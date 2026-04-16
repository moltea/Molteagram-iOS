import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

// MARK: - LocalMessageTags bit 2 = Molteagram "soft-deleted"
// Set by Postbox.swift deleteMessages / deleteMessagesInRange when saveDeletedMessages is enabled.
private let kMolteagramDeletedTag = LocalMessageTags(rawValue: 1 << 2)

// MARK: - Impl (runs on its own serial queue)

private final class MolteagramDeletedMessagesChatContentsImpl {
    let queue: Queue
    private let context: AccountContext
    private let peerId: PeerId

    private(set) var currentView: MessageHistoryView?
    let historyViewPipe = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
    private var viewDisposable: Disposable?

    init(queue: Queue, context: AccountContext, peerId: PeerId) {
        self.queue = queue
        self.context = context
        self.peerId = peerId
        self.subscribe()
    }

    deinit {
        viewDisposable?.dispose()
    }

    private func subscribe() {
        let peerId = self.peerId
        viewDisposable = (context.account.postbox.combinedView(keys: [
            .localMessageTag(kMolteagramDeletedTag)
        ]) |> deliverOn(queue)).start(next: { [weak self] combined in
            self?.handle(combined, peerId: peerId)
        })
    }

    private func handle(_ combined: CombinedView, peerId: PeerId) {
        guard let tagView = combined.views[.localMessageTag(kMolteagramDeletedTag)] as? LocalMessageTagsView else {
            return
        }

        let entries: [MessageHistoryEntry] = tagView.messages
            .values
            .filter { $0.id.peerId == peerId }
            .sorted { $0.index < $1.index }
            .map { msg in
                MessageHistoryEntry(
                    message: msg,
                    isRead: true,
                    location: nil,
                    monthLocation: nil,
                    attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)
                )
            }

        let usedNamespaces = Set(entries.map { $0.message.id.namespace })
        let namespaces: MessageIdNamespaces = usedNamespaces.isEmpty
            ? .just(Set([Namespaces.Message.Cloud]))
            : .just(usedNamespaces)

        let view = MessageHistoryView(
            tag: nil,
            namespaces: namespaces,
            entries: entries,
            holeEarlier: false,
            holeLater: false,
            isLoading: false
        )

        let updateType: ViewUpdateType = currentView == nil ? .Initial : .Generic
        currentView = view
        historyViewPipe.putNext((view, updateType))
    }
}

// MARK: - Public ChatCustomContentsProtocol conformance

/// Drives the standard ChatControllerImpl bubble renderer with soft-deleted messages for a peer.
/// Placed in TelegramUI so ChatController can use it without a cross-module callback bridge.
final class MolteagramDeletedMessagesChatContents: ChatCustomContentsProtocol {

    // MARK: ChatCustomContentsProtocol

    var kind: ChatCustomContentsKind = .deletedMessages

    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return impl.signalWith { impl, subscriber in
            if let current = impl.currentView {
                subscriber.putNext((current, .Initial))
            } else {
                // Emit an empty loading placeholder until Postbox delivers
                let empty = MessageHistoryView(
                    tag: nil,
                    namespaces: .just(Set([Namespaces.Message.Cloud])),
                    entries: [],
                    holeEarlier: false,
                    holeLater: false,
                    isLoading: true
                )
                subscriber.putNext((empty, .Initial))
            }
            return impl.historyViewPipe.signal().start(next: subscriber.putNext)
        }
    }

    var messageLimit: Int? { return nil }

    // Read-only — all mutation stubs are no-ops
    func enqueueMessages(messages: [EnqueueMessage]) {}
    func deleteMessages(ids: [EngineMessage.Id]) {}
    func editMessage(
        id: EngineMessage.Id, text: String,
        media: RequestEditMessageMedia,
        entities: TextEntitiesMessageAttribute?,
        webpagePreviewAttribute: WebpagePreviewMessageAttribute?,
        disableUrlPreview: Bool
    ) {}
    func quickReplyUpdateShortcut(value: String) {}
    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {}
    func loadMore() {}
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
    func hashtagSearchUpdate(query: String) {}

    // MARK: Private

    private let impl: QueueLocalObject<MolteagramDeletedMessagesChatContentsImpl>

    init(context: AccountContext, peerId: PeerId) {
        let queue = Queue(name: "MolteagramDeletedMsgContents")
        impl = QueueLocalObject(queue: queue) {
            MolteagramDeletedMessagesChatContentsImpl(queue: queue, context: context, peerId: peerId)
        }
    }
}
