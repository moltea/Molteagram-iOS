import Foundation
import TelegramCore
import MolteagramCore
import SwiftSignalKit
import Postbox
import OSLog

private enum MolteagramSpecificSharedDataKeyValues: Int32 {
    case molteagramSettings = 501
    case molteagramStatusesSettings = 502
}

public final class GlobalMolteagramState: GlobalMolteagramStateStruct {
    private let lock = NSLock()
    private let lockStatuses = NSLock()
    private var _settings: MolteagramSettings = .defaultSettings
    private var _statusesSettings: MolteagramStatusesSettings = .defaultSettings
    private let settingsPromise = ValuePromise<MolteagramSettings>(.defaultSettings, ignoreRepeated: true)
    public let disposable = MetaDisposable()
    public let disposableStatuses = MetaDisposable()
    public var offlineTimer: SwiftSignalKit.Timer?
    public var performOfflinePing: (() -> Void)?
    public var openDeletedMessages: ((Int64) -> Void)?
    private var debounceTimer: SwiftSignalKit.Timer?
    public func requestDelayedOfflinePing() {
            self.debounceTimer?.invalidate()
            let timer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                self?.performOfflinePing?()
                self?.debounceTimer = nil
            }, queue: .mainQueue())
            self.debounceTimer = timer
            timer.start()
        }
    
    public init() {
        os_log("DEBUG: MolteagramApi is being initialized in process: %{public}@",
                   type: .debug,
                   Bundle.main.bundleIdentifier ?? "unknown")
    }
    
    public static let shared = GlobalMolteagramState()
    public var current: MolteagramSettings {
        get {
            self.lock.lock()
            let value = self._settings
            self.lock.unlock()
            return value
        }
        set {
            self.lock.lock()
            self._settings = newValue
            self.lock.unlock()
            self.settingsPromise.set(newValue)
        }
    }
    public var settingsSignal: Signal<MolteagramSettings, NoError> {
        return self.settingsPromise.get()
    }
    public var typeErasedSettingsSignal: Signal<MolteagramSettingsStruct, NoError> {
        return self.settingsPromise.get() |> map { $0 as MolteagramSettingsStruct }
    }
    public var currentStatuses: MolteagramStatusesSettings {
        get {
            self.lockStatuses.lock()
            let value = self._statusesSettings
            self.lockStatuses.unlock()
            return value
        }
        set {
            self.lockStatuses.lock()
            self._statusesSettings = newValue
            self.lockStatuses.unlock()
        }
    }
}

public struct MolteagramSpecificSharedDataKeys {
    public static let molteagramSettings = applicationSpecificSharedDataKey(MolteagramSpecificSharedDataKeyValues.molteagramSettings.rawValue)
    public static let molteagramStatusesSettings = applicationSpecificSharedDataKey(MolteagramSpecificSharedDataKeyValues.molteagramStatusesSettings.rawValue)
}

public struct MolteagramSettings: Codable, Equatable, MolteagramSettingsStruct {
    public var forceAllowCopy: Bool
    public var disableMarkingAsConsumed: Bool
    public var saveDeletedMessages: Bool
    public var saveEditedMessages: Bool
    public var hideMessageTypingAction: Bool
    public var saveSecretImages: Bool
    public var allowSecretScreenshots: Bool
    public var allowSecretDownload: Bool
    
    public var showUserId: Bool
    public var showGroupsId: Bool
    public var showChannelsId: Bool
    
    public var disableAds: Bool
    public var hideSimilarChannels: Bool
    public var showSecondsInMessages: Bool
    
    public static var defaultSettings: MolteagramSettings {
        return MolteagramSettings(forceAllowCopy: false, disableMarkingAsConsumed: false, saveDeletedMessages: false, saveEditedMessages: false, hideMessageTypingAction: false, saveSecretImages: false, allowSecretScreenshots: false, allowSecretDownload: false,
                                  showUserId: false, showGroupsId: false, showChannelsId: false, disableAds: false, hideSimilarChannels: false, showSecondsInMessages: false)
    }
    
    public init(forceAllowCopy: Bool, disableMarkingAsConsumed: Bool, saveDeletedMessages: Bool, saveEditedMessages: Bool, hideMessageTypingAction: Bool, saveSecretImages: Bool, allowSecretScreenshots: Bool, allowSecretDownload: Bool,
                showUserId: Bool, showGroupsId: Bool, showChannelsId: Bool, disableAds: Bool, hideSimilarChannels: Bool, showSecondsInMessages: Bool) {
        self.forceAllowCopy = forceAllowCopy
        self.disableMarkingAsConsumed = disableMarkingAsConsumed
        self.saveDeletedMessages = saveDeletedMessages
        self.saveEditedMessages = saveEditedMessages
        self.hideMessageTypingAction = hideMessageTypingAction
        self.saveSecretImages = saveSecretImages
        self.allowSecretScreenshots = allowSecretScreenshots
        self.allowSecretDownload = allowSecretDownload
        
        self.showUserId = showUserId
        self.showGroupsId = showGroupsId
        self.showChannelsId = showChannelsId
        
        self.disableAds = disableAds
        self.hideSimilarChannels = hideSimilarChannels
        self.showSecondsInMessages = showSecondsInMessages
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.forceAllowCopy = (try container.decode(Int32.self, forKey: "faCopy")) != 0
        self.disableMarkingAsConsumed = (try container.decode(Int32.self, forKey: "dmaConsumed")) != 0
        self.saveDeletedMessages = (try container.decode(Int32.self, forKey: "sdMessages")) != 0
        self.saveEditedMessages = (try container.decodeIfPresent(Int32.self, forKey: "seMessages")) ?? 0 != 0
        self.hideMessageTypingAction = (try container.decode(Int32.self, forKey: "hmaTyping")) != 0
        self.saveSecretImages = (try container.decode(Int32.self, forKey: "ssImages")) != 0
        self.allowSecretScreenshots = (try container.decode(Int32.self, forKey: "ssScreenshots")) != 0
        self.allowSecretDownload = (try container.decode(Int32.self, forKey: "ssDownload")) != 0
        
        self.showUserId = (try container.decode(Int32.self, forKey: "siUser")) != 0
        self.showGroupsId = (try container.decode(Int32.self, forKey: "siGroup")) != 0
        self.showChannelsId = (try container.decode(Int32.self, forKey: "siChannel")) != 0
        
        self.disableAds = (try container.decodeIfPresent(Int32.self, forKey: "dAds")) != 0
        self.hideSimilarChannels = (try container.decodeIfPresent(Int32.self, forKey: "hSChannels")) ?? 0 != 0
        self.showSecondsInMessages = (try container.decodeIfPresent(Int32.self, forKey: "sSeconds")) ?? 0 != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.forceAllowCopy ? 1 : 0) as Int32, forKey: "faCopy")
        try container.encode((self.disableMarkingAsConsumed ? 1 : 0) as Int32, forKey: "dmaConsumed")
        try container.encode((self.saveDeletedMessages ? 1 : 0) as Int32, forKey: "sdMessages")
        try container.encode((self.saveEditedMessages ? 1 : 0) as Int32, forKey: "seMessages")
        try container.encode((self.hideMessageTypingAction ? 1 : 0) as Int32, forKey: "hmaTyping")
        try container.encode((self.saveSecretImages ? 1 : 0) as Int32, forKey: "ssImages")
        try container.encode((self.allowSecretScreenshots ? 1 : 0) as Int32, forKey: "ssScreenshots")
        try container.encode((self.allowSecretDownload ? 1 : 0) as Int32, forKey: "ssDownload")
        
        try container.encode((self.showUserId ? 1 : 0) as Int32, forKey: "siUser")
        try container.encode((self.showGroupsId ? 1 : 0) as Int32, forKey: "siGroup")
        try container.encode((self.showChannelsId ? 1 : 0) as Int32, forKey: "siChannel")
        
        try container.encode((self.disableAds ? 1 : 0) as Int32, forKey: "dAds")
        try container.encode((self.hideSimilarChannels ? 1 : 0) as Int32, forKey: "hSChannels")
        try container.encode((self.showSecondsInMessages ? 1 : 0) as Int32, forKey: "sSeconds")
    }
}

public struct MolteagramStatusesSettings: Codable, Equatable, MolteagramStatusesSettingsStruct {
    public var doNotReadStories: Bool
    public var doNotReadMessages: Bool
    public var doNotSendOnline: Bool
    public var doNotSendTypingAction: Bool
    public var doNotSendChooseStickerAction: Bool
    public var doNotSendEmojiInteractionSeen: Bool
    public var doNotSendGamePlayAction: Bool
    public var doNotSendRecordAudioAction: Bool
    public var doNotSendRecordRoundAction: Bool
    public var doNotSendRecordVideoAction: Bool
    public var doNotSendUploadAudioAction: Bool
    public var doNotSendUploadDocumentAction: Bool
    public var doNotSendUploadPhotoAction: Bool
    public var doNotSendUploadRoundAction: Bool
    public var doNotSendUploadVideoAction: Bool
    public var doNotSendSpeakingInGroupCallAction: Bool
    
    public static var defaultSettings: MolteagramStatusesSettings {
        return MolteagramStatusesSettings(doNotReadStories: false, doNotReadMessages: false, doNotSendOnline: false, doNotSendTypingAction: false, doNotSendChooseStickerAction: false, doNotSendEmojiInteractionSeen: false,
                                  doNotSendGamePlayAction: false, doNotSendRecordAudioAction: false, doNotSendRecordRoundAction: false, doNotSendRecordVideoAction: false, doNotSendUploadAudioAction: false,
                                  doNotSendUploadDocumentAction: false, doNotSendUploadPhotoAction: false, doNotSendUploadRoundAction: false, doNotSendUploadVideoAction: false, doNotSendSpeakingInGroupCallAction: false)
    }
    
    public init(doNotReadStories: Bool, doNotReadMessages: Bool, doNotSendOnline: Bool, doNotSendTypingAction: Bool, doNotSendChooseStickerAction: Bool, doNotSendEmojiInteractionSeen: Bool,
                doNotSendGamePlayAction: Bool, doNotSendRecordAudioAction: Bool, doNotSendRecordRoundAction: Bool, doNotSendRecordVideoAction: Bool, doNotSendUploadAudioAction: Bool,
                doNotSendUploadDocumentAction: Bool, doNotSendUploadPhotoAction: Bool, doNotSendUploadRoundAction: Bool, doNotSendUploadVideoAction: Bool, doNotSendSpeakingInGroupCallAction: Bool) {
        self.doNotReadStories = doNotReadStories
        self.doNotReadMessages = doNotReadMessages
        self.doNotSendOnline = doNotSendOnline
        self.doNotSendTypingAction = doNotSendTypingAction
        self.doNotSendChooseStickerAction = doNotSendChooseStickerAction
        self.doNotSendEmojiInteractionSeen = doNotSendEmojiInteractionSeen
        self.doNotSendGamePlayAction = doNotSendGamePlayAction
        self.doNotSendRecordAudioAction = doNotSendRecordAudioAction
        self.doNotSendRecordRoundAction = doNotSendRecordRoundAction
        self.doNotSendRecordVideoAction = doNotSendRecordVideoAction
        self.doNotSendUploadAudioAction = doNotSendUploadAudioAction
        self.doNotSendUploadDocumentAction = doNotSendUploadDocumentAction
        self.doNotSendUploadPhotoAction = doNotSendUploadPhotoAction
        self.doNotSendUploadRoundAction = doNotSendUploadRoundAction
        self.doNotSendUploadVideoAction = doNotSendUploadVideoAction
        self.doNotSendSpeakingInGroupCallAction = doNotSendSpeakingInGroupCallAction
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.doNotReadStories = (try container.decode(Int32.self, forKey: "dnrStories")) != 0
        self.doNotReadMessages = (try container.decode(Int32.self, forKey: "dnrMessages")) != 0
        self.doNotSendOnline = (try container.decode(Int32.self, forKey: "dnsOnline")) != 0
        self.doNotSendTypingAction = (try container.decode(Int32.self, forKey: "dnsTyping")) != 0
        self.doNotSendChooseStickerAction = (try container.decode(Int32.self, forKey: "dnsSticker")) != 0
        self.doNotSendEmojiInteractionSeen = (try container.decode(Int32.self, forKey: "dnsEmoji")) != 0
        self.doNotSendGamePlayAction = (try container.decode(Int32.self, forKey: "dnsGame")) != 0
        self.doNotSendRecordAudioAction = (try container.decode(Int32.self, forKey: "dnsrAudio")) != 0
        self.doNotSendRecordRoundAction = (try container.decode(Int32.self, forKey: "dnsrRound")) != 0
        self.doNotSendRecordVideoAction = (try container.decode(Int32.self, forKey: "dnsrVideo")) != 0
        self.doNotSendUploadAudioAction = (try container.decode(Int32.self, forKey: "dnsuAudio")) != 0
        self.doNotSendUploadDocumentAction = (try container.decode(Int32.self, forKey: "dnsuDoc")) != 0
        self.doNotSendUploadPhotoAction = (try container.decode(Int32.self, forKey: "dnsuPhoto")) != 0
        self.doNotSendUploadRoundAction = (try container.decode(Int32.self, forKey: "dnsuRound")) != 0
        self.doNotSendUploadVideoAction = (try container.decode(Int32.self, forKey: "dnsuVideo")) != 0
        self.doNotSendSpeakingInGroupCallAction = (try container.decode(Int32.self, forKey: "dnsSpeak")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.doNotReadStories ? 1 : 0) as Int32, forKey: "dnrStories")
        try container.encode((self.doNotReadMessages ? 1 : 0) as Int32, forKey: "dnrMessages")
        try container.encode((self.doNotSendOnline ? 1 : 0) as Int32, forKey: "dnsOnline")
        try container.encode((self.doNotSendTypingAction ? 1 : 0) as Int32, forKey: "dnsTyping")
        try container.encode((self.doNotSendChooseStickerAction ? 1 : 0) as Int32, forKey: "dnsSticker")
        try container.encode((self.doNotSendEmojiInteractionSeen ? 1 : 0) as Int32, forKey: "dnsEmoji")
        try container.encode((self.doNotSendGamePlayAction ? 1 : 0) as Int32, forKey: "dnsGame")
        try container.encode((self.doNotSendRecordAudioAction ? 1 : 0) as Int32, forKey: "dnsrAudio")
        try container.encode((self.doNotSendRecordRoundAction ? 1 : 0) as Int32, forKey: "dnsrRound")
        try container.encode((self.doNotSendRecordVideoAction ? 1 : 0) as Int32, forKey: "dnsrVideo")
        try container.encode((self.doNotSendUploadAudioAction ? 1 : 0) as Int32, forKey: "dnsuAudio")
        try container.encode((self.doNotSendUploadDocumentAction ? 1 : 0) as Int32, forKey: "dnsuDoc")
        try container.encode((self.doNotSendUploadPhotoAction ? 1 : 0) as Int32, forKey: "dnsuPhoto")
        try container.encode((self.doNotSendUploadRoundAction ? 1 : 0) as Int32, forKey: "dnsuRound")
        try container.encode((self.doNotSendUploadVideoAction ? 1 : 0) as Int32, forKey: "dnsuVideo")
        try container.encode((self.doNotSendSpeakingInGroupCallAction ? 1 : 0) as Int32, forKey: "dnsSpeak")
    }
}

public func updateMolteagramStatusesSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MolteagramStatusesSettings) -> MolteagramStatusesSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(MolteagramSpecificSharedDataKeys.molteagramStatusesSettings, { entry in
            let currentSettings: MolteagramStatusesSettings
            if let entry = entry?.get(MolteagramStatusesSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MolteagramStatusesSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}

public func updateMolteagramSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MolteagramSettings) -> MolteagramSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(MolteagramSpecificSharedDataKeys.molteagramSettings, { entry in
            let currentSettings: MolteagramSettings
            if let entry = entry?.get(MolteagramSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = MolteagramSettings.defaultSettings
            }
            let updatedSettings = f(currentSettings)
            if let bundleId = Bundle.main.bundleIdentifier {
                if let defaults = UserDefaults(suiteName: "group.\(bundleId)") {
                    defaults.set(updatedSettings.saveDeletedMessages, forKey: "Molteagram_saveDeletedMessages")
                    defaults.set(updatedSettings.saveEditedMessages, forKey: "Molteagram_saveEditedMessages")
                }
            }
            return PreferencesEntry(updatedSettings)
        })
    }
}
