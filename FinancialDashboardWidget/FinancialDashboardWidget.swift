import WidgetKit
import SwiftUI

// MARK: - Provider

struct Provider: TimelineProvider {
    let appGroupHelper = AppGroupHelper(appGroupIdentifier: AppConfig.appGroupIdentifier)
    
    func placeholder(in context: Context) -> WidgetEntry {
        // Return a placeholder entry with sample data
        let stockQuote = StockQuote(
            symbol: "AAPL", 
            price: 180.95, 
            change: 1.23, 
            percentChange: 0.68, 
            volume: 23500000, 
            high: 181.50, 
            low: 179.25, 
            open: 179.50
        )
        
        let cryptoQuote = CryptoQuote(
            symbol: "BTCUSD", 
            price: 37450.12, 
            change: 450.30, 
            percentChange: 1.25, 
            volume: 15678.5, 
            marketCap: 710000000000
        )
        
        return WidgetEntry(
            date: Date(), 
            watchlist: ["AAPL", "BTCUSD"],
            stockQuotes: [stockQuote],
            cryptoQuotes: [cryptoQuote]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        // Get real data from shared app group container
        let stockQuotes = appGroupHelper.getStockQuotes() 
        let cryptoQuotes = appGroupHelper.getCryptoQuotes()
        let watchlist = appGroupHelper.getWatchlist()
        
        let entry = WidgetEntry(
            date: Date(),
            watchlist: watchlist,
            stockQuotes: stockQuotes,
            cryptoQuotes: cryptoQuotes
        )
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // Get real data from shared app group container
        let stockQuotes = appGroupHelper.getStockQuotes() 
        let cryptoQuotes = appGroupHelper.getCryptoQuotes()
        let watchlist = appGroupHelper.getWatchlist()
        
        let entry = WidgetEntry(
            date: Date(),
            watchlist: watchlist,
            stockQuotes: stockQuotes,
            cryptoQuotes: cryptoQuotes
        )
        
        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        
        completion(timeline)
    }
}

// MARK: - Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let watchlist: [String]
    let stockQuotes: [StockQuote]
    let cryptoQuotes: [CryptoQuote]
    
    /// Filter quotes to include only watchlist items
    var watchlistQuotes: [any QuoteData] {
        var result: [any QuoteData] = []
        
        for symbol in watchlist {
            if let stock = stockQuotes.first(where: { $0.symbol == symbol }) {
                result.append(stock)
            } else if let crypto = cryptoQuotes.first(where: { $0.symbol == symbol }) {
                result.append(crypto)
            }
        }
        
        return result
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let quote = entry.watchlistQuotes.first {
                // Symbol and time
                HStack {
                    Text(quote.symbol)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(timeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Price
                Text(formatPrice(quote.price))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                // Change and percentage
                HStack(spacing: 4) {
                    Image(systemName: changeIcon(quote.change))
                        .foregroundStyle(changeColor(quote.change))
                    
                    Text(formatChange(quote.change))
                        .foregroundStyle(changeColor(quote.change))
                    
                    Text("(\(formatPercent(quote.percentChange)))")
                        .foregroundStyle(changeColor(quote.change))
                }
                .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                // Mini sparkline chart would go here
            } else {
                Text("No Data")
                    .font(.headline)
                    .foreground(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .widgetBackground()
    }
    
    // Formatting helpers
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.date)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.1f", price)
        } else if price >= 100 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.3f", price)
        }
    }
    
    private func formatChange(_ change: Double) -> String {
        if abs(change) >= 100 {
            return String(format: "%.1f", change)
        } else {
            return String(format: "%.2f", change)
        }
    }
    
    private func formatPercent(_ percent: Double) -> String {
        return String(format: "%.2f%%", percent)
    }
    
    private func changeIcon(_ change: Double) -> String {
        if change > 0 {
            return "arrow.up.right"
        } else if change < 0 {
            return "arrow.down.right"
        } else {
            return "minus"
        }
    }
    
    private func changeColor(_ change: Double) -> Color {
        if change > 0 {
            return .green
        } else if change < 0 {
            return .red
        } else {
            return .secondary
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Financial Dashboard")
                    .font(.headline)
                
                Spacer()
                
                Text("Updated \(timeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if entry.watchlistQuotes.isEmpty {
                Text("No symbols in watchlist")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                let itemCount = min(3, entry.watchlistQuotes.count)
                let quotes = Array(entry.watchlistQuotes.prefix(itemCount))
                
                HStack(spacing: 8) {
                    ForEach(0..<quotes.count, id: \.self) { i in
                        QuoteItemView(quote: quotes[i])
                    }
                }
            }
        }
        .padding()
        .widgetBackground()
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.date)
    }
}

// Single quote view for medium widget
struct QuoteItemView: View {
    let quote: any QuoteData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Symbol
            Text(quote.symbol)
                .font(.headline)
                .lineLimit(1)
            
            // Price
            Text(formatPrice(quote.price))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            
            // Change and percentage
            HStack(spacing: 2) {
                Image(systemName: changeIcon(quote.change))
                    .foregroundStyle(changeColor(quote.change))
                    .font(.system(size: 10))
                
                Text("\(formatChange(quote.change)) (\(formatPercent(quote.percentChange)))")
                    .foregroundStyle(changeColor(quote.change))
                    .font(.system(size: 12, weight: .medium))
            }
            
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // Formatting helpers
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "$%.1f", price)
        } else if price >= 100 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.3f", price)
        }
    }
    
    private func formatChange(_ change: Double) -> String {
        if abs(change) >= 100 {
            return String(format: "%.1f", change)
        } else {
            return String(format: "%.2f", change)
        }
    }
    
    private func formatPercent(_ percent: Double) -> String {
        return String(format: "%.2f%%", percent)
    }
    
    private func changeIcon(_ change: Double) -> String {
        if change > 0 {
            return "arrow.up.right"
        } else if change < 0 {
            return "arrow.down.right"
        } else {
            return "minus"
        }
    }
    
    private func changeColor(_ change: Double) -> Color {
        if change > 0 {
            return .green
        } else if change < 0 {
            return .red
        } else {
            return .secondary
        }
    }
}

// MARK: - Widget Configuration

struct FinancialDashboardWidget: Widget {
    let kind: String = "FinancialDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FinancialDashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Financial Dashboard")
        .description("Track your watchlist symbols.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FinancialDashboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Background Extension

extension View {
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            return background(Color(.systemBackground))
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FinancialDashboardWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        watchlist: ["AAPL", "BTCUSD"],
        stockQuotes: [
            StockQuote(
                symbol: "AAPL", 
                price: 180.95, 
                change: 1.23, 
                percentChange: 0.68, 
                volume: 23500000, 
                high: 181.50, 
                low: 179.25, 
                open: 179.50
            )
        ],
        cryptoQuotes: [
            CryptoQuote(
                symbol: "BTCUSD", 
                price: 37450.12, 
                change: 450.30, 
                percentChange: 1.25, 
                volume: 15678.5, 
                marketCap: 710000000000
            )
        ]
    )
}

#Preview(as: .systemMedium) {
    FinancialDashboardWidget()
} timeline: {
    WidgetEntry(
        date: Date(),
        watchlist: ["AAPL", "MSFT", "BTCUSD"],
        stockQuotes: [
            StockQuote(
                symbol: "AAPL", 
                price: 180.95, 
                change: 1.23, 
                percentChange: 0.68, 
                volume: 23500000, 
                high: 181.50, 
                low: 179.25, 
                open: 179.50
            ),
            StockQuote(
                symbol: "MSFT", 
                price: 330.12, 
                change: -2.35, 
                percentChange: -0.71, 
                volume: 18750000, 
                high: 332.80, 
                low: 329.20, 
                open: 332.50
            )
        ],
        cryptoQuotes: [
            CryptoQuote(
                symbol: "BTCUSD", 
                price: 37450.12, 
                change: 450.30, 
                percentChange: 1.25, 
                volume: 15678.5, 
                marketCap: 710000000000
            )
        ]
    )
} 