import Foundation
import Combine

/// Client for interacting with Polygon.io API
final class PolygonClient {
    // MARK: - Properties
    
    /// API Key for Polygon.io
    private let apiKey: String
    
    /// WebSocket connection for streaming data
    private var websocket: WebSocketConnection
    
    /// Decoder for parsing JSON responses
    private let decoder = JSONDecoder()
    
    /// Subscribed symbols
    private var subscribedSymbols: Set<String> = []
    
    /// Subject for publishing chart data points
    private let chartDataSubject = PassthroughSubject<ChartDataPoint, Error>()
    
    // MARK: - Init
    
    /// Initialize with an API key
    /// - Parameter apiKey: Polygon.io API key
    init(apiKey: String) {
        self.apiKey = apiKey
        
        // Configure the WebSocket connection
        let wsURL = URL(string: "wss://socket.polygon.io/stocks")!
        self.websocket = StandardWebSocketConnection(url: wsURL)
        
        // Set up message handling
        setupMessageHandling()
    }
    
    // MARK: - Public API
    
    /// Connect to the WebSocket server and authenticate
    func connect() {
        websocket.connect()
        
        // Authenticate once connected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.authenticate()
        }
    }
    
    /// Disconnect from the WebSocket server
    func disconnect() {
        websocket.disconnect()
        subscribedSymbols.removeAll()
    }
    
    /// Subscribe to real-time data for a symbol
    /// - Parameter symbol: The ticker symbol to subscribe to
    func subscribe(to symbol: String) {
        guard websocket.isConnected else { return }
        
        let message = """
        {"action":"subscribe","params":"T.\(symbol)"}
        """
        websocket.send(message: message)
        subscribedSymbols.insert(symbol)
    }
    
    /// Unsubscribe from real-time data for a symbol
    /// - Parameter symbol: The ticker symbol to unsubscribe from
    func unsubscribe(from symbol: String) {
        guard websocket.isConnected, subscribedSymbols.contains(symbol) else { return }
        
        let message = """
        {"action":"unsubscribe","params":"T.\(symbol)"}
        """
        websocket.send(message: message)
        subscribedSymbols.remove(symbol)
    }
    
    /// Get real-time chart data as an AsyncSequence
    /// - Returns: Publisher for chart data points
    func chartDataPublisher() -> AnyPublisher<ChartDataPoint, Error> {
        return chartDataSubject.eraseToAnyPublisher()
    }
    
    /// Fetch historical data for a symbol
    /// - Parameters:
    ///   - symbol: The ticker symbol
    ///   - timeframe: Timeframe (e.g., "1/minute", "1/day")
    ///   - from: Start date
    ///   - to: End date
    ///   - limit: Maximum number of results
    /// - Returns: Array of chart data points
    func fetchHistoricalData(
        for symbol: String,
        timeframe: String,
        from: Date,
        to: Date,
        limit: Int = 1000
    ) async throws -> [ChartDataPoint] {
        // Format dates in ISO 8601 format
        let dateFormatter = ISO8601DateFormatter()
        let fromStr = dateFormatter.string(from: from)
        let toStr = dateFormatter.string(from: to)
        
        let urlString = "https://api.polygon.io/v2/aggs/ticker/\(symbol)/range/\(timeframe)/\(fromStr)/\(toStr)?apiKey=\(apiKey)&limit=\(limit)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            let polygonResponse = try decoder.decode(PolygonAggregatesResponse.self, from: data)
            return convertToChartDataPoints(polygonResponse.results, symbol: symbol)
        } catch {
            throw error
        }
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
            // Try parsing as a trade message
            let tradeMessage = try decoder.decode(PolygonTradeMessage.self, from: data)
            return convertToChartDataPoints(tradeMessage)
        } catch {
            // Try parsing as a status message
            do {
                let statusMessage = try decoder.decode(PolygonStatusMessage.self, from: data)
                if statusMessage.status == "connected" {
                    // If connected, authenticate
                    authenticate()
                }
                return []
            } catch {
                // If all parsing attempts fail, return an empty array
                return []
            }
        }
    }
    
    /// Authenticate with the Polygon.io WebSocket API
    private func authenticate() {
        let message = """
        {"action":"auth","params":"\(apiKey)"}
        """
        websocket.send(message: message)
    }
    
    /// Convert Polygon trade messages to chart data points
    /// - Parameter message: The Polygon trade message
    /// - Returns: Array of chart data points
    private func convertToChartDataPoints(_ message: PolygonTradeMessage) -> [ChartDataPoint] {
        return message.data.map { trade in
            let timestamp = Date(timeIntervalSince1970: Double(trade.t) / 1000.0)
            
            return ChartDataPoint(
                time: timestamp,
                open: trade.p,
                high: trade.p,
                low: trade.p,
                close: trade.p,
                volume: Double(trade.s),
                bidVolume: 0,
                askVolume: 0
            )
        }
    }
    
    /// Convert Polygon aggregates to chart data points
    /// - Parameters:
    ///   - aggregates: The Polygon aggregates
    ///   - symbol: The ticker symbol
    /// - Returns: Array of chart data points
    private func convertToChartDataPoints(_ aggregates: [PolygonAggregate]?, symbol: String) -> [ChartDataPoint] {
        guard let aggregates = aggregates else { return [] }
        
        return aggregates.map { agg in
            let timestamp = Date(timeIntervalSince1970: Double(agg.t) / 1000.0)
            
            return ChartDataPoint(
                time: timestamp,
                open: agg.o,
                high: agg.h,
                low: agg.l,
                close: agg.c,
                volume: Double(agg.v),
                bidVolume: 0,
                askVolume: 0
            )
        }
    }
}

// MARK: - Polygon API Models

/// Response from Polygon.io Aggregates API
struct PolygonAggregatesResponse: Codable {
    let ticker: String
    let status: String
    let results: [PolygonAggregate]?
}

/// Aggregate data from Polygon.io
struct PolygonAggregate: Codable {
    let v: Int      // volume
    let o: Double   // open
    let c: Double   // close
    let h: Double   // high
    let l: Double   // low
    let t: Int64    // timestamp (milliseconds)
}

/// Message from Polygon.io WebSocket API for trades
struct PolygonTradeMessage: Codable {
    let ev: String      // event type ("T" for trades)
    let data: [PolygonTrade]
}

/// Trade data from Polygon.io
struct PolygonTrade: Codable {
    let ev: String      // event type
    let sym: String     // symbol
    let p: Double       // price
    let s: Int          // size (volume)
    let t: Int64        // timestamp (milliseconds)
}

/// Status message from Polygon.io WebSocket API
struct PolygonStatusMessage: Codable {
    let status: String
    let message: String?
} 