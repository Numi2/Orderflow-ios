import Foundation
import Combine

/// A protocol for WebSocket connections
protocol WebSocketConnection {
    /// Connect to the WebSocket server
    func connect()
    
    /// Disconnect from the WebSocket server
    func disconnect()
    
    /// Send a message to the WebSocket server
    /// - Parameter message: The message to send
    func send(message: String)
    
    /// Check if the connection is currently open
    var isConnected: Bool { get }
    
    /// Publisher for incoming messages
    var messagePublisher: AnyPublisher<Data, Error> { get }
}

/// Standard implementation of WebSocketConnection using URLSessionWebSocketTask
class StandardWebSocketConnection: NSObject, WebSocketConnection, URLSessionWebSocketDelegate {
    // MARK: - Properties
    
    /// The URL of the WebSocket server
    private let url: URL
    
    /// URLSession used for the WebSocket connection
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    /// The WebSocket task
    private var webSocketTask: URLSessionWebSocketTask?
    
    /// Subject for publishing messages
    private let messageSubject = PassthroughSubject<Data, Error>()
    
    /// Publisher for messages
    var messagePublisher: AnyPublisher<Data, Error> {
        return messageSubject.eraseToAnyPublisher()
    }
    
    /// Reconnection timer
    private var reconnectTimer: Timer?
    
    /// Maximum number of reconnection attempts
    private let maxReconnectAttempts = 5
    
    /// Current number of reconnection attempts
    private var reconnectAttempts = 0
    
    /// Whether the connection is currently open
    private(set) var isConnected = false
    
    /// Headers to include in the connection request
    private var headers: [String: String]?
    
    // MARK: - Init
    
    /// Initialize with a WebSocket URL
    /// - Parameters:
    ///   - url: The URL of the WebSocket server
    ///   - headers: Optional headers to include in the connection request
    init(url: URL, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
        super.init()
    }
    
    // MARK: - WebSocketConnection
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        var request = URLRequest(url: url)
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        stopReconnectTimer()
    }
    
    func send(message: String) {
        guard isConnected else { return }
        
        webSocketTask?.send(.string(message)) { [weak self] error in
            if let error = error {
                self?.messageSubject.send(completion: .failure(error))
            }
        }
    }
    
    // MARK: - WebSocket message handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.messageSubject.send(data)
                    }
                case .data(let data):
                    self.messageSubject.send(data)
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                self.messageSubject.send(completion: .failure(error))
                self.isConnected = false
                self.startReconnectTimer()
            }
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectAttempts = 0
        stopReconnectTimer()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        
        if closeCode != .normalClosure {
            startReconnectTimer()
        }
    }
    
    // MARK: - Reconnection
    
    private func startReconnectTimer() {
        guard reconnectAttempts < maxReconnectAttempts else {
            messageSubject.send(completion: .failure(WebSocketError.maxReconnectAttemptsReached))
            return
        }
        
        stopReconnectTimer()
        
        // Exponential backoff
        let delay = pow(2.0, Double(reconnectAttempts)) * 1.0
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            self.reconnectAttempts += 1
            self.webSocketTask = nil
            self.connect()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

/// Errors that can occur during WebSocket operations
enum WebSocketError: Error {
    case connectionFailed
    case disconnected
    case messageDecodingFailed
    case invalidMessageFormat
    case maxReconnectAttemptsReached
} 