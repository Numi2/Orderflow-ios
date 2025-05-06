import SwiftUI
import PencilKit

/// Types of drawing tools
enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil = "Pencil"
    case line = "Line"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case text = "Text"
    case eraser = "Eraser"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .pencil: return "pencil"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "text.cursor"
        case .eraser: return "eraser"
        }
    }
}

/// A single annotation
struct Annotation: Identifiable {
    let id: UUID
    var tool: DrawingTool
    var color: Color
    var strokeWidth: CGFloat
    var points: [CGPoint]
    var text: String?
    
    init(tool: DrawingTool, color: Color, strokeWidth: CGFloat, points: [CGPoint] = [], text: String? = nil) {
        self.id = UUID()
        self.tool = tool
        self.color = color
        self.strokeWidth = strokeWidth
        self.points = points
        self.text = text
    }
}

/// Manager for drawing annotations
final class AnnotationManager: ObservableObject {
    // MARK: - Published Properties
    
    /// All annotations
    @Published var annotations: [Annotation] = []
    
    /// Current annotation being drawn
    @Published var currentAnnotation: Annotation?
    
    /// Currently selected tool
    @Published var selectedTool: DrawingTool = .pencil
    
    /// Currently selected color
    @Published var selectedColor: Color = .red
    
    /// Currently selected stroke width
    @Published var strokeWidth: CGFloat = 2.0
    
    /// Currently entered text (for text tool)
    @Published var currentText: String = ""
    
    /// Is text entry active
    @Published var isTextEntryActive = false
    
    /// PencilKit canvas state for direct drawing
    @Published var canvasView = PKCanvasView()
    
    /// Whether to use PencilKit for drawing
    @Published var usePencilKit = true
    
    // MARK: - Methods
    
    /// Start a new annotation
    /// - Parameter point: Starting point
    func startAnnotation(at point: CGPoint) {
        // Don't start a new annotation if we're in text entry mode
        guard !isTextEntryActive else { return }
        
        // If we're using PencilKit for pencil drawing, let it handle drawing
        if usePencilKit && selectedTool == .pencil {
            return
        }
        
        // Create a new annotation
        currentAnnotation = Annotation(
            tool: selectedTool,
            color: selectedColor,
            strokeWidth: strokeWidth,
            points: [point]
        )
    }
    
    /// Update the current annotation
    /// - Parameter point: New point
    func updateAnnotation(at point: CGPoint) {
        guard var annotation = currentAnnotation else { return }
        
        // Add point to annotation
        annotation.points.append(point)
        currentAnnotation = annotation
    }
    
    /// Complete the current annotation
    func endAnnotation() {
        guard let annotation = currentAnnotation else { return }
        
        // For text tool, enter text editing mode
        if annotation.tool == .text {
            isTextEntryActive = true
            return
        }
        
        // Add the annotation to the list
        annotations.append(annotation)
        currentAnnotation = nil
    }
    
    /// Complete text entry
    func completeTextEntry() {
        guard var annotation = currentAnnotation, annotation.tool == .text else {
            isTextEntryActive = false
            return
        }
        
        // Add text to annotation
        annotation.text = currentText
        annotations.append(annotation)
        
        // Reset state
        currentAnnotation = nil
        currentText = ""
        isTextEntryActive = false
    }
    
    /// Cancel text entry
    func cancelTextEntry() {
        currentAnnotation = nil
        currentText = ""
        isTextEntryActive = false
    }
    
    /// Cancel current annotation
    func cancelAnnotation() {
        currentAnnotation = nil
    }
    
    /// Clear all annotations
    func clearAnnotations() {
        annotations.removeAll()
        
        // Clear PencilKit canvas if we're using it
        if usePencilKit {
            canvasView.drawing = PKDrawing()
        }
    }
    
    /// Undo last annotation
    func undoAnnotation() {
        if !annotations.isEmpty {
            annotations.removeLast()
        } else if usePencilKit {
            // If no custom annotations, undo in PencilKit
            canvasView.undoManager?.undo()
        }
    }
} 