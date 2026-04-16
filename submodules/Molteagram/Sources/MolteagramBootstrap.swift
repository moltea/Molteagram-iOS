import Foundation
import Display
import AccountContext
import Postbox
import MolteagramCore


public enum MolteagramBootstrap {
    public static func registerCallbacks(
        context: AccountContext,
        navigationController: NavigationController
    ) {
        MolteagramInterceptor.shared.openDeletedMessages = { [weak navigationController] peerIdInt64 in
            guard let nav = navigationController else { return }
            let peerId = PeerId(peerIdInt64)
            let screen = makeDeletedMessagesScreen(context: context, peerId: peerId)
            nav.pushViewController(screen)
        }
    }
}
