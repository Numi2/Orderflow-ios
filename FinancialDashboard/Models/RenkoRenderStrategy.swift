import UIKit

/// Renders data in Renko format, which ignores time and only plots price movements
/// of a specific size (brick size)
final class RenkoRenderStrategy: ChartRenderStrategy {
    
    /// The brick size in price points
    private var brickSize: Double = 0.0
    
    /// Initialize with a specified brick size
    /// - Parameter brickSize: Size of each brick in price units
    init(brickSize: Double = 0.0) {
        self.brickSize = brickSize
    }
    
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
        
        // Create Renko bricks from the price data
        let renkoBricks = createRenkoBricks(from: data)
        guard !renkoBricks.isEmpty else { return }
        
        context.saveGState()
        
        let bw = barWidth
        let gap = barGap
        
        // Pre‑compute min/max price in *visible tile* for Y‑mapping
        let visible = dataIndices(in: rect, barWidth: bw+gap, dataCount: renkoBricks.count)
        guard visible.lowerBound < renkoBricks.count else { return }
        
        let slice = Array(renkoBricks[visible.lowerBound..<min(visible.upperBound, renkoBricks.count)])
        guard let minP = slice.map(\.low).min(),
              let maxP = slice.map(\.high).max()
        else { return }
        let yFactor = Double(bounds.height) / (maxP - minP)
        
        // Draw each Renko brick
        for (idx, brick) in zip(visible, slice) {
            let x = CGFloat(idx) * (bw + gap)
            
            // Draw brick rectangle
            let yHigh = CGFloat(maxP - brick.high) * yFactor
            let height = CGFloat(brick.high - brick.low) * yFactor
            let brickRect = CGRect(x: x, y: yHigh, width: bw, height: height)
            
            // Renko bricks are solid - green for up, red for down
            let color = brick.isUp ? upColor : downColor
            context.setFillColor(color.cgColor)
            context.fill(brickRect)
            
            // Add a border for clarity
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(0.5)
            context.stroke(brickRect)
        }
        
        context.restoreGState()
    }
    
    /// Creates Renko bricks from OHLC data
    /// - Parameter data: The source OHLC data
    /// - Returns: An array of Renko bricks
    private func createRenkoBricks(from data: [ChartDataPoint]) -> [RenkoBrick] {
        guard !data.isEmpty else { return [] }
        
        // Dynamic brick size calculation if none was provided
        let calculatedBrickSize: Double
        if brickSize <= 0 {
            // Calculate a reasonable brick size based on price volatility
            // (approximately 0.5% of the average price)
            let avgPrice = data.reduce(0) { $0 + $1.close } / Double(data.count)
            calculatedBrickSize = avgPrice * 0.005
        } else {
            calculatedBrickSize = brickSize
        }
        
        var bricks: [RenkoBrick] = []
        var currentPrice = data[0].close
        
        for point in data {
            // Process price movement and create bricks
            let priceDiff = point.close - currentPrice
            
            if abs(priceDiff) >= calculatedBrickSize {
                // Determine how many bricks to add
                let brickCount = Int(abs(priceDiff) / calculatedBrickSize)
                let isUp = priceDiff > 0
                
                for _ in 0..<brickCount {
                    if isUp {
                        let lowPrice = currentPrice
                        currentPrice += calculatedBrickSize
                        bricks.append(RenkoBrick(
                            time: point.time,
                            low: lowPrice,
                            high: currentPrice,
                            isUp: true
                        ))
                    } else {
                        let highPrice = currentPrice
                        currentPrice -= calculatedBrickSize
                        bricks.append(RenkoBrick(
                            time: point.time,
                            low: currentPrice,
                            high: highPrice,
                            isUp: false
                        ))
                    }
                }
            }
        }
        
        return bricks
    }
    
    /// Represents a single Renko brick
    struct RenkoBrick {
        let time: Date
        let low: Double
        let high: Double
        let isUp: Bool
    }
} 