import Foundation
import Combine

/// Client for interacting with Binance API
final class BinanceClient {
    // MARK: - Properties
    
    /// WebSocket connection for streaming data
    private var websocket: WebSocketConnection
    
    /// Decoder for parsing JSON responses
    private let decoder = JSONDecoder()
    
    /// Subject for publishing chart data points
    private let chartDataSubject = PassthroughSubject<ChartDataPoint, Error>()
    
    /// Subscribed symbols
    private var subscribedSymbols: Set<String> = []
    
    /// Is main connection active
    private var isConnected = false
    
    // Base URLs
    private let restBaseURL = "https://api.binance.com"
    private let websocketBaseURL = "wss://stream.binance.com:9443/ws"
    
    // WebSocket connection
    private var webSocketTask: URLSessionWebSocketTask?
    private var webSocketSession: URLSession?
    
    // Publisher subjects
    private let priceUpdateSubject = PassthroughSubject<(String, Double), Error>()
    private let orderBookSubject = PassthroughSubject<(String, [(price: Double, quantity: Double)], [(price: Double, quantity: Double)])>, Error>()
    
    // Track active subscriptions
    private var activeSymbols = Set<String>()
    private var activeOrderBookSymbols = Set<String>()
    
    // MARK: - Init
    
    init() {
        // Configure the WebSocket connection
        let wsURL = URL(string: "wss://stream.binance.com:9443/ws")!
        self.websocket = StandardWebSocketConnection(url: wsURL)
        
        // Set up message handling
        setupMessageHandling()
    }
    
    // MARK: - Public API
    
    /// Connect to the WebSocket server
    func connect() {
        guard webSocketTask == nil else { return }
        
        webSocketSession = URLSession(configuration: .default)
        webSocketTask = webSocketSession?.webSocketTask(with: URL(string: websocketBaseURL)!)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    /// Disconnect from the WebSocket server
    func disconnect() {
        websocket.disconnect()
        subscribedSymbols.removeAll()
        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        webSocketSession = nil
        activeSymbols.removeAll()
        activeOrderBookSymbols.removeAll()
    }
    
    /// Subscribe to a symbol's trade stream
    /// - Parameter symbol: The symbol to subscribe to (e.g., "btcusdt")
    func subscribe(to symbol: String) {
        guard !activeSymbols.contains(symbol) else { return }
        
        // Add to tracking set
        activeSymbols.insert(symbol)
        
        // Subscribe via WebSocket
        let lowercaseSymbol = symbol.lowercased()
        let message = """
        {
            "method": "SUBSCRIBE",
            "params": ["\(lowercaseSymbol)@ticker"],
            "id": \(activeSymbols.count)
        }
        """
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("WebSocket subscription error: \(error)")
            }
        }
    }
    
    /// Unsubscribe from a symbol's trade stream
    /// - Parameter symbol: The symbol to unsubscribe from
    func unsubscribe(from symbol: String) {
        guard activeSymbols.contains(symbol) else { return }
        
        // Remove from tracking set
        activeSymbols.remove(symbol)
        
        // Unsubscribe via WebSocket
        let lowercaseSymbol = symbol.lowercased()
        let message = """
        {
            "method": "UNSUBSCRIBE",
            "params": ["\(lowercaseSymbol)@ticker"],
            "id": \(activeSymbols.count + 100)
        }
        """
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("WebSocket unsubscription error: \(error)")
            }
        }
    }
    
    /// Get chart data publisher
    /// - Returns: Publisher for chart data points
    func chartDataPublisher() -> AnyPublisher<ChartDataPoint, Error> {
        return chartDataSubject.eraseToAnyPublisher()
    }
    
    /// Fetch historical kline (candlestick) data
    /// - Parameters:
    ///   - symbol: The trading pair symbol (e.g., "BTCUSDT")
    ///   - interval: Kline interval (e.g., "1m", "1h", "1d")
    ///   - startTime: Optional start time in milliseconds
    ///   - endTime: Optional end time in milliseconds
    ///   - limit: Number of results to return (default 500, max 1000)
    /// - Returns: Array of chart data points
    func fetchHistoricalData(
        for symbol: String,
        interval: String,
        startTime: Int64? = nil,
        endTime: Int64? = nil,
        limit: Int = 500
    ) async throws -> [ChartDataPoint] {
        var urlComponents = URLComponents(string: "https://api.binance.com/api/v3/klines")!
        
        var queryItems = [
            URLQueryItem(name: "symbol", value: symbol.uppercased()),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        if let startTime = startTime {
            queryItems.append(URLQueryItem(name: "startTime", value: String(startTime)))
        }
        
        if let endTime = endTime {
            queryItems.append(URLQueryItem(name: "endTime", value: String(endTime)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            // Binance returns an array of arrays for kline data
            let klines = try decoder.decode([[Any]].self, from: data)
            return convertToChartDataPoints(klines)
        } catch {
            throw error
        }
    }
    
    /// Subscribe to order book updates for a symbol
    /// - Parameter symbol: Symbol to subscribe to
    /// - Returns: Publisher for order book updates
    func subscribeToOrderBook(for symbol: String) -> AnyPublisher<([(price: Double, quantity: Double)], [(price: Double, quantity: Double)]), Error> {
        guard !activeOrderBookSymbols.contains(symbol) else {
            return orderBookSubject.filter { $0.0 == symbol }
                .map { (_, bids, asks) in (bids, asks) }
                .eraseToAnyPublisher()
        }
        
        // Add to tracking set
        activeOrderBookSymbols.insert(symbol)
        
        // Subscribe via WebSocket
        let lowercaseSymbol = symbol.lowercased()
        let message = """
        {
            "method": "SUBSCRIBE",
            "params": ["\(lowercaseSymbol)@depth20@100ms"],
            "id": \(activeOrderBookSymbols.count + 1000)
        }
        """
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("WebSocket order book subscription error: \(error)")
            }
        }
        
        return orderBookSubject.filter { $0.0 == symbol }
            .map { (_, bids, asks) in (bids, asks) }
            .eraseToAnyPublisher()
    }
    
    /// Unsubscribe from order book updates
    /// - Parameter symbol: Symbol to unsubscribe from
    func unsubscribeFromOrderBook(for symbol: String) {
        guard activeOrderBookSymbols.contains(symbol) else { return }
        
        // Remove from tracking set
        activeOrderBookSymbols.remove(symbol)
        
        // Unsubscribe via WebSocket
        let lowercaseSymbol = symbol.lowercased()
        let message = """
        {
            "method": "UNSUBSCRIBE",
            "params": ["\(lowercaseSymbol)@depth20@100ms"],
            "id": \(activeOrderBookSymbols.count + 2000)
        }
        """
        
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("WebSocket order book unsubscription error: \(error)")
            }
        }
    }
    
    /// Fetch order book data for a symbol
    /// - Parameters:
    ///   - symbol: Symbol to fetch order book for
    ///   - limit: Number of price levels to fetch (max 1000)
    /// - Returns: Tuple of bids and asks
    func fetchOrderBook(
        for symbol: String,
        limit: Int = 20
    ) async throws -> ([(price: Double, quantity: Double)], [(price: Double, quantity: Double)]) {
        var components = URLComponents(string: "\(restBaseURL)/api/v3/depth")!
        
        components.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        
        // Parse the response
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        let bidsJson = json["bids"] as! [[String]]
        let asksJson = json["asks"] as! [[String]]
        
        let bids = bidsJson.map { (Double($0[0])!, Double($0[1])!) }
        let asks = asksJson.map { (Double($0[0])!, Double($0[1])!) }
        
        return (bids, asks)
    }
    
    // MARK: - Private methods
    
    /// Set up handling of messages from the WebSocket
    private func setupMessageHandling() {
        websocket.messagePublisher
            .tryMap { [weak self] data -> [ChartDataPoint] in
                guard let self = self else { throw WebSocketError.disconnected }
                return try self.parseMessage(data)
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.chartDataSubject.send(completion: .failure(error))
                    }
                },
                receiveValue: { [weak self] dataPoints in
                    guard let self = self else { return }
                    for point in dataPoints {
                        self.chartDataSubject.send(point)
                    }
                }
            )
            .cancel()
    }
    
    /// Parse a message from the WebSocket and convert it to chart data points
    /// - Parameter data: The raw message data
    /// - Returns: Array of chart data points
    private func parseMessage(_ data: Data) throws -> [ChartDataPoint] {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Handle subscription response
                if let id = json["id"] as? Int, let result = json["result"] as? NSNull {
                    isConnected = true
                    return []
                }
                
                // Handle kline data
                if let e = json["e"] as? String, e == "kline",
                   let k = json["k"] as? [String: Any] {
                    return [try parseKlineData(k)]
                }
            }
            return []
        } catch {
            return []
        }
    }
    
    /// Parse kline data from Binance
    /// - Parameter kline: Kline data dictionary
    /// - Returns: Chart data point
    private func parseKlineData(_ kline: [String: Any]) throws -> ChartDataPoint {
        guard let openTimeMs = kline["t"] as? Int64,
              let open = Double(kline["o"] as? String ?? "0"),
              let high = Double(kline["h"] as? String ?? "0"),
              let low = Double(kline["l"] as? String ?? "0"),
              let close = Double(kline["c"] as? String ?? "0"),
              let volume = Double(kline["v"] as? String ?? "0"),
              let quoteVolume = Double(kline["q"] as? String ?? "0")
        else {
            throw WebSocketError.messageDecodingFailed
        }
        
        let timestamp = Date(timeIntervalSince1970: Double(openTimeMs) / 1000.0)
        
        return ChartDataPoint(
            time: timestamp,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            bidVolume: 0,
            askVolume: 0
        )
    }
    
    /// Convert Binance kline data to chart data points
    /// - Parameter klines: Binance kline data
    /// - Returns: Array of chart data points
    private func convertToChartDataPoints(_ klines: [[Any]]) -> [ChartDataPoint] {
        return klines.compactMap { kline in
            guard kline.count >= 6,
                  let openTime = kline[0] as? Int64,
                  let open = Double(String(describing: kline[1])),
                  let high = Double(String(describing: kline[2])),
                  let low = Double(String(describing: kline[3])),
                  let close = Double(String(describing: kline[4])),
                  let volume = Double(String(describing: kline[5]))
            else {
                return nil
            }
            
            let timestamp = Date(timeIntervalSince1970: Double(openTime) / 1000.0)
            
            return ChartDataPoint(
                time: timestamp,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                bidVolume: 0,
                askVolume: 0
            )
        }
    }
    
    /// Receive messages from WebSocket
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                // Attempt to reconnect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.connect()
                }
            }
        }
    }
    
    /// Handle a message from the WebSocket
    /// - Parameter text: Message text
    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for ticker message (price update)
                if let symbol = json["s"] as? String, 
                   let lastPrice = json["c"] as? String, 
                   let eventType = json["e"] as? String, 
                   eventType == "24hrTicker" {
                    
                    if let price = Double(lastPrice) {
                        priceUpdateSubject.send((symbol, price))
                    }
                }
                
                // Check for depth update message (order book)
                if let eventType = json["e"] as? String, eventType == "depthUpdate",
                   let symbol = json["s"] as? String,
                   let bidsArray = json["b"] as? [[String]],
                   let asksArray = json["a"] as? [[String]] {
                    
                    let bids = bidsArray.map { (Double($0[0])!, Double($0[1])!) }
                    let asks = asksArray.map { (Double($0[0])!, Double($0[1])!) }
                    
                    orderBookSubject.send((symbol, bids, asks))
                }
            }
        } catch {
            print("WebSocket message parsing error: \(error)")
        }
    }
}

// MARK: - APIService conformance

extension BinanceClient: APIService {
    func latestQuotes() async throws -> [any QuoteData] {
        // Fetch top crypto quotes from Binance
        let symbols = ["BTCUSDT", "ETHUSDT", "BNBUSDT", "ADAUSDT", "SOLUSDT"]
        
        var quotes: [CryptoQuote] = []
        
        for symbol in symbols {
            // Call the ticker endpoint
            var components = URLComponents(string: "\(restBaseURL)/api/v3/ticker/24hr")!
            components.queryItems = [URLQueryItem(name: "symbol", value: symbol)]
            
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            
            // Parse the response
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            let lastPrice = Double(json["lastPrice"] as! String)!
            let priceChange = Double(json["priceChange"] as! String)!
            let volume = Double(json["volume"] as! String)!
            
            let quote = CryptoQuote(
                symbol: symbol,
                price: lastPrice,
                change: priceChange,
                percentChange: Double(json["priceChangePercent"] as! String)!,
                volume: volume,
                marketCap: lastPrice * volume
            )
            
            quotes.append(quote)
        }
        
        return quotes
    }
} 