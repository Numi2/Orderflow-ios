import SwiftUI

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