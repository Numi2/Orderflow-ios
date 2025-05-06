import SwiftUI
import Foundation

protocol QuoteData: Identifiable {
    var symbol: String { get }
    var name: String { get }
    var price: Double { get }
    var changePercent: Double { get }
}

struct StockQuote: QuoteData, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let changePercent: Double
}

@main
struct FinancialDashboardApp: App {
    @StateObject private var vm = DashboardViewModel(
        services: [
            AlphaVantageService(apiKey: Secrets.alphaVantageKey),
            CoinGeckoService()
        ])
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DashboardView()
                    .environmentObject(vm)
            }
        }
    }
}