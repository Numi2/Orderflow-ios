import UIKit

/// Renders data in Heikin-Ashi format
/// Heikin-Ashi is a modified candlestick that smooths price action
final class HeikinAshiRenderStrategy: ChartRenderStrategy {
    
    func render(in rect: CGRect,
                context: CGContext,
                data: [ChartDataPoint],
                bounds: CGRect,
                barWidth: CGFloat,
                barGap: CGFloat,
                upColor: UIColor,
                downColor: UIColor,
                tileScaling: CGFloat) {
        
        guard !data.isEmpty else { return }
        
        context.saveGState()
        
        let bw = barWidth
        let gap = barGap
        
        // Convert to Heikin-Ashi values
        let haData = convertToHeikinAshi(data: data)
        
        // Pre‑compute min/max price in *visible tile* for Y‑mapping
        let visible = dataIndices(in: rect, barWidth: bw+gap, dataCount: haData.count)
        let slice = haData[visible]
        guard let minP = slice.map(\.low).min(),
              let maxP = slice.map(\.high).max()
        else { return }
        let yFactor = Double(bounds.height) / (maxP - minP)
        
        // Draw each bar
        for (idx, point) in zip(visible, slice) {
            let x = CGFloat(idx) * (bw + gap)
            
            // ---- BODY RECT -------------------------------------------------------
            let yOpen = CGFloat(maxP - point.open) * yFactor
            let yClose = CGFloat(maxP - point.close) * yFactor
            let bodyY = min(yOpen, yClose)
            let bodyH = max(abs(yOpen - yClose), 1) // Ensure at least 1pt height
            let bodyW = bw * 0.7 // narrower than full bar for aesthetics
            let bodyX = x + (bw - bodyW) / 2
            
            // Determine color based on open/close relationship
            let color = point.close >= point.open ? upColor : downColor
            
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH))
            
            // ---- HIGH/LOW WICK ---------------------------------------------------
            context.setStrokeColor(color.cgColor) // Match body color for Heikin-Ashi
            context.setLineWidth(1)
            
            let yHigh = CGFloat(maxP - point.high) * yFactor
            let yLow = CGFloat(maxP - point.low) * yFactor
            let midX = x + bw * 0.5
            
            // Draw high wick
            context.move(to: CGPoint(x: midX, y: yHigh))
            context.addLine(to: CGPoint(x: midX, y: bodyY))
            context.strokePath()
            
            // Draw low wick
            context.move(to: CGPoint(x: midX, y: bodyY + bodyH))
            context.addLine(to: CGPoint(x: midX, y: yLow))
            context.strokePath()
        }
        
        // Volume bars (underlay) - using original data for volume
        drawVolume(data: data, indices: visible, in: context, bounds: bounds, bw: bw, gap: gap, upColor: upColor, downColor: downColor)
        
        context.restoreGState()
    }
    
    private func convertToHeikinAshi(data: [ChartDataPoint]) -> [ChartDataPoint] {
        guard !data.isEmpty else { return [] }
        
        var result: [ChartDataPoint] = []
        var previousHaClose = data[0].close
        
        for (i, point) in data.enumerated() {
            let haOpen: Double
            if i == 0 {
                haOpen = (point.open + point.close) / 2
            } else {
                haOpen = (result[i-1].open + result[i-1].close) / 2
            }
            
            let haClose = (point.open + point.high + point.low + point.close) / 4
            let haHigh = max(point.high, max(haOpen, haClose))
            let haLow = min(point.low, min(haOpen, haClose))
            
            // Create a new ChartDataPoint with Heikin-Ashi values
            let haPoint = ChartDataPoint(
                time: point.time,
                open: haOpen,
                high: haHigh,
                low: haLow,
                close: haClose,
                volume: point.volume,
                bidVolume: point.bidVolume,
                askVolume: point.askVolume
            )
            
            result.append(haPoint)
            previousHaClose = haClose
        }
        
        return result
    }
    
    private func drawVolume(data: [ChartDataPoint],
                           indices: Range<Int>,
                           in ctx: CGContext,
                           bounds: CGRect,
                           bw: CGFloat,
                           gap: CGFloat,
                           upColor: UIColor,
                           downColor: UIColor) {
        
        guard indices.lowerBound < data.count else { return }
        let slice = data[Swift.max(0, indices.lowerBound)..<Swift.min(data.count, indices.upperBound)]
        guard let maxVol = slice.map(\.volume).max(), maxVol > 0 else { return }
        
        let volHeight: CGFloat = 40 // height reserved at bottom
        let yBase = bounds.height - volHeight
        
        for (i, point) in zip(indices, slice) {
            let x = CGFloat(i) * (bw + gap)
            let h = CGFloat(point.volume / maxVol) * volHeight
            let y = yBase + (volHeight - h)
            
            let rect = CGRect(x: x, y: y, width: bw, height: h)
            let color = point.close >= point.open ? upColor.withAlphaComponent(0.4)
                                                 : downColor.withAlphaComponent(0.4)
            ctx.setFillColor(color.cgColor)
            ctx.fill(rect)
        }
    }
} 