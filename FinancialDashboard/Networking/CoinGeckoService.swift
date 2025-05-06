// Networking/CoinGeckoService.swift
import Foundation

final class CoinGeckoService: APIService {
    typealias Quote = CryptoQuote
    private let ids = ["bitcoin", "ethereum", "dogecoin"]

    func latestQuotes() async throws -> [any QuoteData] {
        // Mock implementation - would fetch from API in production
        return [
            CryptoQuote(symbol: "BTC", name: "Bitcoin", price: 67245.12, changePercent: 1.8),
            CryptoQuote(symbol: "ETH", name: "Ethereum", price: 3487.65, changePercent: 0.5),
            CryptoQuote(symbol: "SOL", name: "Solana", price: 165.34, changePercent: 3.2),
            CryptoQuote(symbol: "ADA", name: "Cardano", price: 0.532, changePercent: -1.3),
            CryptoQuote(symbol: "DOT", name: "Polkadot", price: 6.82, changePercent: -0.7)
        ]
    }

    func latestQuotes() async throws -> [CryptoQuote] {
        let url = URL(string:
          "https://api.coingecko.com/api/v3/simple/price?ids=\(ids.joined(separator: ","))&vs_currencies=usd&include_24hr_change=true")!
        struct Response: Decodable { let usd: Double?; let usd_24h_change: Double? }
        let dict = try await NetworkClient.shared.fetch(url, as: [String:Response].self)
        return ids.compactMap { id in
            guard let r = dict[id], let price = r.usd, let ch = r.usd_24h_change else { return nil }
            return CryptoQuote(id: id, symbol: id.prefix(3).uppercased(), price: price,
                               change24h: ch, timestamp: .init())
        }
    }

    func getChartData(for symbol: String) async throws -> [ChartDataPoint] {
        // In a real app, we would fetch this from the API
        // For demo purposes, generate random OHLC data with more volatility for crypto
        let calendar = Calendar.current
        var chartData: [ChartDataPoint] = []
        let endDate = Date()
        
        // Generate hourly data for 7 days
        for hour in 0..<(24 * 7) {
            guard let date = calendar.date(byAdding: .hour, value: -hour, to: endDate) else { continue }
            
            // Generate price based on random walk with higher volatility
            let basePrice: Double
            switch symbol {
            case "BTC": basePrice = Double.random(in: 60000...70000)
            case "ETH": basePrice = Double.random(in: 3000...4000)
            case "SOL": basePrice = Double.random(in: 150...180)
            case "ADA": basePrice = Double.random(in: 0.5...0.6)
            case "DOT": basePrice = Double.random(in: 6...8)
            default: basePrice = Double.random(in: 100...1000)
            }
            
            let range = basePrice * 0.05 // 5% hourly range for crypto
            
            let open = basePrice
            let high = open + Double.random(in: 0...range)
            let low = open - Double.random(in: 0...range)
            let close = Double.random(in: low...high)
            
            // Volume based on symbol
            let volume = Double.random(in: 10_000...1_000_000)
            let bidVolume = volume * Double.random(in: 0.3...0.7) // More volatility in bid/ask
            let askVolume = volume - bidVolume
            
            let point = ChartDataPoint(
                time: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                bidVolume: bidVolume,
                askVolume: askVolume
            )
            
            chartData.append(point)
        }
        
        // Sort by date, oldest first
        return chartData.sorted(by: { $0.time < $1.time })
    }

    var name: String { "CoinGecko" }
}