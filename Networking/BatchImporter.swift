import Foundation
import Combine

/// Import status for tracking batch operations
enum ImportStatus: Equatable {
    case notStarted
    case inProgress(progress: Double)
    case completed
    case failed(error: String)
    
    static func == (lhs: ImportStatus, rhs: ImportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.inProgress(let lhsProgress), .inProgress(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Batch importer for historical OHLCV data
final class BatchImporter {
    // MARK: - Properties
    
    /// Status publisher for tracking import progress
    private let statusSubject = CurrentValueSubject<ImportStatus, Never>(.notStarted)
    
    /// Publisher for the import status
    var statusPublisher: AnyPublisher<ImportStatus, Never> {
        return statusSubject.eraseToAnyPublisher()
    }
    
    /// Maximum number of retry attempts
    private let maxRetryAttempts: Int
    
    /// Starting delay for retries in seconds
    private let initialRetryDelay: TimeInterval
    
    /// Default values
    private let defaultMaxRetryAttempts = 5
    private let defaultInitialRetryDelay: TimeInterval = 1.0
    
    // MARK: - Init
    
    /// Initialize the batch importer
    /// - Parameters:
    ///   - maxRetryAttempts: Maximum number of retry attempts
    ///   - initialRetryDelay: Initial delay for retries in seconds
    init(maxRetryAttempts: Int? = nil, initialRetryDelay: TimeInterval? = nil) {
        self.maxRetryAttempts = maxRetryAttempts ?? defaultMaxRetryAttempts
        self.initialRetryDelay = initialRetryDelay ?? defaultInitialRetryDelay
    }
    
    // MARK: - Public API
    
    /// Import historical data for a symbol and save it to a store
    /// - Parameters:
    ///   - symbol: The ticker symbol
    ///   - timeframe: The timeframe for data (e.g., "1d", "1h")
    ///   - from: Start date
    ///   - to: End date
    ///   - apiClient: The API client to use for fetching data
    ///   - store: The store to save data to
    /// - Returns: Number of data points imported
    func importHistoricalData(
        for symbol: String,
        timeframe: String,
        from: Date,
        to: Date,
        apiClient: AnyObject,
        store: QuoteStore
    ) async throws -> Int {
        statusSubject.send(.inProgress(progress: 0.0))
        
        // Determine the appropriate method to call based on the API client type
        let fetchMethod: (String, String, Date, Date, Int) async throws -> [ChartDataPoint]
        
        if let polygonClient = apiClient as? PolygonClient {
            // Map timeframe from QuoteStore format to Polygon format
            let polygonTimeframe = mapTimeframeToPolygon(timeframe)
            fetchMethod = { symbol, _, from, to, limit in
                try await polygonClient.fetchHistoricalData(
                    for: symbol,
                    timeframe: polygonTimeframe,
                    from: from,
                    to: to,
                    limit: limit
                )
            }
        } else if let binanceClient = apiClient as? BinanceClient {
            // Map timeframe from QuoteStore format to Binance format
            let binanceInterval = mapTimeframeToBinance(timeframe)
            fetchMethod = { symbol, _, from, to, limit in
                let startTime = Int64(from.timeIntervalSince1970 * 1000)
                let endTime = Int64(to.timeIntervalSince1970 * 1000)
                return try await binanceClient.fetchHistoricalData(
                    for: symbol,
                    interval: binanceInterval,
                    startTime: startTime,
                    endTime: endTime,
                    limit: limit
                )
            }
        } else {
            throw ImportError.unsupportedAPIClient
        }
        
        // Calculate the date ranges to fetch data in batches
        let calendar = Calendar.current
        let batchDuration: DateComponents
        
        switch timeframe {
        case TimeframeInterval.minute.rawValue, 
             TimeframeInterval.fiveMinutes.rawValue, 
             TimeframeInterval.fifteenMinutes.rawValue:
            batchDuration = DateComponents(day: 1) // 1 day batches for minute data
        case TimeframeInterval.hourly.rawValue, 
             TimeframeInterval.fourHours.rawValue:
            batchDuration = DateComponents(day: 7) // 1 week batches for hourly data
        default:
            batchDuration = DateComponents(month: 1) // 1 month batches for daily data
        }
        
        var currentDate = from
        var batchEndDate = calendar.date(byAdding: batchDuration, to: currentDate) ?? to
        if batchEndDate > to {
            batchEndDate = to
        }
        
        var totalDataPoints = 0
        let totalDuration = to.timeIntervalSince(from)
        
        // Fetch data in batches
        while currentDate < to {
            let progressRatio = currentDate.timeIntervalSince(from) / totalDuration
            statusSubject.send(.inProgress(progress: progressRatio))
            
            do {
                // Fetch data with retry
                let data = try await fetchWithRetry { [self] in
                    try await fetchMethod(symbol, timeframe, currentDate, batchEndDate, 1000)
                }
                
                if !data.isEmpty {
                    try await store.saveChartData(data, for: symbol, timeframe: timeframe)
                    totalDataPoints += data.count
                }
                
                // Move to the next batch
                currentDate = batchEndDate
                batchEndDate = calendar.date(byAdding: batchDuration, to: currentDate) ?? to
                if batchEndDate > to {
                    batchEndDate = to
                }
            } catch {
                statusSubject.send(.failed(error: error.localizedDescription))
                throw error
            }
        }
        
        statusSubject.send(.completed)
        return totalDataPoints
    }
    
    // MARK: - Private methods
    
    /// Fetch data with retry and exponential backoff
    /// - Parameter operation: The async operation to retry
    /// - Returns: The result of the operation
    private func fetchWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var currentDelay = initialRetryDelay
        var attempt = 0
        
        while true {
            do {
                return try await operation()
            } catch {
                attempt += 1
                
                if attempt >= maxRetryAttempts {
                    throw error
                }
                
                // Exponential backoff with jitter
                let jitter = Double.random(in: 0.0...0.3)
                let delay = currentDelay * (1.0 + jitter)
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Double the delay for the next attempt
                currentDelay *= 2
            }
        }
    }
    
    /// Map timeframe from QuoteStore format to Polygon format
    /// - Parameter timeframe: QuoteStore timeframe
    /// - Returns: Polygon timeframe
    private func mapTimeframeToPolygon(_ timeframe: String) -> String {
        switch timeframe {
        case TimeframeInterval.minute.rawValue:
            return "1/minute"
        case TimeframeInterval.fiveMinutes.rawValue:
            return "5/minute"
        case TimeframeInterval.fifteenMinutes.rawValue:
            return "15/minute"
        case TimeframeInterval.hourly.rawValue:
            return "1/hour"
        case TimeframeInterval.fourHours.rawValue:
            return "4/hour"
        case TimeframeInterval.daily.rawValue:
            return "1/day"
        case TimeframeInterval.weekly.rawValue:
            return "1/week"
        default:
            return "1/day"
        }
    }
    
    /// Map timeframe from QuoteStore format to Binance format
    /// - Parameter timeframe: QuoteStore timeframe
    /// - Returns: Binance interval
    private func mapTimeframeToBinance(_ timeframe: String) -> String {
        switch timeframe {
        case TimeframeInterval.minute.rawValue:
            return "1m"
        case TimeframeInterval.fiveMinutes.rawValue:
            return "5m"
        case TimeframeInterval.fifteenMinutes.rawValue:
            return "15m"
        case TimeframeInterval.hourly.rawValue:
            return "1h"
        case TimeframeInterval.fourHours.rawValue:
            return "4h"
        case TimeframeInterval.daily.rawValue:
            return "1d"
        case TimeframeInterval.weekly.rawValue:
            return "1w"
        default:
            return "1d"
        }
    }
}

/// Errors that can occur during import operations
enum ImportError: Error {
    case unsupportedAPIClient
    case requestFailed
    case rateLimitExceeded
    case dataConversionFailed
} 