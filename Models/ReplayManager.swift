import Foundation
import Combine

/// Replay speeds
enum ReplaySpeed: Double, CaseIterable, Identifiable {
    case x1 = 1.0
    case x2 = 2.0
    case x5 = 5.0
    case x10 = 10.0
    case x20 = 20.0
    case x60 = 60.0
    
    var id: Double { rawValue }
    
    var description: String {
        switch self {
        case .x1: return "1×"
        case .x2: return "2×"
        case .x5: return "5×"
        case .x10: return "10×"
        case .x20: return "20×"
        case .x60: return "60×"
        }
    }
}

/// Manager for replaying chart data
final class ReplayManager: ObservableObject {
    // MARK: - Published properties
    
    /// Current replay state
    @Published var isPlaying = false
    
    /// Current replay speed
    @Published var speed = ReplaySpeed.x5
    
    /// Current position in the replay (0-1)
    @Published var progress: Double = 0
    
    /// Visible data points during replay
    @Published var visiblePoints: [ChartDataPoint] = []
    
    // MARK: - Private properties
    
    /// All data points for replay
    private var allDataPoints: [ChartDataPoint] = []
    
    /// Original data points for replay (to reset)
    private var originalDataPoints: [ChartDataPoint] = []
    
    /// Timer for replay playback
    private var timer: Timer?
    
    /// Last update time
    private var lastUpdateTime: Date?
    
    /// Number of visible points
    private var visibleCount = 30
    
    /// Current index in the replay
    private var currentIndex = 0
    
    // MARK: - Public methods
    
    /// Set up replay with data points
    /// - Parameters:
    ///   - dataPoints: Data points to replay
    ///   - visibleCount: Number of visible data points
    func setupReplay(dataPoints: [ChartDataPoint], visibleCount: Int = 30) {
        // Save original data for reset
        self.originalDataPoints = dataPoints
        
        // Sort data points by time
        let sortedData = dataPoints.sorted(by: { $0.time < $1.time })
        self.allDataPoints = sortedData
        
        // Set visible count
        self.visibleCount = visibleCount
        
        // Reset to beginning
        reset()
    }
    
    /// Start replay
    func play() {
        guard !isPlaying, !allDataPoints.isEmpty else { return }
        
        isPlaying = true
        lastUpdateTime = Date()
        
        // Create timer for updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateReplay()
        }
    }
    
    /// Pause replay
    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    /// Reset replay to beginning
    func reset() {
        // Stop playback
        pause()
        
        // Reset position
        currentIndex = 0
        progress = 0
        
        // Set initial visible data
        updateVisibleData()
    }
    
    /// Seek to position (0-1)
    /// - Parameter position: Position in replay (0-1)
    func seek(to position: Double) {
        let clampedPosition = max(0, min(1, position))
        progress = clampedPosition
        
        // Calculate index based on position
        let maxIndex = max(0, allDataPoints.count - 1)
        currentIndex = Int(clampedPosition * Double(maxIndex))
        
        // Update visible data
        updateVisibleData()
    }
    
    /// Change replay speed
    /// - Parameter newSpeed: New replay speed
    func setSpeed(_ newSpeed: ReplaySpeed) {
        speed = newSpeed
    }
    
    // MARK: - Private methods
    
    /// Update the replay state
    private func updateReplay() {
        guard isPlaying, !allDataPoints.isEmpty, currentIndex < allDataPoints.count else {
            pause()
            return
        }
        
        // Calculate time since last update
        guard let lastUpdate = lastUpdateTime else {
            lastUpdateTime = Date()
            return
        }
        
        let currentTime = Date()
        let elapsed = currentTime.timeIntervalSince(lastUpdate)
        lastUpdateTime = currentTime
        
        // Calculate how many points to advance based on speed
        let pointsPerSecond = speed.rawValue
        let pointsToAdvance = pointsPerSecond * elapsed
        
        // Advance current index
        let newIndex = min(allDataPoints.count - 1, currentIndex + Int(pointsToAdvance))
        
        // If we haven't advanced, return
        if newIndex == currentIndex {
            return
        }
        
        // Update current index
        currentIndex = newIndex
        
        // Update progress
        progress = Double(currentIndex) / Double(max(1, allDataPoints.count - 1))
        
        // Update visible data
        updateVisibleData()
        
        // If we've reached the end, stop
        if currentIndex >= allDataPoints.count - 1 {
            pause()
        }
    }
    
    /// Update the visible data points
    private func updateVisibleData() {
        guard !allDataPoints.isEmpty else {
            visiblePoints = []
            return
        }
        
        // Calculate start index (ensure we don't go below 0)
        let startIndex = max(0, currentIndex - visibleCount + 1)
        
        // Calculate end index (ensure we don't exceed array bounds)
        let endIndex = min(allDataPoints.count, startIndex + visibleCount)
        
        // Get visible slice
        visiblePoints = Array(allDataPoints[startIndex..<endIndex])
    }
} 