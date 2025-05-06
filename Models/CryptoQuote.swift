import Foundation

struct CryptoQuote: QuoteData, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let changePercent: Double
}
