import UIKit

/// Renders data in standard OHLC (Open-High-Low-Close) format with volume
final class OHLCRenderStrategy: ChartRenderStrategy {
    
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
        let priceRange = maxP - minP
        
        // Draw each bar
        for (idx, point) in zip(visible, slice) {
            let x = CGFloat(idx) * (bw + gap) + bw*0.5
            let color = point.close >= point.open ? upColor : downColor
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1)
            
            // OHLC vertical
            let yHigh = ChartMath.priceToY(price: point.high, maxPrice: maxP, height: bounds.height, priceRange: priceRange)
            let yLow = ChartMath.priceToY(price: point.low, maxPrice: maxP, height: bounds.height, priceRange: priceRange)
            context.drawLine(from: CGPoint(x: x, y: yHigh), to: CGPoint(x: x, y: yLow))
            
            // Open tick (left)
            let yOpen = ChartMath.priceToY(price: point.open, maxPrice: maxP, height: bounds.height, priceRange: priceRange)
            context.drawLine(from: CGPoint(x: x - bw*0.5, y: yOpen), to: CGPoint(x: x, y: yOpen))
            
            // Close tick (right)
            let yClose = ChartMath.priceToY(price: point.close, maxPrice: maxP, height: bounds.height, priceRange: priceRange)
            context.drawLine(from: CGPoint(x: x, y: yClose), to: CGPoint(x: x + bw*0.5, y: yClose))
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
        let volHeight: CGFloat = 40       // height reserved at bottom
        let yBase = bounds.height - volHeight
        
        for (i, point) in zip(indices, slice) {
            let x = CGFloat(i) * (bw + gap)
            let h = CGFloat(point.volume / maxVol) * volHeight
            let y = yBase + (volHeight - h)
            
            let rect = CGRect(x: x, y: y, width: bw, height: h)
            let color = point.delta >= 0 ? upColor.withAlphaComponent(0.4)
                                         : downColor.withAlphaComponent(0.4)
            ctx.fillRect(rect, with: color.cgColor)
        }
    }
} 