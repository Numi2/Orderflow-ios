import Foundation
import Combine

/// Protocol defining a store for financial quotes and chart data
protocol QuoteStore {
    // MARK: - CRUD Operations
    
    /// Retrieve a quote for the given symbol
    /// - Parameter symbol: The ticker symbol
    /// - Returns: Quote data if available
    func quote(for symbol: String) async throws -> any QuoteData
    
    /// Retrieve all quotes
    /// - Returns: All available quotes
    func allQuotes() async throws -> [any QuoteData]
    
    /// Save a quote
    /// - Parameter quote: The quote to save
    func save(quote: any QuoteData) async throws
    
    /// Save multiple quotes
    /// - Parameter quotes: The quotes to save
    func save(quotes: [any QuoteData]) async throws
    
    /// Delete a quote
    /// - Parameter symbol: The symbol of the quote to delete
    func delete(symbol: String) async throws
    
    // MARK: - Chart Data Operations
    
    /// Retrieve chart data for a symbol
    /// - Parameters:
    ///   - symbol: The ticker symbol
    ///   - timeframe: The timeframe to retrieve (e.g., "1d", "1h")
    ///   - limit: Maximum number of data points to retrieve
    /// - Returns: Array of chart data points
    func chartData(for symbol: String, timeframe: String, limit: Int?) async throws -> [ChartDataPoint]
    
    /// Save chart data for a symbol
    /// - Parameters:
    ///   - data: The chart data to save
    ///   - symbol: The ticker symbol
    ///   - timeframe: The timeframe of the data
    func saveChartData(_ data: [ChartDataPoint], for symbol: String, timeframe: String) async throws
    
    /// Delete chart data for a symbol
    /// - Parameters:
    ///   - symbol: The ticker symbol
    ///   - timeframe: Optional timeframe to delete. If nil, all timeframes are deleted
    func deleteChartData(for symbol: String, timeframe: String?) async throws
    
    // MARK: - Real-time Streaming
    
    /// Subscribe to real-time quote updates
    /// - Parameter symbol: The ticker symbol to subscribe to
    /// - Returns: An async sequence of quote updates
    func subscribeToQuotes(for symbol: String) -> AnyPublisher<any QuoteData, Error>
    
    /// Subscribe to real-time chart data updates
    /// - Parameters:
    ///   - symbol: The ticker symbol to subscribe to
    ///   - timeframe: The timeframe to subscribe to
    /// - Returns: An async sequence of chart data updates
    func subscribeToPriceUpdates(for symbol: String, timeframe: String) -> AnyPublisher<ChartDataPoint, Error>
}

/// Time intervals for chart data
enum TimeframeInterval: String, CaseIterable {
    case minute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case hourly = "1h"
    case fourHours = "4h"
    case daily = "1d"
    case weekly = "1w"
}

/// Error types for quote operations
enum QuoteStoreError: Error {
    case notFound
    case invalidData
    case saveFailed
    case deleteFailed
    case connectionFailed
    case subscriptionFailed
    case authenticationFailed
} 