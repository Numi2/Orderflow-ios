import XCTest
@testable import FinancialDashboard

// Note: In a real app, this would be in a separate test target.
// For demo purposes, we're putting it inside the main target.

final class ChartRenderStrategyTests: XCTestCase {
    
    // Testing strategies
    private var ohlcStrategy: OHLCRenderStrategy!
    private var candlestickStrategy: CandlestickRenderStrategy!
    private var heikinAshiStrategy: HeikinAshiRenderStrategy!
    private var renkoStrategy: RenkoRenderStrategy!
    
    // Test constants
    private let sampleBarWidth: CGFloat = 10
    private let sampleDataCount = 1000
    
    override func setUp() {
        super.setUp()
        ohlcStrategy = OHLCRenderStrategy()
        candlestickStrategy = CandlestickRenderStrategy()
        heikinAshiStrategy = HeikinAshiRenderStrategy()
        renkoStrategy = RenkoRenderStrategy()
    }
    
    // MARK: - Normal Case Tests
    
    func testNormalIndicesCalculation() {
        let rect = CGRect(x: 100, y: 0, width: 100, height: 100)
        
        // With bar width of 10, this should show indices 10-19
        let indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices.lowerBound, 10, "Lower bound should be x / barWidth (100 / 10 = 10)")
        XCTAssertEqual(indices.upperBound, 20, "Upper bound should be (x+width) / barWidth + 1 (200 / 10 + 1 = 21)")
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyDataIndices() {
        let rect = CGRect(x: 50, y: 0, width: 100, height: 100)
        
        // Test with empty data set
        let indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: 0)
        
        XCTAssertEqual(indices.lowerBound, 0, "Lower bound should be 0 for empty data")
        XCTAssertEqual(indices.upperBound, 0, "Upper bound should be 0 for empty data")
        XCTAssertTrue(indices.isEmpty, "Range should be empty for empty data")
    }
    
    func testSubPixelBarWidthIndices() {
        let rect = CGRect(x: 100, y: 0, width: 100, height: 100)
        let subPixelBarWidth: CGFloat = 0.5
        
        // With sub-pixel bar width, this should show many more indices
        let indices = ohlcStrategy.dataIndices(in: rect, barWidth: subPixelBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices.lowerBound, 200, "Lower bound should be x / barWidth (100 / 0.5 = 200)")
        XCTAssertEqual(indices.upperBound, 400, "Upper bound should be (x+width) / barWidth + 1 (200 / 0.5 + 1 = 401)")
    }
    
    func testMassiveZoomIndices() {
        let rect = CGRect(x: 5000, y: 0, width: 10000, height: 100)
        let largeBarWidth: CGFloat = 50 // Simulating zoomed in view
        
        // With large bar width (zoomed in), this should show fewer indices
        let indices = ohlcStrategy.dataIndices(in: rect, barWidth: largeBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices.lowerBound, 100, "Lower bound should be x / barWidth (5000 / 50 = 100)")
        // Upper bound should be capped at data count
        XCTAssertEqual(indices.upperBound, 301, "Upper bound should be (x+width) / barWidth + 1 (15000 / 50 + 1 = 301)")
    }
    
    func testOutOfBoundsIndices() {
        // Test rect completely beyond the data range
        let farRect = CGRect(x: 20000, y: 0, width: 100, height: 100)
        
        let indices = ohlcStrategy.dataIndices(in: farRect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        // Lower bound should be limited to data count
        XCTAssertEqual(indices.lowerBound, 1000, "Lower bound should be capped at data count")
        XCTAssertEqual(indices.upperBound, 1000, "Upper bound should be capped at data count")
        XCTAssertTrue(indices.isEmpty, "Range should be empty when completely out of bounds")
    }
    
    func testNegativeXRect() {
        // Test rect with negative X (scrolled left of origin)
        let negativeRect = CGRect(x: -50, y: 0, width: 100, height: 100)
        
        let indices = ohlcStrategy.dataIndices(in: negativeRect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices.lowerBound, 0, "Lower bound should be capped at 0 for negative x")
        XCTAssertEqual(indices.upperBound, 6, "Upper bound should be (x+width) / barWidth + 1 ((-50+100) / 10 + 1 = 6)")
    }
    
    func testAllStrategiesConsistency() {
        let rect = CGRect(x: 100, y: 0, width: 100, height: 100)
        
        // All strategies should return the same indices for the same input
        let ohlcIndices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        let candlestickIndices = candlestickStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        let heikinAshiIndices = heikinAshiStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        let renkoIndices = renkoStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(ohlcIndices, candlestickIndices, "OHLC and Candlestick strategies should return the same indices")
        XCTAssertEqual(ohlcIndices, heikinAshiIndices, "OHLC and Heikin-Ashi strategies should return the same indices")
        XCTAssertEqual(ohlcIndices, renkoIndices, "OHLC and Renko strategies should return the same indices")
    }
    
    // MARK: - Real World Scenario Tests
    
    func testTypicalChartScrollScenario() {
        // Setup initial view (showing first 10 bars)
        var rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        var indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices, 0..<11, "Initial view should show first 11 bars")
        
        // Scroll right by 50 points
        rect = CGRect(x: 50, y: 0, width: 100, height: 100)
        indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices, 5..<16, "After scrolling right, should show bars 5-15")
        
        // Zoom in (bar width doubles)
        rect = CGRect(x: 50, y: 0, width: 100, height: 100)
        indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth * 2, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices, 2..<8, "After zooming in, should show fewer bars (2-7)")
        
        // Zoom out (bar width halves)
        rect = CGRect(x: 50, y: 0, width: 100, height: 100)
        indices = ohlcStrategy.dataIndices(in: rect, barWidth: sampleBarWidth / 2, dataCount: sampleDataCount)
        
        XCTAssertEqual(indices, 10..<31, "After zooming out, should show more bars (10-30)")
    }
} 