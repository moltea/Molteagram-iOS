import UIKit

/// Connects the application's single window to UIKit's scene lifecycle.
@objc(MolteagramSceneDelegate) final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var pendingShortcutItem: UIApplicationShortcutItem?

    private var appDelegate: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene, let window = self.appDelegate?.window else {
            return
        }

        // Application services also initialize for background launches, before a scene exists.
        window.windowScene = windowScene
        window.frame = windowScene.coordinateSpace.bounds
        self.window = window
        window.makeKeyAndVisible()

        self.pendingShortcutItem = connectionOptions.shortcutItem
        self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        for userActivity in connectionOptions.userActivities {
            self.scene(scene, continue: userActivity)
        }
        // Notification responses remain handled by AppDelegate's notification center delegate.
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        self.window?.isHidden = true
        self.window?.windowScene = nil
        self.window = nil
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.appDelegate?.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        self.appDelegate?.applicationDidBecomeActive(UIApplication.shared)
        if let shortcutItem = self.pendingShortcutItem {
            self.pendingShortcutItem = nil
            self.appDelegate?.application(UIApplication.shared, performActionFor: shortcutItem, completionHandler: { _ in })
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        self.appDelegate?.applicationWillResignActive(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        self.appDelegate?.applicationDidEnterBackground(UIApplication.shared)
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        for urlContext in urlContexts {
            var options: [UIApplication.OpenURLOptionsKey: Any] = [.openInPlace: urlContext.options.openInPlace]
            if let sourceApplication = urlContext.options.sourceApplication {
                options[.sourceApplication] = sourceApplication
            }
            if let annotation = urlContext.options.annotation {
                options[.annotation] = annotation
            }
            let _ = self.appDelegate?.application(UIApplication.shared, open: urlContext.url, options: options)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        let _ = self.appDelegate?.application(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let appDelegate = self.appDelegate else {
            completionHandler(false)
            return
        }
        appDelegate.application(UIApplication.shared, performActionFor: shortcutItem, completionHandler: completionHandler)
    }

    @available(iOS 26.0, *)
    func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        return .minimal
    }
}
