import UIKit

// MARK: - Main scroll/zoom container ----------------------------------------

final class TradingBarChartView: UIScrollView {

    // Public API -------------------------------------------------------------
    var data: [ChartDataPoint] = [] {
        didSet { contentView.data = data;            // forward
                 recalcContentSize() }
    }
    var barWidth: CGFloat = 8 { didSet { setNeedsLayout() } }
    
    /// Current chart type
    private var chartType: ChartType = .ohlc
    
    /// Track pinch gesture starting point and scale
    private var pinchStartPoint: CGPoint?
    private var pinchStartScale: CGFloat = 1.0
    private var pinchStartContentOffset: CGPoint = .zero
    
    /// Change the chart type
    /// - Parameter type: The chart type to display
    func setChartType(_ type: ChartType) {
        chartType = type
        contentView.setChartType(type)
    }

    // Private ---------------------------------------------------------------
    // Expose contentView to allow updating colors
    var contentView: BarChartContentView { return _contentView }
    private let _contentView = BarChartContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); commonInit() }

    private func commonInit() {
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator   = false
        bouncesZoom                    = false
        minimumZoomScale               = 1
        maximumZoomScale               = 5
        delegate                       = self

        addSubview(_contentView)
        
        // Add pinch gesture recognizer
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        switch gestureRecognizer.state {
        case .began:
            // Capture initial state when pinch begins
            pinchStartPoint = gestureRecognizer.location(in: self)
            pinchStartScale = zoomScale
            pinchStartContentOffset = contentOffset
            
        case .changed:
            guard let startPoint = pinchStartPoint else { return }
            
            let currentScale = gestureRecognizer.scale * pinchStartScale
            let newScale = min(maximumZoomScale, max(minimumZoomScale, currentScale))
            
            // Calculate fraction of visible content where pinch midpoint is
            let startFractionX = (startPoint.x + contentOffset.x) / (contentSize.width * pinchStartScale)
            let startFractionY = (startPoint.y + contentOffset.y) / (contentSize.height * pinchStartScale)
            
            // Apply zoom scale
            setZoomScale(newScale, animated: false)
            
            // Calculate new content offset to maintain focal point
            let newContentOffsetX = startFractionX * contentSize.width * newScale - startPoint.x
            let newContentOffsetY = startFractionY * contentSize.height * newScale - startPoint.y
            
            // Apply new content offset
            let adjustedOffsetX = max(0, min(newContentOffsetX, contentSize.width * newScale - bounds.width))
            let adjustedOffsetY = max(0, min(newContentOffsetY, contentSize.height * newScale - bounds.height))
            
            contentOffset = CGPoint(x: adjustedOffsetX, y: adjustedOffsetY)
            
        case .ended, .cancelled, .failed:
            // Reset tracking state
            pinchStartPoint = nil
            
        default:
            break
        }
    }

    private func recalcContentSize() {
        let w = CGFloat(data.count) * (barWidth + _contentView.barGap)
        contentSize = CGSize(width: max(w, bounds.width), height: bounds.height)
        _contentView.frame = CGRect(origin: .zero, size: contentSize)
        _contentView.setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recalcContentSize()
    }
}

// MARK: - Scroll‑view delegate (only zoom is handled) -----------------------

extension TradingBarChartView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { _contentView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { _contentView.setNeedsDisplay() }
}