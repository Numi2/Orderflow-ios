import UIKit

/// A tiled backing store: the system will ask to redraw individual tiles
/// (≈ 256 × 256 pt) when they come into view.  Perfect for huge datasets.
final class BarChartContentView: UIView {

    // MARK: - Configurable knobs --------------------------------------------
    /// Chart data points, setting this will trigger a display update (throttled)
    var data: [ChartDataPoint] = [] {
        didSet {
            needsDataUpdate = true
            scheduleDisplayUpdate()
        }
    }
    @objc dynamic var upColor = UIColor.systemGreen
    @objc dynamic var downColor = UIColor.systemRed
    let barGap: CGFloat = 2
    
    /// Strategy to use for rendering the chart
    var renderStrategy: ChartRenderStrategy {
        didSet { setNeedsDisplay() }
    }
    
    // MARK: - Throttling properties -----------------------------------------
    /// Flag indicating if a data update is pending
    private var needsDataUpdate = false
    
    /// Display link for coordinating redraws with screen refresh rate
    private var displayLink: CADisplayLink?
    
    /// Set this to control throttle interval (16ms = 60fps, 33ms = 30fps)
    var throttleInterval: TimeInterval = 1.0/30.0 // 30fps by default
    
    /// Last time a display update was performed
    private var lastDisplayUpdate: TimeInterval = 0
    
    // MARK: - Initialization ------------------------------------------------
    
    init(strategy: ChartRenderStrategy = OHLCRenderStrategy()) {
        self.renderStrategy = strategy
        super.init(frame: .zero)
        setupDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        self.renderStrategy = OHLCRenderStrategy()
        super.init(coder: coder)
        setupDisplayLink()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkFired(_ displayLink: CADisplayLink) {
        // Only update if enough time has passed since the last update
        let currentTime = CACurrentMediaTime()
        guard needsDataUpdate && (currentTime - lastDisplayUpdate) >= throttleInterval else {
            return
        }
        
        // Reset flags and update the display
        needsDataUpdate = false
        lastDisplayUpdate = currentTime
        super.setNeedsDisplay()
    }
    
    // Override setNeedsDisplay to use our throttling mechanism for data updates
    override func setNeedsDisplay() {
        scheduleDisplayUpdate()
    }
    
    private func scheduleDisplayUpdate() {
        // For non-data updates, we'll still throttle but set a flag
        // that an update is required on the next display link cycle
        needsDataUpdate = true
    }

    // MARK: - Tiling layer override -----------------------------------------
    override class var layerClass: AnyClass { CATiledLayer.self }

    private var tileScaling: CGFloat {
        // CATiledLayer draws at 100 %, 200 %, … resolution automatically;
        // account for it so barWidth matches device points.
        UIScreen.main.scale / (layer as! CATiledLayer).contentsScale
    }

    // MARK: - Drawing --------------------------------------------------------
    override func draw(_ rect: CGRect) {
        guard !data.isEmpty else { return }
        let ctx = UIGraphicsGetCurrentContext()!
        
        let tileZoom = tileScaling * (superview as? UIScrollView)?.zoomScale ?? 1
        let w = (superview as? TradingBarChartView)?.barWidth ?? 8
        let bw = w * tileZoom
        let gap = barGap * tileZoom
        
        // Delegate rendering to the strategy
        renderStrategy.render(
            in: rect,
            context: ctx,
            data: data,
            bounds: bounds,
            barWidth: bw,
            barGap: gap,
            upColor: upColor,
            downColor: downColor,
            tileScaling: tileScaling
        )
    }

    // MARK: - Public API --------------------------------------------------------
    /// Returns the data indices visible in the specified rectangle
    /// - Parameters:
    ///   - rect: The rectangle to check
    ///   - barWidth: Width of each bar including gap
    /// - Returns: Range of visible data indices
    func dataIndices(in rect: CGRect, barWidth: CGFloat) -> Range<Int> {
        return renderStrategy.dataIndices(in: rect, barWidth: barWidth, dataCount: data.count)
    }
    
    /// Changes the chart type by updating the render strategy
    /// - Parameter type: The chart type to change to
    func setChartType(_ type: ChartType) {
        switch type {
        case .ohlc:
            renderStrategy = OHLCRenderStrategy()
        case .candlestick:
            renderStrategy = CandlestickRenderStrategy()
        case .heikinAshi:
            renderStrategy = HeikinAshiRenderStrategy()
        case .renko:
            renderStrategy = RenkoRenderStrategy()
        }
    }
}

/// Available chart types
enum ChartType {
    case ohlc
    case candlestick
    case heikinAshi
    case renko
}

// MARK: - Helper functions

private func drawVolume(slice: ArraySlice<ChartDataPoint>, indices: Range<Int>,
                        in ctx: CGContext, bw: CGFloat, gap: CGFloat) {

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
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }
}