import Foundation
import Combine
import SQLite

/// SQLite implementation of the QuoteStore protocol
final class SQLiteQuoteStore: QuoteStore {
    // MARK: - Properties
    
    /// SQLite database connection
    private let db: Connection
    
    /// Quote publishers for real-time updates
    private var quotePublishers: [String: PassthroughSubject<any QuoteData, Error>] = [:]
    
    /// Price publishers for real-time updates
    private var pricePublishers: [String: [String: PassthroughSubject<ChartDataPoint, Error>]] = [:]
    
    // MARK: - SQLite Tables and Columns
    
    // Quotes table
    private let quotesTable = Table("quotes")
    private let idColumn = Expression<Int64>("id")
    private let symbolColumn = Expression<String>("symbol")
    private let nameColumn = Expression<String>("name")
    private let priceColumn = Expression<Double>("price")
    private let changePercentColumn = Expression<Double>("change_percent")
    private let typeColumn = Expression<String>("type")
    private let updatedAtColumn = Expression<Date>("updated_at")
    
    // Chart data table
    private let chartDataTable = Table("chart_data")
    private let cdIdColumn = Expression<Int64>("id")
    private let cdSymbolColumn = Expression<String>("symbol")
    private let cdTimeframeColumn = Expression<String>("timeframe")
    private let timestampColumn = Expression<Date>("timestamp")
    private let openColumn = Expression<Double>("open")
    private let highColumn = Expression<Double>("high")
    private let lowColumn = Expression<Double>("low")
    private let closeColumn = Expression<Double>("close")
    private let volumeColumn = Expression<Double>("volume")
    private let bidVolumeColumn = Expression<Double>("bid_volume")
    private let askVolumeColumn = Expression<Double>("ask_volume")
    
    // MARK: - Init
    
    /// Initialize with an SQLite database
    /// - Parameter dbPath: Path to the SQLite database file (default is in-memory)
    init(dbPath: String? = nil) throws {
        if let path = dbPath {
            db = try Connection(path)
        } else {
            db = try Connection(.inMemory)
        }
        
        // Create tables if they don't exist
        try setupDatabase()
    }
    
    // MARK: - CRUD Operations
    
    func quote(for symbol: String) async throws -> any QuoteData {
        let query = quotesTable.filter(symbolColumn == symbol)
        
        guard let row = try db.pluck(query) else {
            throw QuoteStoreError.notFound
        }
        
        // Convert to domain model
        let type = row[typeColumn]
        if type == "stock" {
            return StockQuote(
                symbol: row[symbolColumn],
                name: row[nameColumn],
                price: row[priceColumn],
                changePercent: row[changePercentColumn]
            )
        } else {
            return CryptoQuote(
                symbol: row[symbolColumn],
                name: row[nameColumn],
                price: row[priceColumn],
                changePercent: row[changePercentColumn]
            )
        }
    }
    
    func allQuotes() async throws -> [any QuoteData] {
        var quotes: [any QuoteData] = []
        
        for row in try db.prepare(quotesTable) {
            let type = row[typeColumn]
            if type == "stock" {
                quotes.append(StockQuote(
                    symbol: row[symbolColumn],
                    name: row[nameColumn],
                    price: row[priceColumn],
                    changePercent: row[changePercentColumn]
                ))
            } else {
                quotes.append(CryptoQuote(
                    symbol: row[symbolColumn],
                    name: row[nameColumn],
                    price: row[priceColumn],
                    changePercent: row[changePercentColumn]
                ))
            }
        }
        
        return quotes
    }
    
    func save(quote: any QuoteData) async throws {
        // Determine the type
        let type: String
        if quote is StockQuote {
            type = "stock"
        } else {
            type = "crypto"
        }
        
        // Check if quote already exists
        let query = quotesTable.filter(symbolColumn == quote.symbol)
        
        if try db.pluck(query) != nil {
            // Update existing quote
            try db.run(query.update(
                nameColumn <- quote.name,
                priceColumn <- quote.price,
                changePercentColumn <- quote.changePercent,
                typeColumn <- type,
                updatedAtColumn <- Date()
            ))
        } else {
            // Insert new quote
            try db.run(quotesTable.insert(
                symbolColumn <- quote.symbol,
                nameColumn <- quote.name,
                priceColumn <- quote.price,
                changePercentColumn <- quote.changePercent,
                typeColumn <- type,
                updatedAtColumn <- Date()
            ))
        }
        
        // Notify subscribers on the main thread
        Task { @MainActor in
            quotePublishers[quote.symbol]?.send(quote)
        }
    }
    
    func save(quotes: [any QuoteData]) async throws {
        try db.transaction {
            for quote in quotes {
                try save(quote: quote)
            }
        }
    }
    
    func delete(symbol: String) async throws {
        let query = quotesTable.filter(symbolColumn == symbol)
        try db.run(query.delete())
    }
    
    // MARK: - Chart Data Operations
    
    func chartData(for symbol: String, timeframe: String, limit: Int?) async throws -> [ChartDataPoint] {
        var query = chartDataTable
            .filter(cdSymbolColumn == symbol && cdTimeframeColumn == timeframe)
            .order(timestampColumn.asc)
        
        if let limit = limit {
            query = query.limit(limit)
        }
        
        var chartData: [ChartDataPoint] = []
        
        for row in try db.prepare(query) {
            chartData.append(ChartDataPoint(
                time: row[timestampColumn],
                open: row[openColumn],
                high: row[highColumn],
                low: row[lowColumn],
                close: row[closeColumn],
                volume: row[volumeColumn],
                bidVolume: row[bidVolumeColumn],
                askVolume: row[askVolumeColumn]
            ))
        }
        
        return chartData
    }
    
    func saveChartData(_ data: [ChartDataPoint], for symbol: String, timeframe: String) async throws {
        try db.transaction {
            for point in data {
                // Check if data point already exists
                let query = chartDataTable
                    .filter(cdSymbolColumn == symbol &&
                            cdTimeframeColumn == timeframe &&
                            timestampColumn == point.time)
                
                if try db.pluck(query) != nil {
                    // Update existing data point
                    try db.run(query.update(
                        openColumn <- point.open,
                        highColumn <- point.high,
                        lowColumn <- point.low,
                        closeColumn <- point.close,
                        volumeColumn <- point.volume,
                        bidVolumeColumn <- point.bidVolume,
                        askVolumeColumn <- point.askVolume
                    ))
                } else {
                    // Insert new data point
                    try db.run(chartDataTable.insert(
                        cdSymbolColumn <- symbol,
                        cdTimeframeColumn <- timeframe,
                        timestampColumn <- point.time,
                        openColumn <- point.open,
                        highColumn <- point.high,
                        lowColumn <- point.low,
                        closeColumn <- point.close,
                        volumeColumn <- point.volume,
                        bidVolumeColumn <- point.bidVolume,
                        askVolumeColumn <- point.askVolume
                    ))
                }
                
                // Notify subscribers on the main thread
                Task { @MainActor in
                    pricePublishers[symbol]?[timeframe]?.send(point)
                }
            }
        }
    }
    
    func deleteChartData(for symbol: String, timeframe: String?) async throws {
        let query: QueryType
        
        if let timeframe = timeframe {
            query = chartDataTable.filter(cdSymbolColumn == symbol && cdTimeframeColumn == timeframe)
        } else {
            query = chartDataTable.filter(cdSymbolColumn == symbol)
        }
        
        try db.run(query.delete())
    }
    
    // MARK: - Real-time Streaming
    
    func subscribeToQuotes(for symbol: String) -> AnyPublisher<any QuoteData, Error> {
        // Create publisher if it doesn't exist
        if quotePublishers[symbol] == nil {
            quotePublishers[symbol] = PassthroughSubject<any QuoteData, Error>()
        }
        
        return quotePublishers[symbol]!.eraseToAnyPublisher()
    }
    
    func subscribeToPriceUpdates(for symbol: String, timeframe: String) -> AnyPublisher<ChartDataPoint, Error> {
        // Create publisher if it doesn't exist
        if pricePublishers[symbol] == nil {
            pricePublishers[symbol] = [:]
        }
        
        if pricePublishers[symbol]?[timeframe] == nil {
            pricePublishers[symbol]?[timeframe] = PassthroughSubject<ChartDataPoint, Error>()
        }
        
        return pricePublishers[symbol]![timeframe]!.eraseToAnyPublisher()
    }
    
    // MARK: - Private methods
    
    /// Set up the database tables
    private func setupDatabase() throws {
        // Create quotes table
        try db.run(quotesTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(symbolColumn)
            t.column(nameColumn)
            t.column(priceColumn)
            t.column(changePercentColumn)
            t.column(typeColumn)
            t.column(updatedAtColumn)
            t.unique([symbolColumn])
        })
        
        // Create chart data table
        try db.run(chartDataTable.create(ifNotExists: true) { t in
            t.column(cdIdColumn, primaryKey: .autoincrement)
            t.column(cdSymbolColumn)
            t.column(cdTimeframeColumn)
            t.column(timestampColumn)
            t.column(openColumn)
            t.column(highColumn)
            t.column(lowColumn)
            t.column(closeColumn)
            t.column(volumeColumn)
            t.column(bidVolumeColumn)
            t.column(askVolumeColumn)
            t.unique([cdSymbolColumn, cdTimeframeColumn, timestampColumn])
        })
        
        // Create indices for faster queries
        try db.run(quotesTable.createIndex(symbolColumn, ifNotExists: true))
        try db.run(chartDataTable.createIndex([cdSymbolColumn, cdTimeframeColumn], ifNotExists: true))
        try db.run(chartDataTable.createIndex(timestampColumn, ifNotExists: true))
    }
} 