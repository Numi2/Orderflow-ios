// Views/PriceChartView.swift
// (Optional mini‑chart using SwiftUI Charts – requires iOS 16+)
import SwiftUI
import Charts

struct PriceChartView<Point: Identifiable & Hashable>: View {
    let points: [Point]
    let valueKeyPath: KeyPath<Point, Double>
    
    var body: some View {
        Chart(points) { p in
            LineMark(
                x: .value("Index", points.firstIndex(of: p) ?? 0),
                y: .value("Price", p[keyPath: valueKeyPath])
            )
        }
        .chartYAxis(.hidden)
        .frame(height: 80)
    }
}