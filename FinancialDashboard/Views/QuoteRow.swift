// Views/QuoteRow.swift
import SwiftUI

struct QuoteRow: View {
    let quote: any QuoteData
    
    var body: some View {
        HStack {
            Text(quote.symbol).bold()
            Text(quote.name)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(String(format: "%.2f", quote.price))
                .monospacedDigit()
            Text(String(format: "%+.2f%%", quote.changePercent))
                .foregroundStyle(quote.changePercent >= 0 ? .green : .red)
                .monospacedDigit()
        }
    }
}