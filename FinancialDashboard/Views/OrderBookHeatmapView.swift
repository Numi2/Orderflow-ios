import SwiftUI

/// Shows the order book as a heat map ladder
struct OrderBookHeatmapView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let orderBook: OrderBook
    let visibleLevels: Int
    
    // Formatting
    private let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    init(orderBook: OrderBook, visibleLevels: Int = 10) {
        self.orderBook = orderBook
        self.visibleLevels = visibleLevels
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Price")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                
                Text("Amount")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(uiColor: UIColor.secondarySystemBackground))
            
            // Asks (sell orders) - displayed top to bottom (highest to lowest price)
            ForEach(orderBook.asks.prefix(visibleLevels).reversed()) { level in
                OrderBookLevelRow(
                    level: level,
                    askColor: Color(uiColor: themeManager.colors.downColor),
                    bidColor: Color(uiColor: themeManager.colors.upColor),
                    priceFormatter: priceFormatter,
                    quantityFormatter: quantityFormatter
                )
            }
            
            // Center spread information
            HStack {
                Text("Spread: \(formatPrice(orderBook.spread ?? 0))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let spread = orderBook.spread, let bid = orderBook.bestBid {
                    Text("\(formatPercentage(spread / bid))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(uiColor: UIColor.systemBackground).opacity(0.8))
            
            // Bids (buy orders) - displayed top to bottom (highest to lowest price)
            ForEach(orderBook.bids.prefix(visibleLevels)) { level in
                OrderBookLevelRow(
                    level: level,
                    askColor: Color(uiColor: themeManager.colors.downColor),
                    bidColor: Color(uiColor: themeManager.colors.upColor),
                    priceFormatter: priceFormatter,
                    quantityFormatter: quantityFormatter
                )
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatPrice(_ price: Double) -> String {
        return priceFormatter.string(from: NSNumber(value: price)) ?? "0.00"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        String(format: "%.2f", value * 100)
    }
}

/// Single row in the order book heatmap
struct OrderBookLevelRow: View {
    let level: OrderBookLevel
    let askColor: Color
    let bidColor: Color
    let priceFormatter: NumberFormatter
    let quantityFormatter: NumberFormatter
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background heatmap
            Rectangle()
                .fill(level.side == .bid ? bidColor : askColor)
                .opacity(level.normalizedValue * 0.3)
                .frame(maxWidth: .infinity)
            
            HStack {
                // Price
                Text(formatPrice(level.price))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(level.side == .bid ? bidColor : askColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Quantity
                Text(formatQuantity(level.quantity))
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Total value
                Text(formatPrice(level.totalValue))
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)
        }
        .frame(height: 28)
    }
    
    private func formatPrice(_ price: Double) -> String {
        return priceFormatter.string(from: NSNumber(value: price)) ?? "0.00"
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        return quantityFormatter.string(from: NSNumber(value: quantity)) ?? "0"
    }
}

// Preview provider
struct OrderBookHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        let bids: [(price: Double, quantity: Double)] = [
            (37590.50, 1.2),
            (37589.75, 0.5),
            (37588.20, 2.1),
            (37587.50, 3.4),
            (37586.30, 1.0),
            (37585.40, 2.7),
            (37584.20, 1.5),
            (37583.10, 0.8),
            (37582.50, 1.2),
            (37581.80, 0.3)
        ]
        
        let asks: [(price: Double, quantity: Double)] = [
            (37591.20, 0.5),
            (37592.10, 0.8),
            (37593.40, 1.5),
            (37594.20, 2.0),
            (37595.60, 0.7),
            (37596.30, 1.3),
            (37597.10, 0.9),
            (37598.40, 1.4),
            (37599.30, 0.6),
            (37600.10, 1.1)
        ]
        
        let orderBook = OrderBook(symbol: "BTC/USD", bids: bids, asks: asks)
        
        return OrderBookHeatmapView(orderBook: orderBook)
            .environmentObject(ThemeManager())
            .frame(width: 300)
            .padding()
    }
} 