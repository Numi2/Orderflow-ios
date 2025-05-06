import Foundation

public struct ChartDataPoint: Hashable {
    public let time: Date
    public let open, high, low, close: Double
    public let volume: Double
    public let bidVolume: Double      // liquidity lifted at bid
    public let askVolume: Double      // liquidity lifted at ask

    public var delta: Double { askVolume - bidVolume }
}