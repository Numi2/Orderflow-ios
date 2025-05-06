// Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var chartType: ChartType = .ohlc
    @State private var selectedSymbol: String?
    @State private var showingAlertSettings = false
    @State private var showOrderBook = false
    @State private var isDetailPopoverPresented = false
    @State private var isReplayModeActive = false
    @State private var isDrawModeActive = false

    var body: some View {
        VStack {
            // Chart and Order Book Section
            if let selectedSymbol = selectedSymbol {
                VStack(spacing: 0) {
                    if let data = vm.chartData(for: selectedSymbol) {
                        ChartView(data: data, chartType: chartType)
                            .frame(height: 300)
                    } else {
                        ProgressView()
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                    }
                    
                    // Buttons to control what's shown
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Conditional buttons based on symbol type
                            if isCryptoSymbol(selectedSymbol) {
                                Button(action: {
                                    showOrderBook.toggle()
                                    
                                    // Load order book data if needed
                                    if showOrderBook && vm.orderBook(for: selectedSymbol) == nil {
                                        Task {
                                            await vm.loadOrderBook(for: selectedSymbol)
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: showOrderBook ? "chart.bar.xaxis" : "rectangle.grid.1x2")
                                        Text(showOrderBook ? "Show Chart" : "Show Order Book")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Replay mode button (available for all symbol types)
                            if let data = vm.chartData(for: selectedSymbol), !data.isEmpty {
                                Button(action: {
                                    isReplayModeActive = true
                                }) {
                                    HStack {
                                        Image(systemName: "play.circle")
                                        Text("Replay")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                                
                                // Drawing mode button (available for iPad with Apple Pencil)
                                if UIDevice.current.userInterfaceIdiom == .pad {
                                    Button(action: {
                                        isDrawModeActive = true
                                    }) {
                                        HStack {
                                            Image(systemName: "pencil.tip")
                                            Text("Draw")
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            Button(action: {
                                isDetailPopoverPresented = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("Details")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                            .popover(isPresented: $isDetailPopoverPresented) {
                                SymbolDetailView(symbol: selectedSymbol)
                                    .environmentObject(vm)
                                    .padding()
                                    .frame(width: 300, height: 300)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    // Order Book if selected and available
                    if showOrderBook, let orderBook = vm.orderBook(for: selectedSymbol) {
                        OrderBookHeatmapView(orderBook: orderBook)
                            .padding(.horizontal)
                            .frame(height: 300)
                            .transition(.opacity)
                    }
                }
                .fullScreenCover(isPresented: $isReplayModeActive) {
                    if let data = vm.chartData(for: selectedSymbol) {
                        ChartReplayView(isPresented: $isReplayModeActive, chartData: data, symbol: selectedSymbol)
                            .environmentObject(themeManager)
                    }
                }
                .fullScreenCover(isPresented: $isDrawModeActive) {
                    if let data = vm.chartData(for: selectedSymbol) {
                        ChartAnnotationView(isPresented: $isDrawModeActive, chartData: data, symbol: selectedSymbol)
                            .environmentObject(themeManager)
                    }
                }
            } else {
                Text("Select a symbol to view chart")
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
            
            // Symbol List
            List {
                Section("Stocks") {
                    ForEach(vm.stockQuotes) { quote in 
                        QuoteRow(quote: quote)
                            .onTapGesture {
                                handleSymbolSelection(quote.symbol)
                            }
                            .background(selectedSymbol == quote.symbol ? Color(.secondarySystemBackground) : Color.clear)
                    }
                }
                Section("Crypto") {
                    ForEach(vm.cryptoQuotes) { quote in
                        QuoteRow(quote: quote)
                            .onTapGesture {
                                handleSymbolSelection(quote.symbol)
                            }
                            .background(selectedSymbol == quote.symbol ? Color(.secondarySystemBackground) : Color.clear)
                    }
                }
            }
        }
        .navigationTitle("Dashboard")
        .refreshable { await vm.refreshAll() }
        .overlay(alignment: .center) {
            if vm.isRefreshing { ProgressView() }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { _ in vm.error = nil })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.error ?? "Unknown error")
        }
        .chartTypeToolbar(chartType: $chartType)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAlertSettings = true
                }) {
                    Label("Alerts", systemImage: "bell")
                }
            }
        }
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
                .environmentObject(vm)
        }
    }
    
    private func handleSymbolSelection(_ symbol: String) {
        // If selecting the same symbol, don't reset view state
        if selectedSymbol != symbol {
            selectedSymbol = symbol
            showOrderBook = false
        }
        
        Task { 
            await vm.loadChartData(for: symbol)
            
            // If we're already showing the order book, load it
            if showOrderBook && isCryptoSymbol(symbol) {
                await vm.loadOrderBook(for: symbol)
            }
        }
    }
    
    private func isCryptoSymbol(_ symbol: String) -> Bool {
        return vm.cryptoQuotes.contains { $0.symbol == symbol }
    }
}

/// Shows detailed information about a symbol
struct SymbolDetailView: View {
    @EnvironmentObject private var vm: DashboardViewModel
    let symbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(symbol)
                .font(.headline)
            
            if let quote = getQuote() {
                Group {
                    DetailRow(label: "Price", value: formatPrice(quote.price))
                    DetailRow(label: "Change", value: formatChange(quote.change, quote.percentChange))
                    DetailRow(label: "Volume", value: formatVolume(quote.volume))
                    
                    if let marketCap = getMarketCap() {
                        DetailRow(label: "Market Cap", value: formatCurrency(marketCap))
                    }
                }
            } else {
                Text("Loading...")
            }
            
            Spacer()
            
            Button(action: {
                if vm.watchlist.contains(symbol) {
                    vm.removeFromWatchlist(symbol)
                } else {
                    vm.addToWatchlist(symbol)
                }
            }) {
                Label(
                    vm.watchlist.contains(symbol) ? "Remove from Watchlist" : "Add to Watchlist",
                    systemImage: vm.watchlist.contains(symbol) ? "star.fill" : "star"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func getQuote() -> (any QuoteData)? {
        if let stock = vm.stockQuotes.first(where: { $0.symbol == symbol }) {
            return stock
        }
        
        if let crypto = vm.cryptoQuotes.first(where: { $0.symbol == symbol }) {
            return crypto
        }
        
        return nil
    }
    
    private func getMarketCap() -> Double? {
        if let crypto = vm.cryptoQuotes.first(where: { $0.symbol == symbol }) {
            return crypto.marketCap
        }
        return nil
    }
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
    
    private func formatChange(_ change: Double, _ percentChange: Double) -> String {
        return String(format: "%.2f (%.2f%%)", change, percentChange)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        return String(format: "%.0f", volume)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}