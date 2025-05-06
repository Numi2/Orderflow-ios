// Networking/APIService.swift
import Foundation

protocol APIService {
    func latestQuotes() async throws -> [any QuoteData]
    func getChartData(for symbol: String) async throws -> [ChartDataPoint]
}