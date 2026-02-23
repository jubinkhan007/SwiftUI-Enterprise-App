import Foundation
import SwiftData

/// Protocol defining the contract for local persistence.
public protocol PersistenceServiceProtocol {
    func insert<T: PersistentModel>(_ model: T) throws
    func fetch<T: PersistentModel>(descriptor: FetchDescriptor<T>) throws -> [T]
    func delete<T: PersistentModel>(_ model: T) throws
    func save() throws
}

/// A SwiftData implementation of the Persistence Service.
@MainActor
public final class SwiftDataService: PersistenceServiceProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public init(schema: Schema, isStoredInMemoryOnly: Bool = false) throws {
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        self.modelContext = modelContainer.mainContext
    }

    public func insert<T: PersistentModel>(_ model: T) throws {
        modelContext.insert(model)
        try save()
    }

    public func fetch<T: PersistentModel>(descriptor: FetchDescriptor<T>) throws -> [T] {
        return try modelContext.fetch(descriptor)
    }

    public func delete<T: PersistentModel>(_ model: T) throws {
        modelContext.delete(model)
        try save()
    }

    public func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
}
