// Networking/AlphaVantageService.swift
import Foundation

final class AlphaVantageService: APIService {
    typealias Quote = StockQuote

    private let apiKey: String
    private let symbols = ["AAPL", "MSFT", "AMZN", "NVDA"]

    init(apiKey: String) { self.apiKey = apiKey }

    func latestQuotes() async throws -> [any QuoteData] {
        var quotes: [StockQuote] = []

        for symbol in symbols {
            var components = URLComponents(string: "https://www.alphavantage.co/query")!
            components.queryItems = [
                URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
                URLQueryItem(name: "symbol", value: symbol),
                URLQueryItem(name: "apikey", value: apiKey)
            ]

            struct GlobalQuote: Decodable {
                let symbol: String
                let price: String
                let changePercent: String

                enum CodingKeys: String, CodingKey {
                    case symbol = "01. symbol"
                    case price = "05. price"
                    case changePercent = "10. change percent"
                }
            }

            struct Response: Decodable {
                let globalQuote: GlobalQuote

                enum CodingKeys: String, CodingKey {
                    case globalQuote = "Global Quote"
                }
            }

            do {
                let result = try await NetworkClient.shared.fetch(components.url!, as: Response.self)
                if let price = Double(result.globalQuote.price),
                   let change = Double(result.globalQuote.changePercent.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) {
                    let quote = StockQuote(symbol: symbol, name: symbol, price: price, changePercent: change)
                    quotes.append(quote)
                }
            } catch {
                // Skip symbols that fail to decode
                continue
            }
        }

        return quotes
    }

    func getChartData(for symbol: String) async throws -> [ChartDataPoint] {
        var components = URLComponents(string: "https://www.alphavantage.co/query")!
        components.queryItems = [
            URLQueryItem(name: "function", value: "TIME_SERIES_DAILY"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "outputsize", value: "compact")
        ]

        struct Response: Decodable {
            let series: [String: [String: String]]

            enum CodingKeys: String, CodingKey {
                case series = "Time Series (Daily)"
            }
        }

        let result = try await NetworkClient.shared.fetch(components.url!, as: Response.self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var points: [ChartDataPoint] = []
        for (dateString, values) in result.series {
            guard let date = formatter.date(from: dateString),
                  let open = Double(values["1. open"] ?? ""),
                  let high = Double(values["2. high"] ?? ""),
                  let low = Double(values["3. low"] ?? ""),
                  let close = Double(values["4. close"] ?? ""),
                  let volume = Double(values["5. volume"] ?? values["6. volume"] ?? "")
            else { continue }

            let point = ChartDataPoint(
                time: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                bidVolume: 0,
                askVolume: 0
            )
            points.append(point)
        }

        return points.sorted { $0.time < $1.time }
    }

    var name: String { "Alpha Vantage" }
}
