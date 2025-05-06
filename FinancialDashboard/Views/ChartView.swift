import SwiftUI

/// SwiftUI wrapper for TradingChartContainer
struct ChartView: UIViewRepresentable {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var data: [ChartDataPoint]
    var chartType: ChartType = .ohlc
    
    func makeUIView(context: Context) -> TradingChartContainer {
        let container = TradingChartContainer()
        container.setChartType(chartType)
        
        // Apply initial theme
        container.applyTheme(colors: themeManager.colors)
        
        return container
    }
    
    func updateUIView(_ uiView: TradingChartContainer, context: Context) {
        uiView.points = data
        uiView.setChartType(chartType)
        
        // Apply theme when it changes
        uiView.applyTheme(colors: themeManager.colors)
    }
    
    static func dismantleUIView(_ uiView: TradingChartContainer, coordinator: ()) {
        // Clean up resources if needed when view is removed
    }
}

/// View modifier to add a chart type picker toolbar
struct ChartToolbarModifier: ViewModifier {
    @Binding var chartType: ChartType
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Picker("Chart Type", selection: $chartType) {
                        Text("OHLC").tag(ChartType.ohlc)
                        Text("Candlestick").tag(ChartType.candlestick)
                        Text("Heikin-Ashi").tag(ChartType.heikinAshi)
                        Text("Renko").tag(ChartType.renko)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
    }
}

extension View {
    func chartTypeToolbar(chartType: Binding<ChartType>) -> some View {
        self.modifier(ChartToolbarModifier(chartType: chartType))
    }
} 