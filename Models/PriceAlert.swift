import Foundation
import UIKit

/// Types of price alerts
enum AlertType: Int, CaseIterable, Identifiable, Codable {
    case priceAbove
    case priceBelow
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .priceAbove: return "Price Above"
        case .priceBelow: return "Price Below"
        }
    }
}

/// A single price alert
struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let price: Double
    let type: AlertType
    var isActive: Bool
    var lastTriggered: Date?
    
    // Minimum time between alert triggers (prevents constant triggering)
    static let cooldownInterval: TimeInterval = 60 * 5 // 5 minutes
    
    init(symbol: String, price: Double, type: AlertType, isActive: Bool = true) {
        self.id = UUID()
        self.symbol = symbol
        self.price = price
        self.type = type
        self.isActive = isActive
        self.lastTriggered = nil
    }
    
    /// Check if alert should trigger for given price
    /// - Parameter currentPrice: Current price to check against alert
    /// - Returns: True if alert should trigger
    func shouldTrigger(for currentPrice: Double) -> Bool {
        // Don't trigger if alert is inactive
        guard isActive else { return false }
        
        // Check if we're in cooldown period
        if let lastTriggered = lastTriggered {
            let timeElapsed = Date().timeIntervalSince(lastTriggered)
            guard timeElapsed >= PriceAlert.cooldownInterval else { return false }
        }
        
        // Check price condition
        switch type {
        case .priceAbove:
            return currentPrice >= price
        case .priceBelow:
            return currentPrice <= price
        }
    }
}

/// Manager for price alerts
final class PriceAlertManager: ObservableObject {
    // MARK: - Published Properties
    
    /// All active alerts
    @Published private(set) var alerts: [PriceAlert] = []
    
    // MARK: - Private Properties
    
    /// Key for storing alerts
    private let alertsStorageKey = "price_alerts"
    
    /// Feedback generator for haptics
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Init
    
    init() {
        loadAlerts()
        
        // Prepare haptics
        feedbackGenerator.prepare()
    }
    
    // MARK: - Public Methods
    
    /// Add a new price alert
    /// - Parameters:
    ///   - symbol: Symbol to alert on
    ///   - price: Price threshold
    ///   - type: Type of alert
    func addAlert(symbol: String, price: Double, type: AlertType) {
        let newAlert = PriceAlert(symbol: symbol, price: price, type: type)
        alerts.append(newAlert)
        saveAlerts()
    }
    
    /// Remove a specific alert
    /// - Parameter id: ID of alert to remove
    func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
        saveAlerts()
    }
    
    /// Clear all alerts
    func clearAllAlerts() {
        alerts.removeAll()
        saveAlerts()
    }
    
    /// Get alerts for a specific symbol
    /// - Parameter symbol: Symbol to get alerts for
    /// - Returns: Array of alerts
    func alertsForSymbol(_ symbol: String) -> [PriceAlert] {
        return alerts.filter { $0.symbol == symbol }
    }
    
    /// Toggle an alert active state
    /// - Parameter id: ID of alert to toggle
    func toggleAlert(id: UUID) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isActive.toggle()
            saveAlerts()
        }
    }
    
    /// Check if any alerts should trigger for a price update
    /// - Parameters:
    ///   - symbol: Symbol that was updated
    ///   - price: Current price
    func checkAlerts(symbol: String, price: Double) {
        var updatedAlerts = false
        
        for (index, alert) in alerts.enumerated() where alert.symbol == symbol {
            if alert.shouldTrigger(for: price) {
                // Trigger alert
                triggerAlert(alert)
                
                // Mark as triggered
                alerts[index].lastTriggered = Date()
                updatedAlerts = true
            }
        }
        
        if updatedAlerts {
            saveAlerts()
        }
    }
    
    // MARK: - Private Methods
    
    /// Trigger a specific alert with haptic feedback
    /// - Parameter alert: Alert that was triggered
    private func triggerAlert(_ alert: PriceAlert) {
        // Generate haptic feedback
        feedbackGenerator.notificationOccurred(.warning)
        
        // Post notification
        let userInfo: [String: Any] = [
            "symbol": alert.symbol,
            "price": alert.price,
            "type": alert.type.description
        ]
        
        NotificationCenter.default.post(
            name: .priceAlertTriggered,
            object: nil,
            userInfo: userInfo
        )
    }
    
    /// Save alerts to persistent storage
    private func saveAlerts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(alerts)
            UserDefaults.standard.set(data, forKey: alertsStorageKey)
        } catch {
            print("Error saving alerts: \(error)")
        }
    }
    
    /// Load alerts from persistent storage
    private func loadAlerts() {
        guard let data = UserDefaults.standard.data(forKey: alertsStorageKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            alerts = try decoder.decode([PriceAlert].self, from: data)
        } catch {
            print("Error loading alerts: \(error)")
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let priceAlertTriggered = Notification.Name("priceAlertTriggered")
} 