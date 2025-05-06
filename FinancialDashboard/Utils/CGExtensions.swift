import CoreGraphics
import UIKit

// MARK: - CGContext Extensions
extension CGContext {
    /// Draw a line from one point to another
    /// - Parameters:
    ///   - from: Starting point
    ///   - to: Ending point
    func drawLine(from: CGPoint, to: CGPoint) {
        move(to: from)
        addLine(to: to)
        strokePath()
    }
    
    /// Fill a rectangle with a specific color
    /// - Parameters:
    ///   - rect: The rectangle to fill
    ///   - color: The color to use
    func fillRect(_ rect: CGRect, with color: CGColor) {
        setFillColor(color)
        fill(rect)
    }
    
    /// Stroke a rectangle with a specific color and line width
    /// - Parameters:
    ///   - rect: The rectangle to stroke
    ///   - color: The color to use
    ///   - lineWidth: The line width to use
    func strokeRect(_ rect: CGRect, with color: CGColor, lineWidth: CGFloat = 1.0) {
        setStrokeColor(color)
        setLineWidth(lineWidth)
        stroke(rect)
    }
    
    /// Draw a dashed vertical line
    /// - Parameters:
    ///   - x: X position of the line
    ///   - fromY: Starting Y position
    ///   - toY: Ending Y position
    ///   - color: Line color
    ///   - lineWidth: Line width
    ///   - dashPattern: The dash pattern to use
    func drawDashedVerticalLine(at x: CGFloat, fromY: CGFloat, toY: CGFloat, 
                                color: CGColor, lineWidth: CGFloat = 1.0, 
                                dashPattern: [CGFloat] = [4, 4]) {
        saveGState()
        setStrokeColor(color)
        setLineWidth(lineWidth)
        setLineDash(phase: 0, lengths: dashPattern)
        
        move(to: CGPoint(x: x, y: fromY))
        addLine(to: CGPoint(x: x, y: toY))
        strokePath()
        
        restoreGState()
    }
    
    /// Draw text at a specified position
    /// - Parameters:
    ///   - text: The text to draw
    ///   - point: The position to draw at
    ///   - font: The font to use
    ///   - color: The text color
    ///   - alignment: Text alignment
    func drawText(_ text: String, at point: CGPoint, font: UIFont, color: CGColor, 
                  alignment: NSTextAlignment = .left) {
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        var drawPoint = point
        switch alignment {
        case .center:
            drawPoint.x -= textSize.width / 2
        case .right:
            drawPoint.x -= textSize.width
        default:
            break
        }
        
        saveGState()
        
        // Flip coordinate system for text drawing (UIKit's coordinate system is upside down)
        textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        
        let textPath = CGMutablePath()
        textPath.addRect(CGRect(origin: drawPoint, size: textSize))
        
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), textPath, nil)
        
        CTFrameDraw(frame, self)
        
        restoreGState()
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    /// Create a gradient of colors
    /// - Parameters:
    ///   - other: The color to blend with
    ///   - progress: The blend amount (0 = self, 1 = other)
    /// - Returns: A new color blended between self and other
    func blend(with other: UIColor, progress: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let p = min(max(0, progress), 1) // Ensure progress is between 0 and 1
        
        return UIColor(
            red: r1 + (r2 - r1) * p,
            green: g1 + (g2 - g1) * p,
            blue: b1 + (b2 - b1) * p,
            alpha: a1 + (a2 - a1) * p
        )
    }
} 