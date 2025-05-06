import Foundation
import ActivityKit
import Combine

/// Manager for Live Activities
@MainActor
final class LiveActivityManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently active Live Activity
    @Published private(set) var activeActivity: Activity<FinancialDashboardAttributes>?
    
    /// Whether Live Activity is supported
    private(set) var isSupported: Bool
    
    // MARK: - Private Properties
    
    /// Subscription to price updates
    private var priceSubscription: AnyCancellable?
    
    /// Cache of last seen prices
    private var lastPrices: [String: Double] = [:]
    
    // MARK: - Init
    
    init() {
        // Check if Live Activity is supported
        if #available(iOS 16.1, *) {
            isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            isSupported = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a Live Activity for a symbol
    /// - Parameters:
    ///   - symbol: Symbol to track
    ///   - initialPrice: Initial price for the symbol
    @available(iOS 16.1, *)
    func startActivity(for symbol: String, initialPrice: Double) async {
        // First, end any existing activity
        await endActivity()
        
        // Store initial price
        lastPrices[symbol] = initialPrice
        
        // Create the activity
        let attributes = FinancialDashboardAttributes(
            symbol: symbol,
            initialPrice: initialPrice
        )
        
        let initialContentState = FinancialDashboardAttributes.ContentState(
            symbol: symbol,
            price: initialPrice,
            previousPrice: initialPrice,
            change: 0.0,
            percentChange: 0.0,
            lastUpdateTime: Date()
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialContentState,
                pushType: nil
            )
            
            activeActivity = activity
            
            // Set up subscription for price updates
            setupPriceSubscription(for: symbol, initialPrice: initialPrice)
        } catch {
            print("Error starting Live Activity: \(error)")
        }
    }
    
    /// Update the active Live Activity with a new price
    /// - Parameters:
    ///   - symbol: Symbol to update
    ///   - price: New price
    ///   - change: Change amount
    ///   - percentChange: Percentage change
    @available(iOS 16.1, *)
    func updateActivity(for symbol: String, price: Double, change: Double, percentChange: Double) async {
        guard let activity = activeActivity, activity.attributes.symbol == symbol else {
            return
        }
        
        // Get previous price
        let previousPrice = lastPrices[symbol] ?? price
        
        // Store new price
        lastPrices[symbol] = price
        
        // Create new content state
        let updatedContentState = FinancialDashboardAttributes.ContentState(
            symbol: symbol,
            price: price,
            previousPrice: previousPrice,
            change: change,
            percentChange: percentChange,
            lastUpdateTime: Date()
        )
        
        // Update the activity
        await activity.update(using: updatedContentState)
    }
    
    /// End the active Live Activity
    @available(iOS 16.1, *)
    func endActivity() async {
        guard let activity = activeActivity else {
            return
        }
        
        // Cancel price subscription
        priceSubscription?.cancel()
        priceSubscription = nil
        
        // End the activity
        await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
        
        // Clear active activity
        activeActivity = nil
    }
    
    /// Check if a symbol has an active Live Activity
    /// - Parameter symbol: Symbol to check
    /// - Returns: True if the symbol has an active Live Activity
    func hasActiveActivity(for symbol: String) -> Bool {
        return activeActivity?.attributes.symbol == symbol
    }
    
    // MARK: - Private Methods
    
    /// Set up subscription for price updates
    /// - Parameters:
    ///   - symbol: Symbol to track
    ///   - initialPrice: Initial price for the symbol
    @available(iOS 16.1, *)
    private func setupPriceSubscription(for symbol: String, initialPrice: Double) {
        // Cancel existing subscription
        priceSubscription?.cancel()
        
        // Subscribe to price updates from WebSocket feed
        let binanceClient = BinanceClient()
        binanceClient.connect()
        binanceClient.subscribe(to: symbol)
        
        // Create publisher for price updates
        priceSubscription = NotificationCenter.default.publisher(for: .quoteUpdated)
            .filter { notification in
                if let notificationSymbol = notification.userInfo?["symbol"] as? String {
                    return notificationSymbol == symbol
                }
                return false
            }
            .sink { [weak self] notification in
                guard let self = self,
                      let price = notification.userInfo?["price"] as? Double else {
                    return
                }
                
                // Calculate change
                let reference = initialPrice
                let change = price - reference
                let percentChange = reference > 0 ? (change / reference) * 100 : 0
                
                // Update the Live Activity
                Task {
                    await self.updateActivity(
                        for: symbol,
                        price: price,
                        change: change,
                        percentChange: percentChange
                    )
                }
            }
    }
} 