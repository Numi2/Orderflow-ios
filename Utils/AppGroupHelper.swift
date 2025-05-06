import Foundation

/// Helper for interacting with App Groups to share data between app and widgets
final class AppGroupHelper {
    // MARK: - Properties
    
    /// App Group identifier
    private let appGroupIdentifier: String
    
    /// UserDefaults for the App Group
    private let sharedDefaults: UserDefaults
    
    /// Shared file manager
    private let fileManager = FileManager.default
    
    // MARK: - Keys for shared data
    private enum Keys {
        static let lastUpdated = "lastUpdated"
        static let stockQuotes = "stockQuotes"
        static let cryptoQuotes = "cryptoQuotes"
        static let watchlist = "watchlist"
    }
    
    // MARK: - Init
    
    /// Initialize with App Group identifier
    /// - Parameter appGroupIdentifier: The App Group identifier
    init?(appGroupIdentifier: String) {
        self.appGroupIdentifier = appGroupIdentifier
        
        // Attempt to get UserDefaults for the App Group
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return nil
        }
        
        self.sharedDefaults = defaults
    }
    
    // MARK: - Public API
    
    /// Get the shared container URL for storing files
    /// - Returns: URL for the shared container
    func sharedContainerURL() -> URL? {
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// Save stock quotes to shared UserDefaults
    /// - Parameter quotes: The quotes to save
    func saveStockQuotes(_ quotes: [StockQuote]) {
        // Convert quotes to dictionaries for storage
        let data = quotes.map { quote -> [String: Any] in
            return [
                "symbol": quote.symbol,
                "name": quote.name,
                "price": quote.price,
                "changePercent": quote.changePercent
            ]
        }
        
        sharedDefaults.set(data, forKey: Keys.stockQuotes)
        updateLastUpdated()
    }
    
    /// Get stock quotes from shared UserDefaults
    /// - Returns: Array of stock quotes
    func getStockQuotes() -> [StockQuote] {
        guard let data = sharedDefaults.array(forKey: Keys.stockQuotes) as? [[String: Any]] else {
            return []
        }
        
        return data.compactMap { dict in
            guard let symbol = dict["symbol"] as? String,
                  let name = dict["name"] as? String,
                  let price = dict["price"] as? Double,
                  let changePercent = dict["changePercent"] as? Double else {
                return nil
            }
            
            return StockQuote(
                symbol: symbol,
                name: name,
                price: price,
                changePercent: changePercent
            )
        }
    }
    
    /// Save crypto quotes to shared UserDefaults
    /// - Parameter quotes: The quotes to save
    func saveCryptoQuotes(_ quotes: [CryptoQuote]) {
        // Convert quotes to dictionaries for storage
        let data = quotes.map { quote -> [String: Any] in
            return [
                "symbol": quote.symbol,
                "name": quote.name,
                "price": quote.price,
                "changePercent": quote.changePercent
            ]
        }
        
        sharedDefaults.set(data, forKey: Keys.cryptoQuotes)
        updateLastUpdated()
    }
    
    /// Get crypto quotes from shared UserDefaults
    /// - Returns: Array of crypto quotes
    func getCryptoQuotes() -> [CryptoQuote] {
        guard let data = sharedDefaults.array(forKey: Keys.cryptoQuotes) as? [[String: Any]] else {
            return []
        }
        
        return data.compactMap { dict in
            guard let symbol = dict["symbol"] as? String,
                  let name = dict["name"] as? String,
                  let price = dict["price"] as? Double,
                  let changePercent = dict["changePercent"] as? Double else {
                return nil
            }
            
            return CryptoQuote(
                symbol: symbol,
                name: name,
                price: price,
                changePercent: changePercent
            )
        }
    }
    
    /// Save watchlist to shared UserDefaults
    /// - Parameter symbols: The symbols in the watchlist
    func saveWatchlist(_ symbols: [String]) {
        sharedDefaults.set(symbols, forKey: Keys.watchlist)
    }
    
    /// Get watchlist from shared UserDefaults
    /// - Returns: Array of symbols in the watchlist
    func getWatchlist() -> [String] {
        return sharedDefaults.stringArray(forKey: Keys.watchlist) ?? []
    }
    
    /// Get the time of the last data update
    /// - Returns: Date of last update or nil if never updated
    func getLastUpdated() -> Date? {
        return sharedDefaults.object(forKey: Keys.lastUpdated) as? Date
    }
    
    /// Save a file to the shared container
    /// - Parameters:
    ///   - data: The data to save
    ///   - filename: The filename
    /// - Returns: URL of the saved file or nil if failed
    func saveFile(_ data: Data, filename: String) -> URL? {
        guard let containerURL = sharedContainerURL() else { return nil }
        
        let fileURL = containerURL.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving file to shared container: \(error)")
            return nil
        }
    }
    
    /// Load a file from the shared container
    /// - Parameter filename: The filename
    /// - Returns: The file data or nil if not found
    func loadFile(filename: String) -> Data? {
        guard let containerURL = sharedContainerURL() else { return nil }
        
        let fileURL = containerURL.appendingPathComponent(filename)
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("Error loading file from shared container: \(error)")
            return nil
        }
    }
    
    // MARK: - Private methods
    
    /// Update the last updated timestamp
    private func updateLastUpdated() {
        sharedDefaults.set(Date(), forKey: Keys.lastUpdated)
    }
} 