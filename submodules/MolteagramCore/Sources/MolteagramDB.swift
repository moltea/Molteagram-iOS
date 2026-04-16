import Foundation
import SwiftData

public final class MolteagramDB {

    private static var instances: [String: MolteagramDB] = [:]
    private static let lock = NSLock()

    public static func get(bundleId: String) -> MolteagramDB {
        lock.lock()
        defer { lock.unlock() }
        if let existing = instances[bundleId] { return existing }
        let instance = MolteagramDB(bundleId: bundleId)
        instances[bundleId] = instance
        return instance
    }

    private let container: ModelContainer

    init(bundleId: String) {
        let groupId = "group.\(bundleId)"
        let dbURL: URL

        if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
            dbURL = groupContainer.appendingPathComponent("molteagram.sqlite")
        } else {
            dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("molteagram.sqlite")
        }

        let schema = Schema([
            EditedMsgMappingSD.self,
        ])

        let config = ModelConfiguration(schema: schema, url: dbURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("MolteagramDB: failed to create ModelContainer at \(dbURL): \(error)")
        }
    }

    public var context: ModelContext {
        ModelContext(container)
    }

    @MainActor
    public var mainContext: ModelContext {
        container.mainContext
    }
}
