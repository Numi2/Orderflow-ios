import Foundation
import Security

/// Manager for securely storing and retrieving sensitive data in the Keychain
final class KeychainManager {
    // MARK: - Properties
    
    /// Service identifier for the keychain items
    private let service: String
    
    /// Access group for sharing keychain items between apps (e.g., app extensions)
    private let accessGroup: String?
    
    // MARK: - Init
    
    /// Initialize with a service identifier and optional access group
    /// - Parameters:
    ///   - service: The service identifier
    ///   - accessGroup: Optional access group for sharing keychain items
    init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public API
    
    /// Save a string value to the keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - account: The account identifier
    /// - Returns: True if the operation was successful
    @discardableResult
    func save(_ value: String, for account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, for: account)
    }
    
    /// Save data to the keychain
    /// - Parameters:
    ///   - data: The data to save
    ///   - account: The account identifier
    /// - Returns: True if the operation was successful
    @discardableResult
    func save(_ data: Data, for account: String) -> Bool {
        // Create query dictionary
        var query = baseQuery(for: account)
        
        // Set attributes for the new item
        query[kSecValueData as String] = data
        
        // Check if item already exists
        if retrieve(for: account) != nil {
            // Update existing item
            let attributesToUpdate = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            return status == errSecSuccess
        } else {
            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        }
    }
    
    /// Retrieve a string value from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The stored string value or nil if not found
    func retrieveString(for account: String) -> String? {
        guard let data = retrieve(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Retrieve data from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The stored data or nil if not found
    func retrieve(for account: String) -> Data? {
        // Create query dictionary
        var query = baseQuery(for: account)
        
        // Configure query for data retrieval
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        // Execute query
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Check if operation was successful
        if status == errSecSuccess, let data = result as? Data {
            return data
        } else {
            return nil
        }
    }
    
    /// Delete an item from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: True if the operation was successful
    @discardableResult
    func delete(for account: String) -> Bool {
        let query = baseQuery(for: account)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Delete all items for this service
    /// - Returns: True if the operation was successful
    @discardableResult
    func deleteAll() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Helper methods
    
    /// Create a base query dictionary for keychain operations
    /// - Parameter account: The account identifier
    /// - Returns: The query dictionary
    private func baseQuery(for account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

/// Extension for storing, retrieving, and managing API keys
extension KeychainManager {
    // MARK: - API Key Constants
    static let polygonApiKeyAccount = "polygon_api_key"
    static let binanceApiKeyAccount = "binance_api_key"
    static let binanceSecretKeyAccount = "binance_secret_key"
    
    /// Save a Polygon API key
    /// - Parameter apiKey: The API key to save
    /// - Returns: True if the operation was successful
    @discardableResult
    func savePolygonApiKey(_ apiKey: String) -> Bool {
        return save(apiKey, for: KeychainManager.polygonApiKeyAccount)
    }
    
    /// Retrieve the Polygon API key
    /// - Returns: The API key or nil if not found
    func retrievePolygonApiKey() -> String? {
        return retrieveString(for: KeychainManager.polygonApiKeyAccount)
    }
    
    /// Save Binance API credentials
    /// - Parameters:
    ///   - apiKey: The API key to save
    ///   - secretKey: The secret key to save
    /// - Returns: True if the operation was successful
    @discardableResult
    func saveBinanceCredentials(apiKey: String, secretKey: String) -> Bool {
        let apiKeySaved = save(apiKey, for: KeychainManager.binanceApiKeyAccount)
        let secretKeySaved = save(secretKey, for: KeychainManager.binanceSecretKeyAccount)
        return apiKeySaved && secretKeySaved
    }
    
    /// Retrieve the Binance API key
    /// - Returns: The API key or nil if not found
    func retrieveBinanceApiKey() -> String? {
        return retrieveString(for: KeychainManager.binanceApiKeyAccount)
    }
    
    /// Retrieve the Binance secret key
    /// - Returns: The secret key or nil if not found
    func retrieveBinanceSecretKey() -> String? {
        return retrieveString(for: KeychainManager.binanceSecretKeyAccount)
    }
    
    /// Delete all API keys
    /// - Returns: True if the operation was successful
    @discardableResult
    func deleteAllApiKeys() -> Bool {
        let polygonDeleted = delete(for: KeychainManager.polygonApiKeyAccount)
        let binanceApiDeleted = delete(for: KeychainManager.binanceApiKeyAccount)
        let binanceSecretDeleted = delete(for: KeychainManager.binanceSecretKeyAccount)
        return polygonDeleted && binanceApiDeleted && binanceSecretDeleted
    }
} 