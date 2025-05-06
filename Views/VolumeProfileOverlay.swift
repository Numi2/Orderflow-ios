import UIKit

final class VolumeProfileOverlay: UIView {

    var data: [ChartDataPoint] = [] { didSet { setNeedsDisplay() } }
    var bins: Int = 48

    override func draw(_ rect: CGRect) {
        guard !data.isEmpty else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // price range
        guard let minP = data.map(\.low).min(),
              let maxP = data.map(\.high).max()
        else { return }
        let binSize = (maxP - minP) / Double(bins)

        // accumulate volume per bin
        var hist = [Double](repeating: 0, count: bins)
        for p in data {
            let v = p.volume
            let b0 = Int((p.low  - minP) / binSize)
            let b1 = Int((p.high - minP) / binSize)
            for b in max(0,b0)...min(b1,bins-1) { hist[b] += v }
        }
        guard let maxVol = hist.max(), maxVol > 0 else { return }

        // draw
        let maxW: CGFloat = 60
        for (i, v) in hist.enumerated() where v > 0 {
            let frac = CGFloat(v / maxVol)
            let w    = frac * maxW
            let y    = CGFloat(i) / CGFloat(bins) * bounds.height
            let h    = bounds.height / CGFloat(bins)
            ctx.setFillColor(UIColor.systemGray4.cgColor)
            ctx.fill(CGRect(x: bounds.maxX - w, y: y, width: w, height: h))
        }
    }
}