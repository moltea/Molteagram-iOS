import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

private let kMolteagramEditedTag = LocalMessageTags(rawValue: 1 << 4)

private final class MolteagramEditedMessagesChatContentsImpl {
    let queue: Queue
    private let context: AccountContext
    private let originalMessageId: MessageId

    private(set) var currentView: MessageHistoryView?
    let historyViewPipe = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
    private var viewDisposable: Disposable?

    init(queue: Queue, context: AccountContext, originalMessageId: MessageId) {
        self.queue = queue
        self.context = context
        self.originalMessageId = originalMessageId
        self.subscribe()
    }

    deinit {
        viewDisposable?.dispose()
    }

    private func subscribe() {
        let originalMessageId = self.originalMessageId
        viewDisposable = (context.account.postbox.combinedView(keys: [
            .localMessageTag(kMolteagramEditedTag),
            .messages(Set([originalMessageId]))
        ]) |> deliverOn(queue)).start(next: { [weak self] combined in
            self?.handle(combined, originalMessageId: originalMessageId)
        })
    }

    private func handle(_ combined: CombinedView, originalMessageId: MessageId) {
        guard let tagView = combined.views[.localMessageTag(kMolteagramEditedTag)] as? LocalMessageTagsView else {
            return
        }

        var entries: [MessageHistoryEntry] = tagView.messages
            .values
            .filter { msg in
                for attribute in msg.attributes {
                    if let attr = attribute as? EditedCloneMessageAttribute {
                        return attr.originalPeerIdInt64 == originalMessageId.peerId.toInt64()
                            && attr.originalNamespace == originalMessageId.namespace
                            && attr.originalMessageId == originalMessageId.id
                    }
                }
                return false
            }
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

        if let messagesView = combined.views[.messages(Set([originalMessageId]))] as? MessagesView,
           let currentMessage = messagesView.messages[originalMessageId] {
            entries.append(MessageHistoryEntry(
                message: currentMessage,
                isRead: true,
                location: nil,
                monthLocation: nil,
                attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)
            ))
        }

        let usedNamespaces = Set(entries.map { $0.message.id.namespace })
        let namespaces: MessageIdNamespaces = usedNamespaces.isEmpty
            ? .just(Set([Namespaces.Message.LocalEditedArchive]))
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

public final class MolteagramEditedMessagesChatContents: ChatCustomContentsProtocol {

    public var kind: ChatCustomContentsKind {
        return .editedMessages(originalMessageId)
    }

    public var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return impl.signalWith { impl, subscriber in
            if let current = impl.currentView {
                subscriber.putNext((current, .Initial))
            } else {
                let empty = MessageHistoryView(
                    tag: nil,
                    namespaces: .just(Set([Namespaces.Message.LocalEditedArchive])),
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

    public var messageLimit: Int? { return nil }

    public func enqueueMessages(messages: [EnqueueMessage]) {}
    public func deleteMessages(ids: [EngineMessage.Id]) {}
    public func editMessage(
        id: EngineMessage.Id, text: String,
        media: RequestEditMessageMedia,
        entities: TextEntitiesMessageAttribute?,
        webpagePreviewAttribute: WebpagePreviewMessageAttribute?,
        disableUrlPreview: Bool
    ) {}
    public func quickReplyUpdateShortcut(value: String) {}
    public func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {}
    public func loadMore() {}
    public var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
    public func hashtagSearchUpdate(query: String) {}

    private let impl: QueueLocalObject<MolteagramEditedMessagesChatContentsImpl>
    private let originalMessageId: MessageId

    public init(context: AccountContext, originalMessageId: MessageId) {
        self.originalMessageId = originalMessageId
        let queue = Queue(name: "MolteagramEditedMsgContents")
        impl = QueueLocalObject(queue: queue) {
            MolteagramEditedMessagesChatContentsImpl(queue: queue, context: context, originalMessageId: originalMessageId)
        }
    }
}
