// ViewModels/DashboardViewModel.swift
import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Published properties
    
    @Published var stockQuotes: [StockQuote] = []
    @Published var cryptoQuotes: [CryptoQuote] = []
    @Published var isRefreshing = false
    @Published var error: String?
    
    // Chart data storage
    @Published private var chartDataCache: [String: [ChartDataPoint]] = [:]
    
    // Order book data
    @Published private(set) var orderBooks: [String: OrderBook] = [:]
    
    // Import progress tracking
    @Published var importStatus: ImportStatus = .notStarted
    
    // Watch settings
    @Published var watchlist: [String] = []
    
    // MARK: - Private properties
    
    // Data store for persistence
    private let store: QuoteStore
    
    // App Group helper for widget sharing
    private let appGroupHelper: AppGroupHelper?
    
    // Keychain manager for API keys
    private let keychainManager: KeychainManager
    
    // Batch importer for historical data
    private let batchImporter: BatchImporter
    
    // API services
    private let services: [any APIService]
    
    // WebSocket clients
    private var polygonClient: PolygonClient?
    private var binanceClient: BinanceClient?
    
    // Streaming subscriptions
    private var quoteSubscriptions: Set<AnyCancellable> = []
    private var chartDataSubscriptions: Set<AnyCancellable> = []
    private var orderBookSubscriptions: Set<AnyCancellable> = []
    
    // Auto-refresh timer
    private var timer: Timer?
    
    // MARK: - Init
    
    init(
        services: [any APIService],
        storeType: QuoteStoreType = .memory,
        appGroupIdentifier: String? = nil
    ) {
        // Set up data store
        do {
            self.store = try QuoteStoreFactory.shared.getStore(storeType)
        } catch {
            // Fall back to in-memory store if persistent store fails
            print("Error creating store: \(error)")
            self.store = InMemoryQuoteStore()
        }
        
        // Set up App Group helper
        if let identifier = appGroupIdentifier {
            self.appGroupHelper = AppGroupHelper(appGroupIdentifier: identifier)
        } else {
            self.appGroupHelper = nil
        }
        
        // Set up keychain manager for API keys
        self.keychainManager = KeychainManager(service: "com.financialdashboard")
        
        // Set up batch importer
        self.batchImporter = BatchImporter()
        
        // Set up services
        self.services = services
        
        // Subscribe to import status updates
        batchImporter.statusPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.importStatus = status
            }
            .cancel()
        
        // Initialize WebSocket clients
        initializeWebSocketClients()
        
        // Initial data load
        Task {
            await loadSavedData() // Load from persistent storage first
            await refreshAll()    // Then refresh from network
        }
        
        // Set up auto-refresh timer (every 5 minutes)
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshAll()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        disconnectWebSockets()
    }
    
    // MARK: - Public Methods
    
    /// Refresh all data from services
    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            var allStockQuotes: [StockQuote] = []
            var allCryptoQuotes: [CryptoQuote] = []
            
            for svc in services {
                let quotes = try await svc.latestQuotes()
                
                // Categorize quotes
                for quote in quotes {
                    if let stockQuote = quote as? StockQuote {
                        allStockQuotes.append(stockQuote)
                    } else if let cryptoQuote = quote as? CryptoQuote {
                        allCryptoQuotes.append(cryptoQuote)
                    }
                }
            }
            
            // Update published properties
            stockQuotes = allStockQuotes
            cryptoQuotes = allCryptoQuotes
            
            // Save to persistent store
            try await saveQuotes(allStockQuotes, allCryptoQuotes)
            
            // Share with widgets if available
            appGroupHelper?.saveStockQuotes(allStockQuotes)
            appGroupHelper?.saveCryptoQuotes(allCryptoQuotes)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Gets chart data for a symbol from cache or loads it if not available
    /// - Parameter symbol: Symbol to get data for
    /// - Returns: Chart data if available
    func chartData(for symbol: String) -> [ChartDataPoint]? {
        return chartDataCache[symbol]
    }
    
    /// Gets order book for a symbol
    /// - Parameter symbol: Symbol to get order book for
    /// - Returns: Order book if available
    func orderBook(for symbol: String) -> OrderBook? {
        return orderBooks[symbol]
    }
    
    /// Loads chart data for a symbol and caches it
    /// - Parameters:
    ///   - symbol: Symbol to load data for
    ///   - timeframe: Timeframe to load (default "1d")
    func loadChartData(for symbol: String, timeframe: String = TimeframeInterval.daily.rawValue) async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            // Try to load from persistent store first
            let data = try await store.chartData(for: symbol, timeframe: timeframe, limit: nil)
            
            if !data.isEmpty {
                // Use cached data if available
                chartDataCache[symbol] = data
            } else {
                // Otherwise fetch from API
                for svc in services {
                    if let polygonClient = svc as? PolygonClient, isStockSymbol(symbol) {
                        let endDate = Date()
                        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
                        
                        let polygonTimeframe = mapTimeframeToPolygon(timeframe)
                        let data = try await polygonClient.fetchHistoricalData(
                            for: symbol,
                            timeframe: polygonTimeframe,
                            from: startDate,
                            to: endDate
                        )
                        
                        chartDataCache[symbol] = data
                        try await store.saveChartData(data, for: symbol, timeframe: timeframe)
                        break
                        
                    } else if let binanceClient = svc as? BinanceClient, isCryptoSymbol(symbol) {
                        let binanceInterval = mapTimeframeToBinance(timeframe)
                        let endDate = Date()
                        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
                        
                        let startTime = Int64(startDate.timeIntervalSince1970 * 1000)
                        let endTime = Int64(endDate.timeIntervalSince1970 * 1000)
                        
                        let data = try await binanceClient.fetchHistoricalData(
                            for: symbol,
                            interval: binanceInterval,
                            startTime: startTime,
                            endTime: endTime
                        )
                        
                        chartDataCache[symbol] = data
                        try await store.saveChartData(data, for: symbol, timeframe: timeframe)
                        break
                    }
                }
            }
            
            // Start streaming updates if in watchlist
            if watchlist.contains(symbol) {
                subscribeToRealTimeUpdates(for: symbol, timeframe: timeframe)
            }
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Loads order book data for a symbol
    /// - Parameter symbol: Symbol to load order book for
    func loadOrderBook(for symbol: String) async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Only crypto symbols supported for now
        guard isCryptoSymbol(symbol) else { return }
        
        do {
            for svc in services {
                if let binanceClient = svc as? BinanceClient {
                    let (bids, asks) = try await binanceClient.fetchOrderBook(for: symbol, limit: 20)
                    let orderBook = OrderBook(symbol: symbol, bids: bids, asks: asks)
                    
                    // Update the order book cache
                    orderBooks[symbol] = orderBook
                    
                    // Subscribe to real-time updates
                    subscribeToOrderBookUpdates(for: symbol)
                    
                    break
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Import historical data for a symbol
    /// - Parameters:
    ///   - symbol: Symbol to import data for
    ///   - timeframe: Timeframe to import
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Number of data points imported
    func importHistoricalData(
        for symbol: String,
        timeframe: String = TimeframeInterval.daily.rawValue,
        from: Date,
        to: Date
    ) async throws -> Int {
        let apiClient: AnyObject
        
        if isStockSymbol(symbol), let polygonClient = self.polygonClient {
            apiClient = polygonClient
        } else if isCryptoSymbol(symbol), let binanceClient = self.binanceClient {
            apiClient = binanceClient
        } else {
            throw ImportError.unsupportedAPIClient
        }
        
        let count = try await batchImporter.importHistoricalData(
            for: symbol,
            timeframe: timeframe,
            from: from,
            to: to,
            apiClient: apiClient,
            store: store
        )
        
        // Refresh the cache after import
        if count > 0 {
            await loadChartData(for: symbol, timeframe: timeframe)
        }
        
        return count
    }
    
    /// Add a symbol to the watchlist
    /// - Parameter symbol: Symbol to add
    func addToWatchlist(_ symbol: String) {
        guard !watchlist.contains(symbol) else { return }
        
        watchlist.append(symbol)
        appGroupHelper?.saveWatchlist(watchlist)
        
        // Start streaming data
        subscribeToRealTimeUpdates(for: symbol)
        
        // Load order book data if crypto
        if isCryptoSymbol(symbol) {
            Task {
                await loadOrderBook(for: symbol)
            }
        }
    }
    
    /// Remove a symbol from the watchlist
    /// - Parameter symbol: Symbol to remove
    func removeFromWatchlist(_ symbol: String) {
        watchlist.removeAll { $0 == symbol }
        appGroupHelper?.saveWatchlist(watchlist)
        
        // Stop streaming data
        unsubscribeFromRealTimeUpdates(for: symbol)
        unsubscribeFromOrderBookUpdates(for: symbol)
    }
    
    /// Save API credentials
    /// - Parameters:
    ///   - polygonApiKey: Polygon.io API key
    ///   - binanceApiKey: Binance API key
    ///   - binanceSecretKey: Binance secret key
    func saveApiCredentials(
        polygonApiKey: String? = nil,
        binanceApiKey: String? = nil,
        binanceSecretKey: String? = nil
    ) {
        if let key = polygonApiKey {
            keychainManager.savePolygonApiKey(key)
            
            // Re-create the Polygon client with the new key
            polygonClient = PolygonClient(apiKey: key)
        }
        
        if let apiKey = binanceApiKey, let secretKey = binanceSecretKey {
            keychainManager.saveBinanceCredentials(apiKey: apiKey, secretKey: secretKey)
            
            // Re-create the Binance client (not using keys directly in this implementation)
            binanceClient = BinanceClient()
        }
        
        // Reconnect WebSocket clients
        connectWebSockets()
    }
    
    // MARK: - Private Methods
    
    /// Load saved data from persistent store
    private func loadSavedData() async {
        do {
            let quotes = try await store.allQuotes()
            
            var stocks: [StockQuote] = []
            var cryptos: [CryptoQuote] = []
            
            for quote in quotes {
                if let stock = quote as? StockQuote {
                    stocks.append(stock)
                } else if let crypto = quote as? CryptoQuote {
                    cryptos.append(crypto)
                }
            }
            
            stockQuotes = stocks
            cryptoQuotes = cryptos
            
            // Load watchlist
            if let appGroupHelper = appGroupHelper {
                watchlist = appGroupHelper.getWatchlist()
            }
            
            // Subscribe to real-time updates for watchlist items
            for symbol in watchlist {
                subscribeToRealTimeUpdates(for: symbol)
                
                // Load order book data for crypto symbols
                if isCryptoSymbol(symbol) {
                    Task {
                        await loadOrderBook(for: symbol)
                    }
                }
            }
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Save quotes to persistent store
    private func saveQuotes(_ stocks: [StockQuote], _ cryptos: [CryptoQuote]) async throws {
        var allQuotes: [any QuoteData] = []
        allQuotes.append(contentsOf: stocks)
        allQuotes.append(contentsOf: cryptos)
        
        try await store.save(quotes: allQuotes)
    }
    
    /// Initialize WebSocket clients
    private func initializeWebSocketClients() {
        // Create Polygon client if API key is available
        if let polygonApiKey = keychainManager.retrievePolygonApiKey() {
            polygonClient = PolygonClient(apiKey: polygonApiKey)
        }
        
        // Create Binance client (no API key needed for public feeds)
        binanceClient = BinanceClient()
        
        // Connect WebSockets
        connectWebSockets()
    }
    
    /// Connect WebSocket clients
    private func connectWebSockets() {
        polygonClient?.connect()
        binanceClient?.connect()
    }
    
    /// Disconnect WebSocket clients
    private func disconnectWebSockets() {
        polygonClient?.disconnect()
        binanceClient?.disconnect()
        
        // Clear subscriptions
        quoteSubscriptions.removeAll()
        chartDataSubscriptions.removeAll()
        orderBookSubscriptions.removeAll()
    }
    
    /// Subscribe to real-time updates for a symbol
    /// - Parameters:
    ///   - symbol: Symbol to subscribe to
    ///   - timeframe: Timeframe for chart data (default "1d")
    private func subscribeToRealTimeUpdates(for symbol: String, timeframe: String = TimeframeInterval.daily.rawValue) {
        // Subscribe to quote updates
        store.subscribeToQuotes(for: symbol)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] quote in
                    self?.handleQuoteUpdate(quote)
                }
            )
            .store(in: &quoteSubscriptions)
        
        // Subscribe to chart data updates
        store.subscribeToPriceUpdates(for: symbol, timeframe: timeframe)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] dataPoint in
                    self?.handleChartDataUpdate(dataPoint, for: symbol)
                }
            )
            .store(in: &chartDataSubscriptions)
        
        // Connect to WebSocket feeds for real-time data
        if isStockSymbol(symbol) {
            polygonClient?.subscribe(to: symbol)
        } else if isCryptoSymbol(symbol) {
            binanceClient?.subscribe(to: symbol)
        }
    }
    
    /// Subscribe to order book updates for a symbol
    /// - Parameter symbol: Symbol to subscribe to
    private func subscribeToOrderBookUpdates(for symbol: String) {
        // Only Binance (crypto) order books are supported for now
        guard isCryptoSymbol(symbol), let binanceClient = binanceClient else { return }
        
        binanceClient.subscribeToOrderBook(for: symbol)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] (bids, asks) in
                    self?.handleOrderBookUpdate(symbol: symbol, bids: bids, asks: asks)
                }
            )
            .store(in: &orderBookSubscriptions)
    }
    
    /// Unsubscribe from order book updates
    /// - Parameter symbol: Symbol to unsubscribe from
    private func unsubscribeFromOrderBookUpdates(for symbol: String) {
        binanceClient?.unsubscribeFromOrderBook(for: symbol)
        
        // Remove from cache
        orderBooks.removeValue(forKey: symbol)
    }
    
    /// Unsubscribe from real-time updates
    /// - Parameter symbol: Symbol to unsubscribe from
    private func unsubscribeFromRealTimeUpdates(for symbol: String) {
        // Unsubscribe from WebSocket feeds
        if isStockSymbol(symbol) {
            polygonClient?.unsubscribe(from: symbol)
        } else if isCryptoSymbol(symbol) {
            binanceClient?.unsubscribe(from: symbol)
        }
        
        // Note: Combine subscriptions will remain but we won't do anything with the updates
    }
    
    /// Handle a quote update
    /// - Parameter quote: The updated quote
    private func handleQuoteUpdate(_ quote: any QuoteData) {
        if let stockQuote = quote as? StockQuote {
            // Update in the local array
            if let index = stockQuotes.firstIndex(where: { $0.symbol == stockQuote.symbol }) {
                stockQuotes[index] = stockQuote
            } else {
                stockQuotes.append(stockQuote)
            }
            
            // Update in App Group for widgets
            appGroupHelper?.saveStockQuotes(stockQuotes)
            
            // Post notification for price alert mechanism
            NotificationCenter.default.post(
                name: .quoteUpdated,
                object: nil,
                userInfo: [
                    "symbol": stockQuote.symbol,
                    "price": stockQuote.price
                ]
            )
            
        } else if let cryptoQuote = quote as? CryptoQuote {
            // Update in the local array
            if let index = cryptoQuotes.firstIndex(where: { $0.symbol == cryptoQuote.symbol }) {
                cryptoQuotes[index] = cryptoQuote
            } else {
                cryptoQuotes.append(cryptoQuote)
            }
            
            // Update in App Group for widgets
            appGroupHelper?.saveCryptoQuotes(cryptoQuotes)
            
            // Post notification for price alert mechanism
            NotificationCenter.default.post(
                name: .quoteUpdated,
                object: nil,
                userInfo: [
                    "symbol": cryptoQuote.symbol,
                    "price": cryptoQuote.price
                ]
            )
        }
    }
    
    /// Handle a chart data update
    /// - Parameters:
    ///   - dataPoint: The updated data point
    ///   - symbol: The symbol for the data point
    private func handleChartDataUpdate(_ dataPoint: ChartDataPoint, for symbol: String) {
        // Get current data for this symbol
        var data = chartDataCache[symbol] ?? []
        
        // Find and update or add the data point
        if let index = data.firstIndex(where: { $0.time.timeIntervalSince1970 == dataPoint.time.timeIntervalSince1970 }) {
            data[index] = dataPoint
        } else {
            data.append(dataPoint)
            
            // Sort by timestamp
            data.sort(by: { $0.time < $1.time })
        }
        
        // Update the cache
        chartDataCache[symbol] = data
    }
    
    /// Handle an order book update
    /// - Parameters:
    ///   - symbol: The symbol for the order book
    ///   - bids: Updated bids
    ///   - asks: Updated asks
    private func handleOrderBookUpdate(symbol: String, bids: [(price: Double, quantity: Double)], asks: [(price: Double, quantity: Double)]) {
        if var orderBook = orderBooks[symbol] {
            // Update existing order book
            orderBook.update(bids: bids, asks: asks)
            orderBooks[symbol] = orderBook
        } else {
            // Create new order book
            let orderBook = OrderBook(symbol: symbol, bids: bids, asks: asks)
            orderBooks[symbol] = orderBook
        }
    }
    
    /// Check if a symbol is a stock
    /// - Parameter symbol: Symbol to check
    /// - Returns: True if it's a stock symbol
    private func isStockSymbol(_ symbol: String) -> Bool {
        return stockQuotes.contains { $0.symbol == symbol }
    }
    
    /// Check if a symbol is a cryptocurrency
    /// - Parameter symbol: Symbol to check
    /// - Returns: True if it's a crypto symbol
    private func isCryptoSymbol(_ symbol: String) -> Bool {
        return cryptoQuotes.contains { $0.symbol == symbol }
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

// MARK: - Notification Extensions

extension Notification.Name {
    static let quoteUpdated = Notification.Name("quoteUpdated")
}