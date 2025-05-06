// Networking/AlphaVantageService.swift
import Foundation

final class AlphaVantageService: APIService {
    typealias Quote = StockQuote

    private let apiKey: String
    private let symbols = ["AAPL", "MSFT", "AMZN", "NVDA"]

    init(apiKey: String) { self.apiKey = apiKey }

    func latestQuotes() async throws -> [any QuoteData] {
        // Mock implementation - would fetch from API in production
        return [
            StockQuote(symbol: "AAPL", name: "Apple Inc.", price: 187.32, changePercent: 1.2),
            StockQuote(symbol: "MSFT", name: "Microsoft Corp.", price: 378.85, changePercent: 0.8),
            StockQuote(symbol: "AMZN", name: "Amazon.com Inc.", price: 184.22, changePercent: -0.5),
            StockQuote(symbol: "NVDA", name: "NVIDIA Corp.", price: 947.50, changePercent: 2.3),
            StockQuote(symbol: "GOOG", name: "Alphabet Inc.", price: 167.28, changePercent: 0.3)
        ]
    }

    func getChartData(for symbol: String) async throws -> [ChartDataPoint] {
        // In a real app, we would fetch this from the API
        // For demo purposes, generate random OHLC data
        let calendar = Calendar.current
        var chartData: [ChartDataPoint] = []
        let endDate = Date()
        
        // Generate daily data for 30 days
        for day in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -day, to: endDate) else { continue }
            
            // Generate price based on random walk
            let basePrice = Double.random(in: 100...200)
            let range = basePrice * 0.02 // 2% daily range
            
            let open = basePrice
            let high = open + Double.random(in: 0...range)
            let low = open - Double.random(in: 0...range)
            let close = Double.random(in: low...high)
            
            // Volume based on symbol
            let volume = Double.random(in: 1_000_000...10_000_000)
            let bidVolume = volume * Double.random(in: 0.4...0.6)
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

    var name: String { "Alpha Vantage" }
}