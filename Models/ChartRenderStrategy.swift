import UIKit

/// A protocol defining how chart data is rendered
protocol ChartRenderStrategy {
    /// Renders chart data within the given rect
    /// - Parameters:
    ///   - rect: The rectangle to draw in
    ///   - context: The graphics context to draw into
    ///   - data: The data points to render
    ///   - bounds: The view bounds
    ///   - barWidth: Width of a single bar
    ///   - barGap: Gap between bars
    ///   - upColor: Color for positive movements
    ///   - downColor: Color for negative movements
    ///   - tileScaling: Scale factor for proper rendering in tiled layers
    func render(in rect: CGRect, 
                context: CGContext, 
                data: [ChartDataPoint], 
                bounds: CGRect, 
                barWidth: CGFloat, 
                barGap: CGFloat, 
                upColor: UIColor, 
                downColor: UIColor,
                tileScaling: CGFloat)
    
    /// Calculate data indices visible in the given rect
    /// - Parameters:
    ///   - rect: The visible rectangle
    ///   - barWidth: Width of a single bar including gap
    ///   - dataCount: Total count of data points
    /// - Returns: Range of data indices visible in the rect
    func dataIndices(in rect: CGRect, barWidth: CGFloat, dataCount: Int) -> Range<Int>
}

/// Default implementation of dataIndices for chart render strategies
extension ChartRenderStrategy {
    func dataIndices(in rect: CGRect, barWidth: CGFloat, dataCount: Int) -> Range<Int> {
        // Handle edge cases
        if dataCount <= 0 || barWidth <= 0 {
            return 0..<0 // Empty range for no data or invalid bar width
        }
        
        // Calculate visible range
        let start = max(0, Int(floor(rect.minX / barWidth)))
        let end = min(dataCount, Int(ceil(rect.maxX / barWidth)) + 1)
        
        // Ensure valid range (start < end)
        return start..<max(start, end)
    }
} 