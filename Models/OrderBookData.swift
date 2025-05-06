import Foundation

/// Represents a single order book price level
struct OrderBookLevel: Identifiable, Hashable {
    let id = UUID()
    let price: Double
    let quantity: Double
    let side: OrderSide
    
    // Calculated properties for visualization
    var totalValue: Double { price * quantity }
    
    // Normalized value (0...1) for heatmap intensity
    var normalizedValue: Double = 0
}

/// Side of the order (bid or ask)
enum OrderSide {
    case bid  // Buy orders
    case ask  // Sell orders
}

/// Represents a full order book with bids and asks
struct OrderBook {
    private(set) var bids: [OrderBookLevel] = []
    private(set) var asks: [OrderBookLevel] = []
    
    let symbol: String
    let lastUpdateTime: Date
    
    /// Total quantity of all bids
    var totalBidQuantity: Double {
        bids.reduce(0) { $0 + $1.quantity }
    }
    
    /// Total quantity of all asks
    var totalAskQuantity: Double {
        asks.reduce(0) { $0 + $1.quantity }
    }
    
    /// Best bid price
    var bestBid: Double? {
        bids.first?.price
    }
    
    /// Best ask price
    var bestAsk: Double? {
        asks.first?.price
    }
    
    /// Spread between best bid and best ask
    var spread: Double? {
        guard let bid = bestBid, let ask = bestAsk else { return nil }
        return ask - bid
    }
    
    /// Initialize with raw bid and ask data
    init(symbol: String, bids: [(price: Double, quantity: Double)], asks: [(price: Double, quantity: Double)]) {
        self.symbol = symbol
        self.lastUpdateTime = Date()
        
        // Sort bids by price (descending)
        let sortedBids = bids.sorted(by: { $0.price > $1.price })
        self.bids = sortedBids.map { OrderBookLevel(price: $0.price, quantity: $0.quantity, side: .bid) }
        
        // Sort asks by price (ascending)
        let sortedAsks = asks.sorted(by: { $0.price < $1.price })
        self.asks = sortedAsks.map { OrderBookLevel(price: $0.price, quantity: $0.quantity, side: .ask) }
        
        normalizeValues()
    }
    
    /// Update order book with new data
    mutating func update(bids: [(price: Double, quantity: Double)], asks: [(price: Double, quantity: Double)]) {
        let sortedBids = bids.sorted(by: { $0.price > $1.price })
        let sortedAsks = asks.sorted(by: { $0.price < $1.price })
        
        self.bids = sortedBids.map { OrderBookLevel(price: $0.price, quantity: $0.quantity, side: .bid) }
        self.asks = sortedAsks.map { OrderBookLevel(price: $0.price, quantity: $0.quantity, side: .ask) }
        
        normalizeValues()
    }
    
    /// Normalize the values for heatmap visualization
    private mutating func normalizeValues() {
        // Find max quantities for normalization
        let maxBidQuantity = bids.map { $0.quantity }.max() ?? 1
        let maxAskQuantity = asks.map { $0.quantity }.max() ?? 1
        
        // Normalize bid values
        for i in 0..<bids.count {
            bids[i].normalizedValue = bids[i].quantity / maxBidQuantity
        }
        
        // Normalize ask values
        for i in 0..<asks.count {
            asks[i].normalizedValue = asks[i].quantity / maxAskQuantity
        }
    }
    
    /// Get levels around the mid-price for visualization
    /// - Parameter count: Number of levels to include on each side
    /// - Returns: Array of levels
    func visibleLevels(count: Int) -> [OrderBookLevel] {
        var result: [OrderBookLevel] = []
        
        // Add bids (up to count)
        let bidCount = min(count, bids.count)
        result.append(contentsOf: bids[0..<bidCount])
        
        // Add asks (up to count)
        let askCount = min(count, asks.count)
        result.append(contentsOf: asks[0..<askCount])
        
        return result
    }
} 