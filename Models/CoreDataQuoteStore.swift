import Foundation
import CoreData
import Combine

/// CoreData implementation of the QuoteStore protocol
final class CoreDataQuoteStore: QuoteStore {
    // MARK: - Properties
    
    /// CoreData persistent container
    private let container: NSPersistentContainer
    
    /// Quote publishers for real-time updates
    private var quotePublishers: [String: PassthroughSubject<any QuoteData, Error>] = [:]
    
    /// Price publishers for real-time updates
    private var pricePublishers: [String: [String: PassthroughSubject<ChartDataPoint, Error>]] = [:]
    
    // MARK: - Init
    
    /// Initialize with an in-memory store (for testing) or persistent store
    /// - Parameter inMemory: Whether to use an in-memory store
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FinancialData")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading CoreData: \(error)")
            }
        }
        
        // Set merge policy to overwrite conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Background context helper
    
    /// Create a background context for performing operations
    private func backgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - CRUD Operations
    
    func quote(for symbol: String) async throws -> any QuoteData {
        let context = backgroundContext()
        
        let result = try await context.perform {
            let request = NSFetchRequest<CDQuote>(entityName: "CDQuote")
            request.predicate = NSPredicate(format: "symbol == %@", symbol)
            request.fetchLimit = 1
            
            let quotes = try context.fetch(request)
            guard let cdQuote = quotes.first else {
                throw QuoteStoreError.notFound
            }
            
            // Convert to domain model
            if cdQuote.type == "stock" {
                return StockQuote(
                    symbol: cdQuote.symbol ?? "",
                    name: cdQuote.name ?? "",
                    price: cdQuote.price,
                    changePercent: cdQuote.changePercent
                )
            } else {
                return CryptoQuote(
                    symbol: cdQuote.symbol ?? "",
                    name: cdQuote.name ?? "",
                    price: cdQuote.price,
                    changePercent: cdQuote.changePercent
                )
            }
        }
        
        return result
    }
    
    func allQuotes() async throws -> [any QuoteData] {
        let context = backgroundContext()
        
        let result = try await context.perform {
            let request = NSFetchRequest<CDQuote>(entityName: "CDQuote")
            
            let cdQuotes = try context.fetch(request)
            
            // Convert to domain models
            return cdQuotes.compactMap { cdQuote -> (any QuoteData)? in
                if cdQuote.type == "stock" {
                    return StockQuote(
                        symbol: cdQuote.symbol ?? "",
                        name: cdQuote.name ?? "",
                        price: cdQuote.price, 
                        changePercent: cdQuote.changePercent
                    )
                } else {
                    return CryptoQuote(
                        symbol: cdQuote.symbol ?? "",
                        name: cdQuote.name ?? "",
                        price: cdQuote.price,
                        changePercent: cdQuote.changePercent
                    )
                }
            }
        }
        
        return result
    }
    
    func save(quote: any QuoteData) async throws {
        let context = backgroundContext()
        
        try await context.perform {
            // Check if quote already exists
            let request = NSFetchRequest<CDQuote>(entityName: "CDQuote")
            request.predicate = NSPredicate(format: "symbol == %@", quote.symbol)
            request.fetchLimit = 1
            
            let existingQuotes = try context.fetch(request)
            let cdQuote: CDQuote
            
            if let existing = existingQuotes.first {
                cdQuote = existing
            } else {
                cdQuote = CDQuote(context: context)
                cdQuote.symbol = quote.symbol
            }
            
            // Update properties
            cdQuote.name = quote.name
            cdQuote.price = quote.price
            cdQuote.changePercent = quote.changePercent
            cdQuote.updatedAt = Date()
            
            // Set type based on concrete type
            if quote is StockQuote {
                cdQuote.type = "stock"
            } else if quote is CryptoQuote {
                cdQuote.type = "crypto"
            }
            
            if context.hasChanges {
                try context.save()
            }
            
            // Notify subscribers on the main thread
            Task { @MainActor in
                quotePublishers[quote.symbol]?.send(quote)
            }
        }
    }
    
    func save(quotes: [any QuoteData]) async throws {
        let context = backgroundContext()
        
        try await context.perform {
            for quote in quotes {
                // Check if quote already exists
                let request = NSFetchRequest<CDQuote>(entityName: "CDQuote")
                request.predicate = NSPredicate(format: "symbol == %@", quote.symbol)
                request.fetchLimit = 1
                
                let existingQuotes = try context.fetch(request)
                let cdQuote: CDQuote
                
                if let existing = existingQuotes.first {
                    cdQuote = existing
                } else {
                    cdQuote = CDQuote(context: context)
                    cdQuote.symbol = quote.symbol
                }
                
                // Update properties
                cdQuote.name = quote.name
                cdQuote.price = quote.price
                cdQuote.changePercent = quote.changePercent
                cdQuote.updatedAt = Date()
                
                // Set type based on concrete type
                if quote is StockQuote {
                    cdQuote.type = "stock"
                } else if quote is CryptoQuote {
                    cdQuote.type = "crypto"
                }
            }
            
            if context.hasChanges {
                try context.save()
            }
            
            // Notify subscribers on the main thread
            Task { @MainActor in
                for quote in quotes {
                    quotePublishers[quote.symbol]?.send(quote)
                }
            }
        }
    }
    
    func delete(symbol: String) async throws {
        let context = backgroundContext()
        
        try await context.perform {
            let request = NSFetchRequest<CDQuote>(entityName: "CDQuote")
            request.predicate = NSPredicate(format: "symbol == %@", symbol)
            
            let quotes = try context.fetch(request)
            
            for quote in quotes {
                context.delete(quote)
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    // MARK: - Chart Data Operations
    
    func chartData(for symbol: String, timeframe: String, limit: Int?) async throws -> [ChartDataPoint] {
        let context = backgroundContext()
        
        let result = try await context.perform {
            let request = NSFetchRequest<CDChartDataPoint>(entityName: "CDChartDataPoint")
            request.predicate = NSPredicate(format: "symbol == %@ AND timeframe == %@", symbol, timeframe)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            let cdPoints = try context.fetch(request)
            
            // Convert to domain models
            return cdPoints.map { cdPoint in
                ChartDataPoint(
                    time: cdPoint.timestamp ?? Date(),
                    open: cdPoint.open,
                    high: cdPoint.high,
                    low: cdPoint.low,
                    close: cdPoint.close,
                    volume: cdPoint.volume,
                    bidVolume: cdPoint.bidVolume,
                    askVolume: cdPoint.askVolume
                )
            }
        }
        
        return result
    }
    
    func saveChartData(_ data: [ChartDataPoint], for symbol: String, timeframe: String) async throws {
        let context = backgroundContext()
        
        try await context.perform {
            // Get existing timestamps to avoid duplicates
            let request = NSFetchRequest<CDChartDataPoint>(entityName: "CDChartDataPoint")
            request.predicate = NSPredicate(format: "symbol == %@ AND timeframe == %@", symbol, timeframe)
            request.propertiesToFetch = ["timestamp"]
            
            let existingPoints = try context.fetch(request)
            let existingTimestamps = Set(existingPoints.compactMap { $0.timestamp?.timeIntervalSince1970 })
            
            // Save new data points
            for point in data {
                if !existingTimestamps.contains(point.time.timeIntervalSince1970) {
                    let cdPoint = CDChartDataPoint(context: context)
                    cdPoint.symbol = symbol
                    cdPoint.timeframe = timeframe
                    cdPoint.timestamp = point.time
                    cdPoint.open = point.open
                    cdPoint.high = point.high
                    cdPoint.low = point.low
                    cdPoint.close = point.close
                    cdPoint.volume = point.volume
                    cdPoint.bidVolume = point.bidVolume
                    cdPoint.askVolume = point.askVolume
                    
                    // Notify subscribers on the main thread
                    Task { @MainActor in
                        pricePublishers[symbol]?[timeframe]?.send(point)
                    }
                }
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    func deleteChartData(for symbol: String, timeframe: String?) async throws {
        let context = backgroundContext()
        
        try await context.perform {
            let request = NSFetchRequest<CDChartDataPoint>(entityName: "CDChartDataPoint")
            
            if let timeframe = timeframe {
                request.predicate = NSPredicate(format: "symbol == %@ AND timeframe == %@", symbol, timeframe)
            } else {
                request.predicate = NSPredicate(format: "symbol == %@", symbol)
            }
            
            let points = try context.fetch(request)
            
            for point in points {
                context.delete(point)
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    // MARK: - Real-time Streaming
    
    func subscribeToQuotes(for symbol: String) -> AnyPublisher<any QuoteData, Error> {
        // Create publisher if it doesn't exist
        if quotePublishers[symbol] == nil {
            quotePublishers[symbol] = PassthroughSubject<any QuoteData, Error>()
        }
        
        return quotePublishers[symbol]!.eraseToAnyPublisher()
    }
    
    func subscribeToPriceUpdates(for symbol: String, timeframe: String) -> AnyPublisher<ChartDataPoint, Error> {
        // Create publisher if it doesn't exist
        if pricePublishers[symbol] == nil {
            pricePublishers[symbol] = [:]
        }
        
        if pricePublishers[symbol]?[timeframe] == nil {
            pricePublishers[symbol]?[timeframe] = PassthroughSubject<ChartDataPoint, Error>()
        }
        
        return pricePublishers[symbol]![timeframe]!.eraseToAnyPublisher()
    }
}

// MARK: - CoreData Model Classes

/// CoreData model for storing quotes
@objc(CDQuote)
class CDQuote: NSManagedObject {
    @NSManaged var symbol: String?
    @NSManaged var name: String?
    @NSManaged var price: Double
    @NSManaged var changePercent: Double
    @NSManaged var type: String?
    @NSManaged var updatedAt: Date?
}

/// CoreData model for storing chart data points
@objc(CDChartDataPoint)
class CDChartDataPoint: NSManagedObject {
    @NSManaged var symbol: String?
    @NSManaged var timeframe: String?
    @NSManaged var timestamp: Date?
    @NSManaged var open: Double
    @NSManaged var high: Double
    @NSManaged var low: Double
    @NSManaged var close: Double
    @NSManaged var volume: Double
    @NSManaged var bidVolume: Double
    @NSManaged var askVolume: Double
} 