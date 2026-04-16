import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

private let kMolteagramDeletedTag = LocalMessageTags(rawValue: 1 << 2)

private final class DeletedMessagesChatContentsImpl {
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
            guard let self else { return }
            self.handleCombinedView(combined, peerId: peerId)
        })
    }

    private func handleCombinedView(_ combined: CombinedView, peerId: PeerId) {
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

final class DeletedMessagesChatContents: ChatCustomContentsProtocol {

    var kind: ChatCustomContentsKind = .deletedMessages

    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return impl.signalWith { impl, subscriber in
            if let current = impl.currentView {
                subscriber.putNext((current, .Initial))
            } else {
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

    func enqueueMessages(messages: [EnqueueMessage]) {}
    func deleteMessages(ids: [EngineMessage.Id]) {}
    func editMessage(
        id: EngineMessage.Id,
        text: String,
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

    private let impl: QueueLocalObject<DeletedMessagesChatContentsImpl>

    init(context: AccountContext, peerId: PeerId) {
        let queue = Queue(name: "DeletedMessagesChatContents")
        impl = QueueLocalObject(queue: queue) {
            DeletedMessagesChatContentsImpl(queue: queue, context: context, peerId: peerId)
        }
    }
}
