import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes

struct FinancialDashboardAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic content that can update over time
        var symbol: String
        var price: Double
        var previousPrice: Double
        var change: Double
        var percentChange: Double
        var lastUpdateTime: Date
    }

    // Fixed content for the Live Activity
    var symbol: String
    var initialPrice: Double
}

// MARK: - Live Activity Widget

@available(iOS 16.1, *)
struct FinancialDashboardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinancialDashboardAttributes.self) { context in
            // Lock screen/banner UI
            HStack {
                SymbolAndPriceView(context: context)
                Spacer()
                ChangeView(context: context)
            }
            .padding(16)
            .activityBackgroundTint(Color.gray.opacity(0.2))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.symbol)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Real-time price")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(formatPrice(context.state.price))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(formatChange(context.state.change, context.state.percentChange))
                            .font(.caption)
                            .foregroundColor(context.state.change >= 0 ? .green : .red)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    PriceTickView(price: context.state.price, previousPrice: context.state.previousPrice)
                        .frame(height: 44)
                        .padding(.top, 8)
                }
            } compactLeading: {
                // Leading compact UI
                Text(context.attributes.symbol)
                    .font(.caption2)
                    .foregroundColor(.primary)
            } compactTrailing: {
                // Trailing compact UI
                HStack(spacing: 4) {
                    Image(systemName: context.state.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(context.state.change >= 0 ? .green : .red)
                    
                    Text(formatShortPrice(context.state.price))
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
            } minimal: {
                // Minimal UI when DI is very small
                Image(systemName: context.state.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                    .foregroundColor(context.state.change >= 0 ? .green : .red)
            }
            .keylineTint(context.state.change >= 0 ? .green : .red)
        }
    }
}

// MARK: - Helper Views

@available(iOS 16.1, *)
struct SymbolAndPriceView: View {
    let context: ActivityViewContext<FinancialDashboardAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(context.attributes.symbol)
                    .font(.headline)
                
                Text("• LIVE")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text(formatPrice(context.state.price))
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

@available(iOS 16.1, *)
struct ChangeView: View {
    let context: ActivityViewContext<FinancialDashboardAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Time of last update
            Text(formatTime(context.state.lastUpdateTime))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Change amount and percentage
            HStack(spacing: 2) {
                Image(systemName: context.state.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(formatChange(context.state.change, context.state.percentChange))
            }
            .font(.subheadline)
            .foregroundColor(context.state.change >= 0 ? .green : .red)
        }
    }
}

/// Visual price tick indicator that shows price movement
struct PriceTickView: View {
    let price: Double
    let previousPrice: Double
    
    @State private var lastPrices: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            // Draw price ticks as small circles
            ZStack {
                // Horizontal line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                HStack(spacing: 0) {
                    ForEach(Array(lastPrices.enumerated()), id: \.offset) { index, price in
                        if let prev = index > 0 ? lastPrices[index - 1] : nil {
                            Circle()
                                .fill(getColor(current: price, previous: prev))
                                .frame(width: 4, height: 4)
                                .offset(y: getOffset(current: price, previous: prev))
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 4, height: 4)
                        }
                        Spacer()
                            .frame(width: 8)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .onAppear {
            // Initialize with some values
            lastPrices = [price]
        }
        .onChange(of: price) { newValue in
            addPrice(newValue)
        }
    }
    
    /// Add a new price while keeping a limited history
    private func addPrice(_ price: Double) {
        // Keep a history of 20 prices
        var updatedPrices = lastPrices
        updatedPrices.append(price)
        if updatedPrices.count > 20 {
            updatedPrices.removeFirst()
        }
        lastPrices = updatedPrices
    }
    
    /// Get the vertical offset based on price change
    private func getOffset(current: Double, previous: Double) -> CGFloat {
        let diff = current - previous
        // Scale the difference to make it visible
        let scaleFactor: CGFloat = 50.0
        return CGFloat(-diff * scaleFactor)
    }
    
    /// Get color based on price change
    private func getColor(current: Double, previous: Double) -> Color {
        if current > previous {
            return .green
        } else if current < previous {
            return .red
        } else {
            return .gray
        }
    }
}

// MARK: - Helper Functions

private func formatPrice(_ price: Double) -> String {
    if price >= 1000 {
        return String(format: "$%.1f", price)
    } else if price >= 100 {
        return String(format: "$%.2f", price)
    } else {
        return String(format: "$%.3f", price)
    }
}

private func formatShortPrice(_ price: Double) -> String {
    if price >= 1000 {
        return String(format: "$%.0f", price)
    } else if price >= 100 {
        return String(format: "$%.1f", price)
    } else {
        return String(format: "$%.2f", price)
    }
}

private func formatChange(_ change: Double, _ percentChange: Double) -> String {
    let changeStr = abs(change) >= 100 ? String(format: "%.1f", change) : String(format: "%.2f", change)
    let percentStr = String(format: "%.2f%%", percentChange)
    return "\(changeStr) (\(percentStr))"
}

private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

// MARK: - Previews

#Preview(as: .dynamicIsland(.compact), using: FinancialDashboardAttributes(symbol: "AAPL", initialPrice: 181.25)) {
    FinancialDashboardLiveActivity()
} contentStates: {
    FinancialDashboardAttributes.ContentState(
        symbol: "AAPL",
        price: 181.25,
        previousPrice: 181.17,
        change: 1.75,
        percentChange: 0.98,
        lastUpdateTime: Date()
    )
}

#Preview(as: .dynamicIsland(.expanded), using: FinancialDashboardAttributes(symbol: "AAPL", initialPrice: 181.25)) {
    FinancialDashboardLiveActivity()
} contentStates: {
    FinancialDashboardAttributes.ContentState(
        symbol: "AAPL",
        price: 181.25,
        previousPrice: 181.17,
        change: 1.75,
        percentChange: 0.98,
        lastUpdateTime: Date()
    )
}

#Preview(as: .content, using: FinancialDashboardAttributes(symbol: "AAPL", initialPrice: 181.25)) {
    FinancialDashboardLiveActivity()
} contentStates: {
    FinancialDashboardAttributes.ContentState(
        symbol: "AAPL",
        price: 181.25,
        previousPrice: 181.17,
        change: 1.75,
        percentChange: 0.98,
        lastUpdateTime: Date()
    )
} 