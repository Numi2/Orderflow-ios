import SwiftUI
import PencilKit

/// View for annotating charts with Apple Pencil
struct ChartAnnotationView: View {
    @StateObject private var annotationManager = AnnotationManager()
    @EnvironmentObject private var themeManager: ThemeManager
    
    @Binding var isPresented: Bool
    let chartData: [ChartDataPoint]
    let symbol: String
    
    @State private var chartType: ChartType = .candlestick
    @State private var showTools = true
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text("Draw Mode: \(symbol)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showTools.toggle()
                    }) {
                        Image(systemName: showTools ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                            .imageScale(.medium)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Drawing Tools
                if showTools {
                    drawingToolbar
                }
                
                // Main drawing area with chart and annotations
                ZStack {
                    // Chart layer
                    ChartView(data: chartData, chartType: chartType)
                        .allowsHitTesting(false)
                    
                    // Apple Pencil drawing layer if enabled
                    if annotationManager.usePencilKit {
                        PencilKitCanvasRepresentable(canvasView: $annotationManager.canvasView, isErasing: annotationManager.selectedTool == .eraser)
                            .opacity(0.9)
                    }
                    
                    // Custom drawing layer
                    AnnotationDrawingView(manager: annotationManager)
                        .opacity(0.9)
                    
                    // Text entry overlay
                    if annotationManager.isTextEntryActive, let annotation = annotationManager.currentAnnotation, annotation.tool == .text, !annotation.points.isEmpty {
                        VStack {
                            TextField("Enter text", text: $annotationManager.currentText)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                                .position(annotation.points[0])
                            
                            HStack {
                                Button("Cancel") {
                                    annotationManager.cancelTextEntry()
                                }
                                
                                Button("Done") {
                                    annotationManager.completeTextEntry()
                                }
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .position(CGPoint(x: annotation.points[0].x, y: annotation.points[0].y + 50))
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if annotationManager.currentAnnotation == nil {
                                annotationManager.startAnnotation(at: value.location)
                            } else {
                                annotationManager.updateAnnotation(at: value.location)
                            }
                        }
                        .onEnded { value in
                            annotationManager.endAnnotation()
                        }
                )
            }
        }
        .onAppear {
            // Configure PencilKit canvas
            annotationManager.canvasView.tool = PKInkingTool(.pen, color: UIColor.red, width: 2.0)
            annotationManager.canvasView.drawingPolicy = .pencilOnly
            
            // Update canvas background color based on theme
            updateCanvasBackgroundColor()
        }
        .onChange(of: themeManager.themeMode) { _ in
            updateCanvasBackgroundColor()
        }
    }
    
    // Drawing toolbar UI
    private var drawingToolbar: some View {
        VStack(spacing: 0) {
            // Tool selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Spacer(minLength: 12)
                    
                    ForEach(DrawingTool.allCases) { tool in
                        Button(action: {
                            annotationManager.selectedTool = tool
                            
                            // Update PencilKit tool
                            if tool == .eraser {
                                annotationManager.canvasView.tool = PKEraserTool(.vector)
                            } else if tool == .pencil {
                                let color = UIColor(annotationManager.selectedColor)
                                let width = annotationManager.strokeWidth
                                annotationManager.canvasView.tool = PKInkingTool(.pen, color: color, width: width)
                            }
                        }) {
                            VStack {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 20))
                                    .foregroundColor(annotationManager.selectedTool == tool ? .accentColor : .primary)
                                    .frame(width: 32, height: 32)
                                
                                Text(tool.rawValue)
                                    .font(.caption)
                                    .foregroundColor(annotationManager.selectedTool == tool ? .accentColor : .secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(annotationManager.selectedTool == tool ? Color(.secondarySystemBackground) : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer(minLength: 12)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            Divider()
            
            // Color and thickness selection
            HStack(spacing: 16) {
                // Color picker
                ColorPicker("", selection: $annotationManager.selectedColor)
                    .onChange(of: annotationManager.selectedColor) { newColor in
                        // Update PencilKit tool color
                        if annotationManager.selectedTool == .pencil {
                            let uiColor = UIColor(newColor)
                            let width = annotationManager.strokeWidth
                            annotationManager.canvasView.tool = PKInkingTool(.pen, color: uiColor, width: width)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 40)
                
                // Stroke width slider
                HStack {
                    Text("Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $annotationManager.strokeWidth, in: 1...10, step: 0.5)
                        .onChange(of: annotationManager.strokeWidth) { newWidth in
                            // Update PencilKit tool width
                            if annotationManager.selectedTool == .pencil {
                                let color = UIColor(annotationManager.selectedColor)
                                annotationManager.canvasView.tool = PKInkingTool(.pen, color: color, width: newWidth)
                            }
                        }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Action buttons
                Button(action: {
                    annotationManager.undoAnnotation()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                
                Button(action: {
                    annotationManager.clearAnnotations()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                }
                
                Toggle(isOn: $annotationManager.usePencilKit) {
                    Label("Apple Pencil", systemImage: "pencil.tip")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .fixedSize()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
        }
    }
    
    // Update PencilKit canvas background color to match theme
    private func updateCanvasBackgroundColor() {
        annotationManager.canvasView.backgroundColor = .clear
    }
}

/// Representable for PencilKit canvas
struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isErasing: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Only handle eraser state changes to avoid disrupting PencilKit's drawing interactions
        if isErasing {
            uiView.tool = PKEraserTool(.vector)
        }
    }
}

/// Custom drawing view for annotations
struct AnnotationDrawingView: View {
    @ObservedObject var manager: AnnotationManager
    
    var body: some View {
        Canvas { context, size in
            // Draw completed annotations
            for annotation in manager.annotations {
                drawAnnotation(annotation, in: context, size: size)
            }
            
            // Draw current annotation being created
            if let currentAnnotation = manager.currentAnnotation {
                drawAnnotation(currentAnnotation, in: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func drawAnnotation(_ annotation: Annotation, in context: GraphicsContext, size: CGSize) {
        let points = annotation.points
        guard !points.isEmpty else { return }
        
        // Set up stroke style
        let stroke = StrokeStyle(
            lineWidth: annotation.strokeWidth,
            lineCap: .round,
            lineJoin: .round
        )
        
        // Draw based on tool type
        switch annotation.tool {
        case .pencil:
            drawFreehandLine(points, in: context, color: annotation.color, style: stroke)
            
        case .line:
            drawStraightLine(points, in: context, color: annotation.color, style: stroke)
            
        case .arrow:
            drawArrow(points, in: context, color: annotation.color, style: stroke)
            
        case .rectangle:
            drawRectangle(points, in: context, color: annotation.color, style: stroke)
            
        case .ellipse:
            drawEllipse(points, in: context, color: annotation.color, style: stroke)
            
        case .text:
            drawText(annotation, in: context)
            
        case .eraser:
            // Eraser is not drawn - it's handled by the annotation manager
            break
        }
    }
    
    private func drawFreehandLine(_ points: [CGPoint], in context: GraphicsContext, color: Color, style: StrokeStyle) {
        guard points.count > 1 else { return }
        
        var path = Path()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        context.stroke(path, with: .color(color), style: style)
    }
    
    private func drawStraightLine(_ points: [CGPoint], in context: GraphicsContext, color: Color, style: StrokeStyle) {
        guard points.count >= 2 else { return }
        
        var path = Path()
        path.move(to: points[0])
        path.addLine(to: points.last!)
        
        context.stroke(path, with: .color(color), style: style)
    }
    
    private func drawArrow(_ points: [CGPoint], in context: GraphicsContext, color: Color, style: StrokeStyle) {
        guard points.count >= 2 else { return }
        
        let start = points[0]
        let end = points.last!
        
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        // Add arrowhead
        let length = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let arrowLength = min(length * 0.2, 20)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle = CGFloat.pi / 6  // 30 degrees
        
        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)
        
        context.stroke(path, with: .color(color), style: style)
    }
    
    private func drawRectangle(_ points: [CGPoint], in context: GraphicsContext, color: Color, style: StrokeStyle) {
        guard points.count >= 2 else { return }
        
        let start = points[0]
        let end = points.last!
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        let path = Path(rect)
        context.stroke(path, with: .color(color), style: style)
    }
    
    private func drawEllipse(_ points: [CGPoint], in context: GraphicsContext, color: Color, style: StrokeStyle) {
        guard points.count >= 2 else { return }
        
        let start = points[0]
        let end = points.last!
        
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        
        let path = Path(ellipseIn: rect)
        context.stroke(path, with: .color(color), style: style)
    }
    
    private func drawText(_ annotation: Annotation, in context: GraphicsContext) {
        guard let text = annotation.text, !text.isEmpty, !annotation.points.isEmpty else { return }
        
        let position = annotation.points[0]
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14 * annotation.strokeWidth / 2),
            .foregroundColor: UIColor(annotation.color)
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: textAttributes)
        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 500, height: 100))
        let textImage = renderer.image { context in
            attributedText.draw(at: CGPoint(x: 0, y: 0))
        }
        
        context.draw(Image(uiImage: textImage), at: position)
    }
} 