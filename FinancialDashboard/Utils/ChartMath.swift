import Foundation
import CoreGraphics

/// Utility functions for chart calculations
enum ChartMath {
    /// Convert a price value to a Y coordinate
    /// - Parameters:
    ///   - price: The price value to convert
    ///   - maxPrice: The maximum price in the visible range
    ///   - height: The height of the chart area
    ///   - priceRange: The range between minimum and maximum price
    /// - Returns: The Y coordinate for the price
    static func priceToY(price: Double, maxPrice: Double, height: CGFloat, priceRange: Double) -> CGFloat {
        return CGFloat(maxPrice - price) * (height / CGFloat(priceRange))
    }
    
    /// Calculate color based on price delta
    /// - Parameters:
    ///   - delta: The price change
    ///   - maxDelta: The maximum price change in the visible range
    ///   - upColor: Color for positive change
    ///   - downColor: Color for negative change
    /// - Returns: Color with intensity proportional to delta magnitude
    static func deltaToColor(delta: Double, maxDelta: Double, upColor: CGColor, downColor: CGColor) -> CGColor {
        let intensity = min(abs(delta) / maxDelta, 1.0)
        
        if delta >= 0 {
            return upColor.copy(alpha: CGFloat(intensity))!
        } else {
            return downColor.copy(alpha: CGFloat(intensity))!
        }
    }
    
    /// Calculate a reasonable brick size for Renko charts
    /// - Parameters:
    ///   - data: The price data
    ///   - percentOfAverage: Percentage of average price to use (e.g. 0.005 for 0.5%)
    /// - Returns: A reasonable brick size
    static func calculateBrickSize(data: [ChartDataPoint], percentOfAverage: Double = 0.005) -> Double {
        guard !data.isEmpty else { return 1.0 }
        
        let avgPrice = data.reduce(0.0) { $0 + $1.close } / Double(data.count)
        return avgPrice * percentOfAverage
    }
    
    /// Calculate tick marks for price axis
    /// - Parameters:
    ///   - minPrice: Minimum price in range
    ///   - maxPrice: Maximum price in range
    ///   - targetCount: Target number of tick marks
    /// - Returns: Array of price values for tick marks
    static func calculatePriceTicks(minPrice: Double, maxPrice: Double, targetCount: Int = 5) -> [Double] {
        let range = maxPrice - minPrice
        
        // Find a reasonable increment (1, 2, 5, 10, 20, 50, etc.)
        let roughIncrement = range / Double(targetCount)
        let exponent = floor(log10(roughIncrement))
        let magnitude = pow(10, exponent)
        
        let normalizedIncrement = roughIncrement / magnitude
        let niceIncrement: Double
        
        if normalizedIncrement < 1.5 {
            niceIncrement = 1.0
        } else if normalizedIncrement < 3.5 {
            niceIncrement = 2.0
        } else if normalizedIncrement < 7.5 {
            niceIncrement = 5.0
        } else {
            niceIncrement = 10.0
        }
        
        let increment = niceIncrement * magnitude
        
        // Calculate starting point
        let niceMin = floor(minPrice / increment) * increment
        
        // Generate ticks
        var ticks: [Double] = []
        var currentTick = niceMin
        
        while currentTick <= maxPrice {
            if currentTick >= minPrice {
                ticks.append(currentTick)
            }
            currentTick += increment
        }
        
        return ticks
    }
} 