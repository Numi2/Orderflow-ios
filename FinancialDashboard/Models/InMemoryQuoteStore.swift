import Foundation
import Combine

/// In-memory implementation of QuoteStore
final class InMemoryQuoteStore: QuoteStore {
    // MARK: - Properties
    
    /// Quotes indexed by symbol
    private var quotes: [String: any QuoteData] = [:]
    
    /// Chart data indexed by symbol and timeframe
    private var chartData: [String: [String: [ChartDataPoint]]] = [:]
    
    /// Quote publishers for real-time updates
    private var quotePublishers: [String: PassthroughSubject<any QuoteData, Error>] = [:]
    
    /// Price publishers for real-time updates
    private var pricePublishers: [String: [String: PassthroughSubject<ChartDataPoint, Error>]] = [:]
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    // MARK: - Init
    
    init(initialQuotes: [any QuoteData] = []) {
        for quote in initialQuotes {
            quotes[quote.symbol] = quote
        }
    }
    
    // MARK: - CRUD Operations
    
    func quote(for symbol: String) async throws -> any QuoteData {
        lock.lock()
        defer { lock.unlock() }
        
        guard let quote = quotes[symbol] else {
            throw QuoteStoreError.notFound
        }
        
        return quote
    }
    
    func allQuotes() async throws -> [any QuoteData] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(quotes.values)
    }
    
    func save(quote: any QuoteData) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        quotes[quote.symbol] = quote
        
        // Publish update to subscribers
        quotePublishers[quote.symbol]?.send(quote)
    }
    
    func save(quotes: [any QuoteData]) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        for quote in quotes {
            self.quotes[quote.symbol] = quote
            quotePublishers[quote.symbol]?.send(quote)
        }
    }
    
    func delete(symbol: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        quotes.removeValue(forKey: symbol)
    }
    
    // MARK: - Chart Data Operations
    
    func chartData(for symbol: String, timeframe: String, limit: Int? = nil) async throws -> [ChartDataPoint] {
        lock.lock()
        defer { lock.unlock() }
        
        guard let symbolData = chartData[symbol], let data = symbolData[timeframe] else {
            return []
        }
        
        if let limit = limit, limit < data.count {
            return Array(data.suffix(limit))
        } else {
            return data
        }
    }
    
    func saveChartData(_ data: [ChartDataPoint], for symbol: String, timeframe: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        if chartData[symbol] == nil {
            chartData[symbol] = [:]
        }
        
        // Merge with existing data if available, keeping only unique points by timestamp
        var existingData = chartData[symbol]?[timeframe] ?? []
        
        // Create a set of existing timestamps for quick lookup
        let existingTimestamps = Set(existingData.map { $0.time.timeIntervalSince1970 })
        
        // Only add new data points
        for point in data {
            if !existingTimestamps.contains(point.time.timeIntervalSince1970) {
                existingData.append(point)
                // Publish update to subscribers
                pricePublishers[symbol]?[timeframe]?.send(point)
            }
        }
        
        // Sort by timestamp
        existingData.sort { $0.time < $1.time }
        
        chartData[symbol]?[timeframe] = existingData
    }
    
    func deleteChartData(for symbol: String, timeframe: String? = nil) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        if let timeframe = timeframe {
            chartData[symbol]?[timeframe] = nil
        } else {
            chartData.removeValue(forKey: symbol)
        }
    }
    
    // MARK: - Real-time Streaming
    
    func subscribeToQuotes(for symbol: String) -> AnyPublisher<any QuoteData, Error> {
        lock.lock()
        defer { lock.unlock() }
        
        // Create publisher if it doesn't exist
        if quotePublishers[symbol] == nil {
            quotePublishers[symbol] = PassthroughSubject<any QuoteData, Error>()
        }
        
        return quotePublishers[symbol]!.eraseToAnyPublisher()
    }
    
    func subscribeToPriceUpdates(for symbol: String, timeframe: String) -> AnyPublisher<ChartDataPoint, Error> {
        lock.lock()
        defer { lock.unlock() }
        
        // Create publisher if it doesn't exist
        if pricePublishers[symbol] == nil {
            pricePublishers[symbol] = [:]
        }
        
        if pricePublishers[symbol]?[timeframe] == nil {
            pricePublishers[symbol]?[timeframe] = PassthroughSubject<ChartDataPoint, Error>()
        }
        
        return pricePublishers[symbol]![timeframe]!.eraseToAnyPublisher()
    }
    
    // MARK: - Helper methods for simulation
    
    /// Simulate a real-time price update for testing
    /// - Parameters:
    ///   - point: The price point to add
    ///   - symbol: The symbol to update
    ///   - timeframe: The timeframe to update
    func simulatePriceUpdate(_ point: ChartDataPoint, for symbol: String, timeframe: String) {
        lock.lock()
        defer { lock.unlock() }
        
        // Add to chart data
        if chartData[symbol] == nil {
            chartData[symbol] = [:]
        }
        
        if chartData[symbol]?[timeframe] == nil {
            chartData[symbol]?[timeframe] = []
        }
        
        chartData[symbol]?[timeframe]?.append(point)
        
        // Publish to subscribers
        pricePublishers[symbol]?[timeframe]?.send(point)
    }
} 