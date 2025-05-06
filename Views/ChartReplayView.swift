import SwiftUI

/// View for replaying historical chart data
struct ChartReplayView: View {
    @StateObject private var replayManager = ReplayManager()
    @EnvironmentObject private var themeManager: ThemeManager
    
    @Binding var isPresented: Bool
    let chartData: [ChartDataPoint]
    let symbol: String
    
    @State private var chartType: ChartType = .candlestick
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with title and close button
            HStack {
                Text("Replay Mode: \(symbol)")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    replayManager.pause()
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
            }
            .padding(.horizontal)
            
            // Chart view
            if !replayManager.visiblePoints.isEmpty {
                ChartView(data: replayManager.visiblePoints, chartType: chartType)
                    .frame(height: 300)
            } else {
                Text("No data to replay")
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
            
            // Replay controls
            VStack(spacing: 12) {
                // Progress slider
                Slider(value: Binding(
                    get: { replayManager.progress },
                    set: { replayManager.seek(to: $0) }
                ), in: 0...1, step: 0.01)
                .padding(.horizontal)
                
                // Playback controls
                HStack {
                    Button(action: {
                        replayManager.reset()
                    }) {
                        Image(systemName: "backward.end.fill")
                            .imageScale(.large)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if replayManager.isPlaying {
                            replayManager.pause()
                        } else {
                            replayManager.play()
                        }
                    }) {
                        Image(systemName: replayManager.isPlaying ? "pause.fill" : "play.fill")
                            .imageScale(.large)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Speed picker
                    Picker("Speed", selection: Binding(
                        get: { replayManager.speed },
                        set: { replayManager.setSpeed($0) }
                    )) {
                        ForEach(ReplaySpeed.allCases) { speed in
                            Text(speed.description).tag(speed)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 60)
                }
                .padding(.horizontal, 32)
                
                // Chart type selection
                Picker("Chart Type", selection: $chartType) {
                    Text("Candlestick").tag(ChartType.candlestick)
                    Text("OHLC").tag(ChartType.ohlc)
                    Text("Heikin-Ashi").tag(ChartType.heikinAshi)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .onAppear {
            replayManager.setupReplay(dataPoints: chartData)
        }
        .onDisappear {
            replayManager.pause()
        }
    }
}

// MARK: - Preview Provider

struct ChartReplayView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample data
        let data = (0..<100).map { i -> ChartDataPoint in
            let date = Calendar.current.date(byAdding: .hour, value: i, to: Date())!
            let open = 100.0 + Double.random(in: -5...5)
            let close = open + Double.random(in: -3...3)
            let high = max(open, close) + Double.random(in: 0...2)
            let low = min(open, close) - Double.random(in: 0...2)
            return ChartDataPoint(
                time: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: Double.random(in: 100...1000),
                bidVolume: Double.random(in: 50...500),
                askVolume: Double.random(in: 50...500)
            )
        }
        
        return ChartReplayView(isPresented: .constant(true), chartData: data, symbol: "AAPL")
            .environmentObject(ThemeManager())
    }
} 