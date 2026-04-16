import Foundation
import Display
import AccountContext
import Postbox
import TelegramCore
import TelegramPresentationData

public func makeDeletedMessagesScreen(
    context: AccountContext,
    peerId: PeerId
) -> ViewController {
    let contents = DeletedMessagesChatContents(context: context, peerId: peerId)

    let controller = context.sharedContext.makeChatController(
        context: context,
        chatLocation: .customChatContents,
        subject: .customChatContents(contents: contents),
        botStart: nil,
        mode: .standard(.default),
        params: nil
    )

    return controller
}
