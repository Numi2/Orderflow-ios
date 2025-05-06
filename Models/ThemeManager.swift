import SwiftUI

/// Available theme modes
enum ThemeMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

/// Theme colors for the app
struct ThemeColors {
    // Bar chart colors
    let upColor: UIColor
    let downColor: UIColor
    
    // Background colors
    let backgroundColor: UIColor
    let cardBackgroundColor: UIColor
    
    // Grid/axis colors
    let gridColor: UIColor
    let axisColor: UIColor
    
    // Text colors
    let primaryTextColor: UIColor
    let secondaryTextColor: UIColor
    
    // Crosshair colors
    let crosshairColor: UIColor
    
    // Initialize with default light/dark mode colors
    init(style: UIUserInterfaceStyle) {
        switch style {
        case .dark:
            upColor = UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0)  // Brighter green
            downColor = UIColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1.0) // Brighter red
            backgroundColor = UIColor.systemBackground
            cardBackgroundColor = UIColor.secondarySystemBackground
            gridColor = UIColor.systemGray.withAlphaComponent(0.3)
            axisColor = UIColor.systemGray
            primaryTextColor = UIColor.label
            secondaryTextColor = UIColor.secondaryLabel
            crosshairColor = UIColor.systemGray.withAlphaComponent(0.7)
            
        default: // .light or .unspecified
            upColor = UIColor(red: 0.0, green: 0.7, blue: 0.4, alpha: 1.0)
            downColor = UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
            backgroundColor = UIColor.systemBackground
            cardBackgroundColor = UIColor.secondarySystemBackground
            gridColor = UIColor.systemGray.withAlphaComponent(0.2)
            axisColor = UIColor.systemGray2
            primaryTextColor = UIColor.label
            secondaryTextColor = UIColor.secondaryLabel
            crosshairColor = UIColor.systemGray.withAlphaComponent(0.5)
        }
    }
}

/// Manager for handling app themes
final class ThemeManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current theme colors
    @Published private(set) var colors: ThemeColors
    
    /// Current theme mode
    @Published var themeMode: ThemeMode {
        didSet {
            applyTheme()
            UserDefaults.standard.set(themeMode.rawValue, forKey: themePreferenceKey)
        }
    }
    
    // MARK: - Private Properties
    
    /// Key for storing theme preference
    private let themePreferenceKey = "app_theme_preference"
    
    /// Notification observer for user interface style changes
    private var styleObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    init() {
        // Load saved theme preference or default to system
        let savedTheme = UserDefaults.standard.string(forKey: themePreferenceKey) ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: savedTheme) ?? .system
        
        // Initialize with current interface style
        let currentStyle = UITraitCollection.current.userInterfaceStyle
        self.colors = ThemeColors(style: currentStyle)
        
        // Observe interface style changes when using system theme
        setupStyleObserver()
    }
    
    deinit {
        if let observer = styleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    /// Set a specific theme mode
    /// - Parameter mode: The theme mode to set
    func setTheme(_ mode: ThemeMode) {
        self.themeMode = mode
    }
    
    // MARK: - Private Methods
    
    /// Apply the current theme
    private func applyTheme() {
        switch themeMode {
        case .light:
            colors = ThemeColors(style: .light)
            if #available(iOS 15.0, *) {
                // Force light mode in app
                UIApplication.shared.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .light
                }
            }
            
        case .dark:
            colors = ThemeColors(style: .dark)
            if #available(iOS 15.0, *) {
                // Force dark mode in app
                UIApplication.shared.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
            
        case .system:
            // Use system setting and observe changes
            if #available(iOS 15.0, *) {
                UIApplication.shared.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .unspecified
                }
            }
            
            // Set colors based on current trait collection
            let currentStyle = UITraitCollection.current.userInterfaceStyle
            colors = ThemeColors(style: currentStyle)
        }
    }
    
    /// Setup observer for system interface style changes
    private func setupStyleObserver() {
        // Remove existing observer if any
        if let observer = styleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Observe trait collection changes
        styleObserver = NotificationCenter.default.addObserver(
            forName: UITraitCollection.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.themeMode == .system else { return }
            
            // Update colors when system appearance changes
            let currentStyle = UITraitCollection.current.userInterfaceStyle
            self.colors = ThemeColors(style: currentStyle)
        }
    }
}

// MARK: - SwiftUI Environment Support

// Create a SwiftUI environment key for the theme manager
struct ThemeManagerKey: EnvironmentKey {
    static var defaultValue = ThemeManager()
}

// Extend the environment values
extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// Convenience environment property wrapper
extension View {
    func environmentThemeManager(_ themeManager: ThemeManager) -> some View {
        environment(\.themeManager, themeManager)
    }
} 