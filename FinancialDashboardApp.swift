import SwiftUI

// Constants for app configuration
enum AppConfig {
    /// App Group identifier for sharing data with widgets
    static let appGroupIdentifier = "group.com.financialdashboard"
    
    /// Storage type preference key
    static let storageTypeKey = "storage_type_preference"
}

/// Secrets for API keys (would be injected at build time)
enum Secrets {
    static let alphaVantageKey = "YOUR_ALPHA_VANTAGE_KEY"
    static let polygonKey = "YOUR_POLYGON_KEY"
    static let binanceKey = "YOUR_BINANCE_KEY" 
    static let binanceSecret = "YOUR_BINANCE_SECRET"
}

@main
struct FinancialDashboardApp: App {
    // MARK: - State Objects
    
    /// Main view model for the dashboard
    @StateObject private var vm: DashboardViewModel
    
    /// Theme manager
    @StateObject private var themeManager = ThemeManager()
    
    /// Price alert manager
    @StateObject private var alertManager = PriceAlertManager()
    
    // MARK: - User Defaults for Settings
    
    /// User defaults for app settings
    @AppStorage(AppConfig.storageTypeKey) private var storageTypePreference: String = "memory"
    
    // MARK: - Init
    
    init() {
        // Create services based on available keys
        let services = createServices()
        
        // Get storage type preference
        let storeType: QuoteStoreType
        switch storageTypePreference {
        case "coreData":
            storeType = .coreData
        case "sqlite":
            storeType = .sqlite
        default:
            storeType = .memory
        }
        
        // Create view model
        let viewModel = DashboardViewModel(
            services: services,
            storeType: storeType,
            appGroupIdentifier: AppConfig.appGroupIdentifier
        )
        
        // Register as state object
        _vm = StateObject(wrappedValue: viewModel)
        
        // Setup alert handling
        setupPriceAlertHandler()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                DashboardView()
                    .environmentObject(vm)
                    .environmentObject(themeManager)
                    .environmentObject(alertManager)
            }
            .onChange(of: themeManager.themeMode) { _ in
                // Update theme in UI components that need it
                updateThemeInUIComponents()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create the API services
    /// - Returns: Array of API services
    private func createServices() -> [any APIService] {
        var services: [any APIService] = []
        
        // Add services based on available API keys
        let keychainManager = KeychainManager(service: "com.financialdashboard")
        
        // Polygon service
        if let polygonKey = keychainManager.retrievePolygonApiKey() {
            services.append(AlphaVantageService(apiKey: polygonKey))
        } else {
            // Use default key for development
            services.append(AlphaVantageService(apiKey: Secrets.alphaVantageKey))
        }
        
        // Binance service (no key needed for public API)
        services.append(CoinGeckoService())
        
        return services
    }
    
    /// Setup handler for checking price alerts when prices update
    private func setupPriceAlertHandler() {
        // Observe quote updates from the view model
        NotificationCenter.default.addObserver(
            forName: .quoteUpdated,
            object: nil,
            queue: .main
        ) { [weak alertManager] notification in
            guard let alertManager = alertManager,
                  let userInfo = notification.userInfo,
                  let symbol = userInfo["symbol"] as? String,
                  let price = userInfo["price"] as? Double else {
                return
            }
            
            // Check if any alerts should trigger for this price update
            alertManager.checkAlerts(symbol: symbol, price: price)
        }
    }
    
    /// Update theme in UI components that don't automatically receive updates
    private func updateThemeInUIComponents() {
        // Update chart appearance when theme changes
        let colors = themeManager.colors
        
        // Update UIAppearance defaults - these affect all instances of the respective controls
        BarChartContentView.appearance().upColor = colors.upColor
        BarChartContentView.appearance().downColor = colors.downColor
    }
}