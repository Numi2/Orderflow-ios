import UIKit

/// One self‑contained view = chart + volume‑profile ⇒ drop anywhere.
final class TradingChartContainer: UIView {

    // internal views
    private let chart   = TradingBarChartView()
    private let profile = VolumeProfileOverlay()
    
    // Crosshair overlay elements
    private let crosshairOverlay = UIView()
    private let horizontalLine = UIView()
    private let verticalLine = UIView()
    private let tooltipView = OHLCTooltipView()
    private var longPressGesture: UILongPressGestureRecognizer!
    
    // Go to latest button
    private let goToLatestButton = UIButton(type: .system)
    private var isTrackingLatest = true
    private var observingChanges = false
    
    // Theme colors
    var crosshairColor: UIColor = .gray.withAlphaComponent(0.7) {
        didSet {
            horizontalLine.backgroundColor = crosshairColor
            verticalLine.backgroundColor = crosshairColor
        }
    }
    
    /// Current touch location
    private var touchLocation: CGPoint?

    /// Set or stream your data here
    var points: [ChartDataPoint] = [] {
        didSet {
            chart.data = points
            profile.data = points
            
            // If tracking is enabled and new data is appended, scroll to latest
            if isTrackingLatest && oldValue.count < points.count {
                scrollToLatest(animated: true)
            }
            
            // Show/hide button based on whether we're at the latest point
            updateGoToLatestButtonVisibility()
        }
    }
    
    // Chart colors
    var upColor: UIColor = .systemGreen {
        didSet {
            chart.contentView?.upColor = upColor
        }
    }
    
    var downColor: UIColor = .systemRed {
        didSet {
            chart.contentView?.downColor = downColor
        }
    }
    
    /// Set the chart display type
    /// - Parameter type: The chart type to display
    func setChartType(_ type: ChartType) {
        chart.setChartType(type)
    }
    
    /// Apply theme colors
    /// - Parameter colors: The theme colors to apply
    func applyTheme(colors: ThemeColors) {
        upColor = colors.upColor
        downColor = colors.downColor
        crosshairColor = colors.crosshairColor
        
        // Update tooltip colors
        tooltipView.backgroundColor = colors.backgroundColor.withAlphaComponent(0.9)
        tooltipView.layer.borderColor = colors.gridColor.cgColor
        tooltipView.updateTextColors(primaryColor: colors.primaryTextColor, secondaryColor: colors.secondaryTextColor)
        
        // Update go to latest button
        goToLatestButton.backgroundColor = colors.backgroundColor.withAlphaComponent(0.8)
        goToLatestButton.tintColor = colors.primaryTextColor
    }

    // ---- life‑cycle -------------------------------------------------------
    override init(frame: CGRect)  { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        // chart fills container
        chart.frame = bounds
        chart.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(chart)

        // overlay rides on top, ignores touches
        profile.frame = chart.bounds
        profile.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        profile.isUserInteractionEnabled = false
        chart.addSubview(profile)
        
        // Setup crosshair overlay
        setupCrosshairOverlay()
        
        // Setup go to latest button
        setupGoToLatestButton()
        
        // Start observing scroll changes
        setupScrollObserver()
    }
    
    // MARK: - Go To Latest Implementation
    
    private func setupGoToLatestButton() {
        goToLatestButton.setImage(UIImage(systemName: "arrow.right.to.line"), for: .normal)
        goToLatestButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        goToLatestButton.layer.cornerRadius = 20
        goToLatestButton.layer.shadowColor = UIColor.black.cgColor
        goToLatestButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        goToLatestButton.layer.shadowRadius = 2
        goToLatestButton.layer.shadowOpacity = 0.3
        goToLatestButton.addTarget(self, action: #selector(goToLatestTapped), for: .touchUpInside)
        
        // Initially hidden since we start with tracking enabled
        goToLatestButton.alpha = 0
        
        addSubview(goToLatestButton)
        
        // Position button
        goToLatestButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            goToLatestButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            goToLatestButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            goToLatestButton.widthAnchor.constraint(equalToConstant: 40),
            goToLatestButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupScrollObserver() {
        guard !observingChanges else { return }
        observingChanges = true
        
        // Observe content offset changes
        chart.addObserver(self, forKeyPath: "contentOffset", options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" && object as? UIScrollView == chart {
            // When user manually scrolls, disable tracking
            if chart.isDragging || chart.isDecelerating {
                if isTrackingLatest && !isShowingLatestBar() {
                    isTrackingLatest = false
                    updateGoToLatestButtonVisibility()
                }
            }
        }
    }
    
    deinit {
        if observingChanges {
            chart.removeObserver(self, forKeyPath: "contentOffset")
        }
    }
    
    @objc private func goToLatestTapped() {
        scrollToLatest(animated: true)
        isTrackingLatest = true
        updateGoToLatestButtonVisibility()
    }
    
    private func scrollToLatest(animated: Bool) {
        guard !points.isEmpty else { return }
        
        let contentWidth = chart.contentSize.width
        let viewWidth = chart.bounds.width
        
        if contentWidth > viewWidth {
            // Calculate the offset to show the latest bars
            let newOffset = CGPoint(x: contentWidth - viewWidth, y: 0)
            chart.setContentOffset(newOffset, animated: animated)
        }
    }
    
    private func isShowingLatestBar() -> Bool {
        guard !points.isEmpty else { return true }
        
        let contentWidth = chart.contentSize.width
        let viewWidth = chart.bounds.width
        let currentOffset = chart.contentOffset.x
        
        // Consider showing latest if we're within a small threshold of the end
        let threshold: CGFloat = 20
        return contentWidth - (currentOffset + viewWidth) <= threshold
    }
    
    private func updateGoToLatestButtonVisibility() {
        UIView.animate(withDuration: 0.3) {
            self.goToLatestButton.alpha = self.isTrackingLatest ? 0 : 1
        }
    }
    
    // MARK: - Crosshair Implementation
    
    private func setupCrosshairOverlay() {
        // Configure crosshair container
        crosshairOverlay.frame = chart.bounds
        crosshairOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        crosshairOverlay.isUserInteractionEnabled = false
        crosshairOverlay.isHidden = true
        chart.addSubview(crosshairOverlay)
        
        // Configure horizontal line
        horizontalLine.backgroundColor = crosshairColor
        horizontalLine.isHidden = true
        crosshairOverlay.addSubview(horizontalLine)
        
        // Configure vertical line
        verticalLine.backgroundColor = crosshairColor
        verticalLine.isHidden = true
        crosshairOverlay.addSubview(verticalLine)
        
        // Configure tooltip
        tooltipView.isHidden = true
        tooltipView.layer.cornerRadius = 6
        tooltipView.layer.masksToBounds = true
        crosshairOverlay.addSubview(tooltipView)
        
        // Setup long press gesture
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.3
        addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: chart)
            touchLocation = location
            updateCrosshair(at: location)
            crosshairOverlay.isHidden = false
            horizontalLine.isHidden = false
            verticalLine.isHidden = false
            tooltipView.isHidden = false
            
            // Disable tracking when using crosshair
            if isTrackingLatest {
                isTrackingLatest = false
                updateGoToLatestButtonVisibility()
            }
            
        case .ended, .cancelled, .failed:
            touchLocation = nil
            crosshairOverlay.isHidden = true
            horizontalLine.isHidden = true
            verticalLine.isHidden = true
            tooltipView.isHidden = true
            
        default:
            break
        }
    }
    
    private func updateCrosshair(at location: CGPoint) {
        // Update horizontal line
        horizontalLine.frame = CGRect(
            x: 0,
            y: location.y - 0.5,
            width: chart.bounds.width,
            height: 1
        )
        
        // Update vertical line
        verticalLine.frame = CGRect(
            x: location.x - 0.5,
            y: 0,
            width: 1,
            height: chart.bounds.height
        )
        
        // Get data at location
        guard let (dataPoint, _) = dataPointAt(location: location) else { return }
        
        // Update tooltip with dataPoint information
        tooltipView.configure(with: dataPoint)
        
        // Position tooltip
        let tooltipSize = tooltipView.sizeThatFits(CGSize(width: 180, height: 120))
        var tooltipX = location.x + 10
        let tooltipY = min(location.y - tooltipSize.height/2, chart.bounds.height - tooltipSize.height - 10)
        
        // Keep tooltip on screen
        if tooltipX + tooltipSize.width > chart.bounds.width {
            tooltipX = location.x - tooltipSize.width - 10
        }
        
        tooltipView.frame = CGRect(
            x: tooltipX,
            y: tooltipY,
            width: tooltipSize.width,
            height: tooltipSize.height
        )
    }
    
    private func dataPointAt(location: CGPoint) -> (ChartDataPoint, Int)? {
        guard !points.isEmpty else { return nil }
        
        let barWidth = chart.barWidth
        let totalWidth = barWidth + chart.contentView.barGap
        
        // Convert point to content view coordinates
        let contentLocation = chart.convert(location, to: chart.contentView)
        
        // Calculate index
        let index = Int(contentLocation.x / totalWidth)
        guard index >= 0 && index < points.count else { return nil }
        
        return (points[index], index)
    }
}

// MARK: - Tooltip View

final class OHLCTooltipView: UIView {
    private let stackView = UIStackView()
    private let timeLabel = UILabel()
    private let ohlcLabel = UILabel()
    private let deltaLabel = UILabel()
    private let volumeLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.borderWidth = 1
        layer.borderColor = UIColor.gray.withAlphaComponent(0.5).cgColor
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        // Configure labels
        [timeLabel, ohlcLabel, deltaLabel, volumeLabel].forEach { label in
            label.font = UIFont.systemFont(ofSize: 12)
            stackView.addArrangedSubview(label)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with dataPoint: ChartDataPoint) {
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let timeString = dateFormatter.string(from: dataPoint.time)
        
        // Update labels
        timeLabel.text = timeString
        
        // Format OHLC values
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        
        let open = numberFormatter.string(from: NSNumber(value: dataPoint.open)) ?? "0.00"
        let high = numberFormatter.string(from: NSNumber(value: dataPoint.high)) ?? "0.00"
        let low = numberFormatter.string(from: NSNumber(value: dataPoint.low)) ?? "0.00"
        let close = numberFormatter.string(from: NSNumber(value: dataPoint.close)) ?? "0.00"
        
        ohlcLabel.text = "O: \(open)  H: \(high)  L: \(low)  C: \(close)"
        
        // Set delta 
        let delta = numberFormatter.string(from: NSNumber(value: dataPoint.delta)) ?? "0.00"
        deltaLabel.text = "Delta: \(delta)"
        deltaLabel.textColor = dataPoint.delta >= 0 ? .systemGreen : .systemRed
        
        // Set volume
        let volumeFormatter = NumberFormatter()
        volumeFormatter.numberStyle = .decimal
        volumeFormatter.maximumFractionDigits = 0
        let volume = volumeFormatter.string(from: NSNumber(value: dataPoint.volume)) ?? "0"
        volumeLabel.text = "Volume: \(volume)"
    }
    
    func updateTextColors(primaryColor: UIColor, secondaryColor: UIColor) {
        timeLabel.textColor = secondaryColor
        ohlcLabel.textColor = primaryColor
        volumeLabel.textColor = secondaryColor
        // deltaLabel color is set dynamically based on value
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: 180, height: 90)
    }
}