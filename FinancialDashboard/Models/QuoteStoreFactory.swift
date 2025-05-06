import Foundation

/// Available storage types for the QuoteStore
enum QuoteStoreType {
    case memory
    case coreData
    case sqlite
}

/// Factory for creating QuoteStore instances
final class QuoteStoreFactory {
    // MARK: - Properties
    
    /// Shared instance of the factory
    static let shared = QuoteStoreFactory()
    
    /// Default store type
    private let defaultStoreType: QuoteStoreType = .memory
    
    /// Cached store instances
    private var stores: [QuoteStoreType: QuoteStore] = [:]
    
    // MARK: - Public API
    
    /// Get a QuoteStore of the specified type
    /// - Parameter type: The type of store to create
    /// - Returns: A QuoteStore instance
    func getStore(_ type: QuoteStoreType? = nil) throws -> QuoteStore {
        let storeType = type ?? defaultStoreType
        
        // Return cached store if available
        if let store = stores[storeType] {
            return store
        }
        
        // Create new store
        let store: QuoteStore
        
        switch storeType {
        case .memory:
            store = InMemoryQuoteStore()
        case .coreData:
            store = try CoreDataQuoteStore()
        case .sqlite:
            // Create SQLite store with file in Documents directory
            let fileManager = FileManager.default
            let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbURL = docsURL.appendingPathComponent("financial_data.sqlite")
            store = try SQLiteQuoteStore(dbPath: dbURL.path)
        }
        
        // Cache the store
        stores[storeType] = store
        
        return store
    }
    
    /// Clear the cache of store instances
    func clearCache() {
        stores.removeAll()
    }
}

/// Extension for UserDefaults to manage store type preference
extension UserDefaults {
    private enum Keys {
        static let storeType = "quote_store_type"
    }
    
    /// Get the preferred QuoteStoreType
    var preferredStoreType: QuoteStoreType {
        get {
            guard let typeString = string(forKey: Keys.storeType) else {
                return .memory
            }
            
            switch typeString {
            case "memory":
                return .memory
            case "coreData":
                return .coreData
            case "sqlite":
                return .sqlite
            default:
                return .memory
            }
        }
        set {
            let typeString: String
            
            switch newValue {
            case .memory:
                typeString = "memory"
            case .coreData:
                typeString = "coreData"
            case .sqlite:
                typeString = "sqlite"
            }
            
            set(typeString, forKey: Keys.storeType)
        }
    }
} 