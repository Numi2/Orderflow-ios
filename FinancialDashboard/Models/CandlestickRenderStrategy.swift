import UIKit

/// Renders data in Candlestick format with volume
final class CandlestickRenderStrategy: ChartRenderStrategy {
    
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
        
        // Pre‑compute min/max price in *visible tile* for Y‑mapping
        let visible = dataIndices(in: rect, barWidth: bw+gap, dataCount: data.count)
        let slice = data[visible]
        guard let minP = slice.map(\.low).min(),
              let maxP = slice.map(\.high).max()
        else { return }
        let yFactor = Double(bounds.height) / (maxP - minP)
        
        // Pre-compute maximum delta for color intensity
        let maxDelta = slice.map { abs($0.delta) }.max() ?? 1
        
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
            
            // colour = hue (green➜red) + intensity by |delta|
            let hue: CGFloat = point.delta >= 0 ? 0.33 : 0.0 // 0.33 ≈ green, 0 ≈ red
            let sat: CGFloat = min(abs(point.delta) / maxDelta, 1)
            let color = UIColor(hue: hue, saturation: sat, brightness: 0.9, alpha: 1)
            
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: bodyX, y: bodyY, width: bodyW, height: bodyH))
            
            // ---- HIGH/LOW WICK ---------------------------------------------------
            context.setStrokeColor(UIColor.label.withAlphaComponent(0.6).cgColor)
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
        
        // Volume bars (underlay)
        drawVolume(slice: slice, indices: visible, in: context, bounds: bounds, bw: bw, gap: gap, upColor: upColor, downColor: downColor)
        
        context.restoreGState()
    }
    
    private func drawVolume(slice: ArraySlice<ChartDataPoint>,
                           indices: Range<Int>,
                           in ctx: CGContext,
                           bounds: CGRect,
                           bw: CGFloat,
                           gap: CGFloat,
                           upColor: UIColor,
                           downColor: UIColor) {
        
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