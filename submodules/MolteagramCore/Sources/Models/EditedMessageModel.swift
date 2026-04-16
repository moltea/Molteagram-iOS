import Foundation
import SwiftData

public struct EditedMsgMappingEntry {
    public var originalMessageIdInt: Int32
    public var peerIdInt: Int64
    public var cloneMessageIdInt: Int32
    public var cloneNamespaceInt: Int32
    public var editedAt: Date

    public init(
        originalMessageIdInt: Int32,
        peerIdInt: Int64,
        cloneMessageIdInt: Int32,
        cloneNamespaceInt: Int32,
        editedAt: Date = Date()
    ) {
        self.originalMessageIdInt = originalMessageIdInt
        self.peerIdInt = peerIdInt
        self.cloneMessageIdInt = cloneMessageIdInt
        self.cloneNamespaceInt = cloneNamespaceInt
        self.editedAt = editedAt
    }
}

@Model
final class EditedMsgMappingSD {
    var originalMessageIdInt: Int32 = 0
    var peerIdInt: Int64 = 0
    var cloneMessageIdInt: Int32 = 0
    var cloneNamespaceInt: Int32 = 0
    var editedAt: Date = Date()

    init(entry: EditedMsgMappingEntry) {
        self.originalMessageIdInt = entry.originalMessageIdInt
        self.peerIdInt = entry.peerIdInt
        self.cloneMessageIdInt = entry.cloneMessageIdInt
        self.cloneNamespaceInt = entry.cloneNamespaceInt
        self.editedAt = entry.editedAt
    }

    var asEntry: EditedMsgMappingEntry {
        EditedMsgMappingEntry(
            originalMessageIdInt: originalMessageIdInt,
            peerIdInt: peerIdInt,
            cloneMessageIdInt: cloneMessageIdInt,
            cloneNamespaceInt: cloneNamespaceInt,
            editedAt: editedAt
        )
    }
}

public final class EditedMsgStore {

    private static var instances: [String: EditedMsgStore] = [:]
    private static let lock = NSLock()

    public static func get(bundleId: String) -> EditedMsgStore {
        lock.lock()
        defer { lock.unlock() }
        if let existing = instances[bundleId] { return existing }
        let instance = EditedMsgStore(bundleId: bundleId)
        instances[bundleId] = instance
        return instance
    }

    private let db: MolteagramDB
    private var observer: NSObjectProtocol?

    private init(bundleId: String) {
        self.db = MolteagramDB.get(bundleId: bundleId)
        
        self.observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MolteagramEditedMessageCloned"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let userInfo = notification.userInfo else { return }
            guard let originalMessageIdInt = userInfo["originalMessageIdInt"] as? Int32,
                  let peerIdInt = userInfo["peerIdInt"] as? Int64,
                  let cloneMessageIdInt = userInfo["cloneMessageIdInt"] as? Int32,
                  let cloneNamespaceInt = userInfo["cloneNamespaceInt"] as? Int32 else { return }
                  
            let entry = EditedMsgMappingEntry(
                originalMessageIdInt: originalMessageIdInt,
                peerIdInt: peerIdInt,
                cloneMessageIdInt: cloneMessageIdInt,
                cloneNamespaceInt: cloneNamespaceInt
            )
            self.push(entry)
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func push(_ entry: EditedMsgMappingEntry) {
        let ctx = db.context
        ctx.insert(EditedMsgMappingSD(entry: entry))
        try? ctx.save()
    }

    public func historyCloneIds(for originalMessageId: Int32, peerId: Int64) -> [EditedMsgMappingEntry] {
        let ctx = db.context
        let descriptor = FetchDescriptor<EditedMsgMappingSD>(
            predicate: #Predicate { $0.originalMessageIdInt == originalMessageId && $0.peerIdInt == peerId },
            sortBy: [SortDescriptor(\.cloneMessageIdInt, order: .forward)]
        )
        return (try? ctx.fetch(descriptor))?.map(\.asEntry) ?? []
    }

    public func delete(originalMessageId: Int32, peerId: Int64) {
        let ctx = db.context
        try? ctx.delete(
            model: EditedMsgMappingSD.self,
            where: #Predicate { $0.originalMessageIdInt == originalMessageId && $0.peerIdInt == peerId }
        )
        try? ctx.save()
    }
}
