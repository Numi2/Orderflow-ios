// Networking/CoinGeckoService.swift
import Foundation

final class CoinGeckoService: APIService {
    typealias Quote = CryptoQuote
    private let ids = ["bitcoin", "ethereum", "dogecoin"]

    func latestQuotes() async throws -> [any QuoteData] {
        let url = URL(string:
          "https://api.coingecko.com/api/v3/simple/price?ids=\(ids.joined(separator: ","))&vs_currencies=usd&include_24hr_change=true")!
        struct Response: Decodable { let usd: Double?; let usd_24h_change: Double? }
        let dict = try await NetworkClient.shared.fetch(url, as: [String:Response].self)

        let symbols = [
            "bitcoin": ("BTC", "Bitcoin"),
            "ethereum": ("ETH", "Ethereum"),
            "dogecoin": ("DOGE", "Dogecoin")
        ]

        var quotes: [CryptoQuote] = []
        for id in ids {
            guard let r = dict[id], let price = r.usd, let ch = r.usd_24h_change else { continue }
            let mapping = symbols[id] ?? (id.uppercased(), id.capitalized)
            let quote = CryptoQuote(symbol: mapping.0, name: mapping.1, price: price, changePercent: ch)
            quotes.append(quote)
        }

        return quotes
    }

    func getChartData(for symbol: String) async throws -> [ChartDataPoint] {
        let idMap = ["BTC": "bitcoin", "ETH": "ethereum", "DOGE": "dogecoin"]
        let id = idMap[symbol] ?? symbol.lowercased()
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/\(id)/ohlc?vs_currency=usd&days=7")!

        let raw = try await NetworkClient.shared.fetch(url, as: [[Double]].self)

        let points = raw.compactMap { arr -> ChartDataPoint? in
            guard arr.count == 5 else { return nil }
            let date = Date(timeIntervalSince1970: arr[0] / 1000)
            return ChartDataPoint(
                time: date,
                open: arr[1],
                high: arr[2],
                low: arr[3],
                close: arr[4],
                volume: 0,
                bidVolume: 0,
                askVolume: 0
            )
        }

        return points.sorted { $0.time < $1.time }
    }

    var name: String { "CoinGecko" }
}
