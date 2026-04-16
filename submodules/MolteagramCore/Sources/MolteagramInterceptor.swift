import Foundation
import SwiftSignalKit

public protocol MolteagramSettingsStruct {
    var forceAllowCopy: Bool { get set }
    var disableMarkingAsConsumed: Bool { get set }
    var saveDeletedMessages: Bool { get set }
    var saveEditedMessages: Bool { get set }
    var hideMessageTypingAction: Bool { get set }
    var saveSecretImages: Bool { get set }
    var allowSecretScreenshots: Bool { get set }
    var allowSecretDownload: Bool { get set }
    
    var showUserId: Bool { get set }
    var showGroupsId: Bool { get set }
    var showChannelsId: Bool { get set }
    
    var disableAds: Bool { get set }
    var hideSimilarChannels: Bool { get set }
    var showSecondsInMessages: Bool { get set }
}

private class MolteagramSettingsImpl: MolteagramSettingsStruct {
    public var forceAllowCopy = false
    public var disableMarkingAsConsumed = false
    public var saveDeletedMessages: Bool = false
    public var saveEditedMessages: Bool = false
    public var hideMessageTypingAction = false
    public var saveSecretImages = false
    public var allowSecretScreenshots = false
    public var allowSecretDownload = false
    
    public var showUserId = false
    public var showGroupsId = false
    public var showChannelsId = false
    
    public var disableAds = false
    public var hideSimilarChannels = false
    public var showSecondsInMessages = false
}

public protocol MolteagramStatusesSettingsStruct {
    var doNotReadStories: Bool { get set }
    var doNotReadMessages: Bool { get set }
    var doNotSendOnline: Bool { get set }
    var doNotSendTypingAction: Bool { get set }
    var doNotSendChooseStickerAction: Bool { get set }
    var doNotSendEmojiInteractionSeen: Bool { get set }
    var doNotSendGamePlayAction: Bool { get set }
    var doNotSendRecordAudioAction: Bool { get set }
    var doNotSendRecordRoundAction: Bool { get set }
    var doNotSendRecordVideoAction: Bool { get set }
    var doNotSendUploadAudioAction: Bool { get set }
    var doNotSendUploadDocumentAction: Bool { get set }
    var doNotSendUploadPhotoAction: Bool { get set }
    var doNotSendUploadRoundAction: Bool { get set }
    var doNotSendUploadVideoAction: Bool { get set }
    var doNotSendSpeakingInGroupCallAction: Bool { get set }
}

private class MolteagramStatusesSettingsImpl: MolteagramStatusesSettingsStruct {
    public var doNotReadStories = false
    public var doNotReadMessages = false
    public var doNotSendOnline = false
    public var doNotSendTypingAction = false
    public var doNotSendChooseStickerAction = false
    public var doNotSendEmojiInteractionSeen = false
    public var doNotSendGamePlayAction = false
    public var doNotSendRecordAudioAction = false
    public var doNotSendRecordRoundAction = false
    public var doNotSendRecordVideoAction = false
    public var doNotSendUploadAudioAction = false
    public var doNotSendUploadDocumentAction = false
    public var doNotSendUploadPhotoAction = false
    public var doNotSendUploadRoundAction = false
    public var doNotSendUploadVideoAction = false
    public var doNotSendSpeakingInGroupCallAction = false
}

public protocol GlobalMolteagramStateStruct {
    static var shared: Self { get }
    associatedtype Settings: MolteagramSettingsStruct
    var current: Settings { get set }
    associatedtype StatusesSettings: MolteagramStatusesSettingsStruct
    var currentStatuses: StatusesSettings { get set }
    var performOfflinePing: (() -> Void)? { get set }
    func requestDelayedOfflinePing()
    var openDeletedMessages: ((Int64) -> Void)? { get set }
    var settingsSignal: Signal<Settings, NoError> { get }
    var typeErasedSettingsSignal: Signal<MolteagramSettingsStruct, NoError> { get }
}

private final class GlobalMolteagramStateImpl: GlobalMolteagramStateStruct {
    public static var shared = GlobalMolteagramStateImpl()
    public var current = MolteagramSettingsImpl()
    public var currentStatuses = MolteagramStatusesSettingsImpl()
    public var performOfflinePing: (() -> Void)?
    public var openDeletedMessages: ((Int64) -> Void)?
    public func requestDelayedOfflinePing() {}
    public var settingsSignal: Signal<MolteagramSettingsImpl, NoError> {
        return .complete()
    }
    public var typeErasedSettingsSignal: Signal<MolteagramSettingsStruct, NoError> {
        return self.settingsSignal |> map { $0 as MolteagramSettingsStruct }
    }
}

public struct MolteagramInterceptor {
    public static var shared: any GlobalMolteagramStateStruct = GlobalMolteagramStateImpl()
}
