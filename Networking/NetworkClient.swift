import Foundation

/// Simple shared network client for fetching decodable types.
final class NetworkClient {
    static let shared = NetworkClient()
    private init() {}

    /// Fetch a Decodable object from the given URL.
    /// - Parameters:
    ///   - url: Endpoint URL
    ///   - type: Expected Decodable type
    ///   - decoder: JSON decoder to use
    func fetch<T: Decodable>(_ url: URL, as type: T.Type, decoder: JSONDecoder = .init()) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(type, from: data)
    }
}
