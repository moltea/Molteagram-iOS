import Foundation
import TelegramApi
import UIKit
import Display
import MolteagramCore
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import ItemListUI
import SettingsUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import NotificationSoundSelectionUI
import TelegramStringFormatting
import NotificationPeerExceptionController

private final class MolteagramStatusesSettingsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    
    let updateDoNotReadStories: (Bool) -> Void
    let updateDoNotReadMessages: (Bool) -> Void
    let updateDoNotSendOnline: (Bool) -> Void
    let updateDoNotSendTypingAction: (Bool) -> Void
    let updateDoNotSendChooseStickerAction: (Bool) -> Void
    let updateDoNotSendEmojiInteractionSeen: (Bool) -> Void
    let updateDoNotSendGamePlayAction: (Bool) -> Void
    let updateDoNotSendRecordAudioAction: (Bool) -> Void
    let updateDoNotSendRecordRoundAction: (Bool) -> Void
    let updateDoNotSendRecordVideoAction: (Bool) -> Void
    let updateDoNotSendUploadAudioAction: (Bool) -> Void
    let updateDoNotSendUploadDocumentAction: (Bool) -> Void
    let updateDoNotSendUploadPhotoAction: (Bool) -> Void
    let updateDoNotSendUploadRoundAction: (Bool) -> Void
    let updateDoNotSendUploadVideoAction: (Bool) -> Void
    let updateDoNotSendSpeakingInGroupCallAction: (Bool) -> Void
    
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping(ViewController)->Void,
         updateDoNotReadStories: @escaping (Bool) -> Void, updateDoNotReadMessages: @escaping (Bool) -> Void, updateDoNotSendOnline: @escaping (Bool) -> Void,
         updateDoNotSendTypingAction: @escaping (Bool) -> Void, updateDoNotSendChooseStickerAction: @escaping (Bool) -> Void,updateDoNotSendEmojiInteractionSeen: @escaping (Bool) -> Void,
         updateDoNotSendGamePlayAction: @escaping (Bool) -> Void, updateDoNotSendRecordAudioAction: @escaping (Bool) -> Void, updateDoNotSendRecordRoundAction: @escaping (Bool) -> Void,
         updateDoNotSendRecordVideoAction: @escaping (Bool) -> Void, updateDoNotSendUploadAudioAction: @escaping (Bool) -> Void, updateDoNotSendUploadDocumentAction: @escaping (Bool) -> Void,
         updateDoNotSendUploadPhotoAction: @escaping (Bool) -> Void, updateDoNotSendUploadRoundAction: @escaping (Bool) -> Void, updateDoNotSendUploadVideoAction: @escaping (Bool) -> Void,
         updateDoNotSendSpeakingInGroupCallAction: @escaping (Bool) -> Void,
    ) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.updateDoNotReadStories = updateDoNotReadStories
        self.updateDoNotReadMessages = updateDoNotReadMessages
        self.updateDoNotSendOnline = updateDoNotSendOnline
        self.updateDoNotSendTypingAction = updateDoNotSendTypingAction
        self.updateDoNotSendChooseStickerAction = updateDoNotSendChooseStickerAction
        self.updateDoNotSendEmojiInteractionSeen = updateDoNotSendEmojiInteractionSeen
        self.updateDoNotSendGamePlayAction = updateDoNotSendGamePlayAction
        self.updateDoNotSendRecordAudioAction = updateDoNotSendRecordAudioAction
        self.updateDoNotSendRecordRoundAction = updateDoNotSendRecordRoundAction
        self.updateDoNotSendRecordVideoAction = updateDoNotSendRecordVideoAction
        self.updateDoNotSendUploadAudioAction = updateDoNotSendUploadAudioAction
        self.updateDoNotSendUploadDocumentAction = updateDoNotSendUploadDocumentAction
        self.updateDoNotSendUploadPhotoAction = updateDoNotSendUploadPhotoAction
        self.updateDoNotSendUploadRoundAction = updateDoNotSendUploadRoundAction
        self.updateDoNotSendUploadVideoAction = updateDoNotSendUploadVideoAction
        self.updateDoNotSendSpeakingInGroupCallAction = updateDoNotSendSpeakingInGroupCallAction
    }
}

private enum MolteagramStatusesSettingsSection: Int32 {
    case basicStatuses
    case records
    case uploads
    case misc
}

public enum MolteagramStatusesSettingsEntryTag: ItemListItemTag {
    case doNotReadStories
    case doNotReadMessages
    case doNotSendOnline
    case doNotSendTypingAction
    case doNotSendChooseStickerAction
    case doNotSendEmojiInteractionSeen
    case doNotSendGamePlayAction
    case doNotSendRecordAudioAction
    case doNotSendRecordRoundAction
    case doNotSendRecordVideoAction
    case doNotSendUploadAudioAction
    case doNotSendUploadDocumentAction
    case doNotSendUploadPhotoAction
    case doNotSendUploadRoundAction
    case doNotSendUploadVideoAction
    case doNotSendSpeakingInGroupCallAction
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? MolteagramStatusesSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum MolteagramStatusesSettingsEntry: ItemListNodeEntry {
    case basicStatusesHeader(PresentationTheme, String)
    case doNotReadStories(PresentationTheme, String, Bool)
    case doNotReadMessages(PresentationTheme, String, Bool)
    case doNotSendOnline(PresentationTheme, String, Bool)
    case doNotSendTypingAction(PresentationTheme, String, Bool)
    
    case recordsHeader(PresentationTheme, String)
    case doNotSendRecordAudioAction(PresentationTheme, String, Bool)
    case doNotSendRecordRoundAction(PresentationTheme, String, Bool)
    case doNotSendRecordVideoAction(PresentationTheme, String, Bool)
    
    case uploadsHeader(PresentationTheme, String)
    case doNotSendUploadAudioAction(PresentationTheme, String, Bool)
    case doNotSendUploadDocumentAction(PresentationTheme, String, Bool)
    case doNotSendUploadPhotoAction(PresentationTheme, String, Bool)
    case doNotSendUploadRoundAction(PresentationTheme, String, Bool)
    case doNotSendUploadVideoAction(PresentationTheme, String, Bool)
    
    case miscHeader(PresentationTheme, String)
    case doNotSendChooseStickerAction(PresentationTheme, String, Bool)
    case doNotSendEmojiInteractionSeen(PresentationTheme, String, Bool)
    case doNotSendGamePlayAction(PresentationTheme, String, Bool)
    case doNotSendSpeakingInGroupCallAction(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .basicStatusesHeader, .doNotReadStories, .doNotReadMessages, .doNotSendOnline, .doNotSendTypingAction:
                return MolteagramStatusesSettingsSection.basicStatuses.rawValue
            case .recordsHeader, .doNotSendRecordAudioAction, .doNotSendRecordRoundAction, .doNotSendRecordVideoAction:
                return MolteagramStatusesSettingsSection.records.rawValue
            case .uploadsHeader, .doNotSendUploadAudioAction, .doNotSendUploadDocumentAction, .doNotSendUploadPhotoAction, .doNotSendUploadRoundAction, .doNotSendUploadVideoAction:
                return MolteagramStatusesSettingsSection.uploads.rawValue
            case .miscHeader, .doNotSendChooseStickerAction, .doNotSendEmojiInteractionSeen, .doNotSendGamePlayAction, .doNotSendSpeakingInGroupCallAction:
                return MolteagramStatusesSettingsSection.misc.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .basicStatusesHeader:
                return 1
            case .doNotReadStories:
                return 2
            case .doNotReadMessages:
                return 3
            case .doNotSendOnline:
                return 4
            case .doNotSendTypingAction:
                return 5
            case .recordsHeader:
                return 6
            case .doNotSendRecordAudioAction:
                return 7
            case .doNotSendRecordRoundAction:
                return 8
            case .doNotSendRecordVideoAction:
                return 9
            case .uploadsHeader:
                return 10
            case .doNotSendUploadAudioAction:
                return 11
            case .doNotSendUploadDocumentAction:
                return 12
            case .doNotSendUploadPhotoAction:
                return 13
            case .doNotSendUploadRoundAction:
                return 14
            case .doNotSendUploadVideoAction:
                return 15
            case .miscHeader:
                return 16
            case .doNotSendChooseStickerAction:
                return 17
            case .doNotSendEmojiInteractionSeen:
                return 18
            case .doNotSendGamePlayAction:
                return 19
            case .doNotSendSpeakingInGroupCallAction:
                return 20
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .doNotReadStories:
                return MolteagramStatusesSettingsEntryTag.doNotReadStories
            case .doNotReadMessages:
                return MolteagramStatusesSettingsEntryTag.doNotReadMessages
            case .doNotSendOnline:
                return MolteagramStatusesSettingsEntryTag.doNotSendOnline
            case .doNotSendTypingAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendTypingAction
            case .doNotSendRecordAudioAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendRecordAudioAction
            case .doNotSendRecordRoundAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendRecordRoundAction
            case .doNotSendRecordVideoAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendRecordVideoAction
            case .doNotSendUploadAudioAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendUploadAudioAction
            case .doNotSendUploadDocumentAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendUploadDocumentAction
            case .doNotSendUploadPhotoAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendUploadPhotoAction
            case .doNotSendUploadRoundAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendUploadRoundAction
            case .doNotSendUploadVideoAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendUploadVideoAction
            case .doNotSendChooseStickerAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendChooseStickerAction
            case .doNotSendEmojiInteractionSeen:
                return MolteagramStatusesSettingsEntryTag.doNotSendEmojiInteractionSeen
            case .doNotSendGamePlayAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendGamePlayAction
            case .doNotSendSpeakingInGroupCallAction:
                return MolteagramStatusesSettingsEntryTag.doNotSendSpeakingInGroupCallAction
            default:
                return nil
        }
    }
    
    static func ==(lhs: MolteagramStatusesSettingsEntry, rhs: MolteagramStatusesSettingsEntry) -> Bool {
        switch lhs {
            case let .basicStatusesHeader(lhsTheme, lhsText):
                if case let .basicStatusesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .doNotReadStories(lhsTheme, lhsText, lhsValue):
                if case let .doNotReadStories(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotReadMessages(lhsTheme, lhsText, lhsValue):
                if case let .doNotReadMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendOnline(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendOnline(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendTypingAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendTypingAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
                
            case let .recordsHeader(lhsTheme, lhsText):
                if case let .recordsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .doNotSendRecordAudioAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendRecordAudioAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
                
            case let .doNotSendRecordRoundAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendRecordRoundAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
                
            case let .doNotSendRecordVideoAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendRecordVideoAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
                
            case let .uploadsHeader(lhsTheme, lhsText):
                if case let .uploadsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .doNotSendUploadAudioAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendUploadAudioAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendUploadDocumentAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendUploadDocumentAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendUploadPhotoAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendUploadPhotoAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendUploadRoundAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendUploadRoundAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendUploadVideoAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendUploadVideoAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
               
            case let .miscHeader(lhsTheme, lhsText):
                if case let .miscHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .doNotSendChooseStickerAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendChooseStickerAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendEmojiInteractionSeen(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendEmojiInteractionSeen(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendGamePlayAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendGamePlayAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .doNotSendSpeakingInGroupCallAction(lhsTheme, lhsText, lhsValue):
                if case let .doNotSendSpeakingInGroupCallAction(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: MolteagramStatusesSettingsEntry, rhs: MolteagramStatusesSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MolteagramStatusesSettingsArguments
        switch self {
            case let .basicStatusesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .doNotReadStories(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotReadStories(updatedValue)
                }, tag: self.tag)
            case let .doNotReadMessages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotReadMessages(updatedValue)
                }, tag: self.tag)
            case let .doNotSendOnline(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendOnline(updatedValue)
                }, tag: self.tag)
            case let .doNotSendTypingAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendTypingAction(updatedValue)
                }, tag: self.tag)
            
            case let .recordsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .doNotSendRecordAudioAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendRecordAudioAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendRecordRoundAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendRecordRoundAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendRecordVideoAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendRecordVideoAction(updatedValue)
                }, tag: self.tag)
            
            case let .uploadsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .doNotSendUploadAudioAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendUploadAudioAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendUploadDocumentAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendUploadDocumentAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendUploadPhotoAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendUploadPhotoAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendUploadRoundAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendUploadRoundAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendUploadVideoAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendUploadVideoAction(updatedValue)
                }, tag: self.tag)
            
            case let .miscHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .doNotSendChooseStickerAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendChooseStickerAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendEmojiInteractionSeen(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendEmojiInteractionSeen(updatedValue)
                }, tag: self.tag)
            case let .doNotSendGamePlayAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendGamePlayAction(updatedValue)
                }, tag: self.tag)
            case let .doNotSendSpeakingInGroupCallAction(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDoNotSendSpeakingInGroupCallAction(updatedValue)
                }, tag: self.tag)
        }
    }
}

private func molteagramStatusesSettingsEntries(molteagramStatusesSettings: MolteagramStatusesSettings, presentationData: PresentationData) -> [MolteagramStatusesSettingsEntry] {
    var entries: [MolteagramStatusesSettingsEntry] = []
    
    let lang = presentationData.strings.primaryComponent.languageCode
    entries.append(.basicStatusesHeader(presentationData.theme, MolteagramStrings.get("Molteagram.BasicStatusesHeader", languageCode: lang)))
    entries.append(.doNotReadStories(presentationData.theme, MolteagramStrings.get("Molteagram.DontViewStories", languageCode: lang), molteagramStatusesSettings.doNotReadStories))
    entries.append(.doNotReadMessages(presentationData.theme, MolteagramStrings.get("Molteagram.DontReadMessages", languageCode: lang), molteagramStatusesSettings.doNotReadMessages))
    entries.append(.doNotSendOnline(presentationData.theme, MolteagramStrings.get("Molteagram.ForceOffline", languageCode: lang), molteagramStatusesSettings.doNotSendOnline))
    entries.append(.doNotSendTypingAction(presentationData.theme, MolteagramStrings.get("Molteagram.DontSendTyping", languageCode: lang), molteagramStatusesSettings.doNotSendTypingAction))
    
    entries.append(.recordsHeader(presentationData.theme, MolteagramStrings.get("Molteagram.RecordsHeader", languageCode: lang)))
    entries.append(.doNotSendRecordAudioAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableRecordingAudio", languageCode: lang), molteagramStatusesSettings.doNotSendRecordAudioAction))
    entries.append(.doNotSendRecordRoundAction(presentationData.theme,MolteagramStrings.get("Molteagram.DisableRecordingRound", languageCode: lang), molteagramStatusesSettings.doNotSendRecordRoundAction))
    entries.append(.doNotSendRecordVideoAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableRecordingVideo", languageCode: lang), molteagramStatusesSettings.doNotSendRecordVideoAction))
    
    entries.append(.uploadsHeader(presentationData.theme, MolteagramStrings.get("Molteagram.UploadsHeader", languageCode: lang)))
    entries.append(.doNotSendUploadAudioAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableUploadingAudio", languageCode: lang), molteagramStatusesSettings.doNotSendUploadAudioAction))
    entries.append(.doNotSendUploadDocumentAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableUploadingDocument", languageCode: lang), molteagramStatusesSettings.doNotSendUploadDocumentAction))
    entries.append(.doNotSendUploadPhotoAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableUploadingPhoto", languageCode: lang), molteagramStatusesSettings.doNotSendUploadPhotoAction))
    entries.append(.doNotSendUploadRoundAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableUploadingRound", languageCode: lang), molteagramStatusesSettings.doNotSendUploadRoundAction))
    entries.append(.doNotSendUploadVideoAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableUploadingVideo", languageCode: lang), molteagramStatusesSettings.doNotSendUploadVideoAction))
    
    entries.append(.miscHeader(presentationData.theme, MolteagramStrings.get("Molteagram.MiscHeader", languageCode: lang)))
    entries.append(.doNotSendChooseStickerAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableChoosingSticker", languageCode: lang), molteagramStatusesSettings.doNotSendChooseStickerAction))
    entries.append(.doNotSendEmojiInteractionSeen(presentationData.theme, MolteagramStrings.get("Molteagram.DisableWatchingAtEmoji", languageCode: lang), molteagramStatusesSettings.doNotSendEmojiInteractionSeen))
    entries.append(.doNotSendGamePlayAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisablePlayingGame", languageCode: lang), molteagramStatusesSettings.doNotSendGamePlayAction))
    entries.append(.doNotSendSpeakingInGroupCallAction(presentationData.theme, MolteagramStrings.get("Molteagram.DisableSpeaking", languageCode: lang), molteagramStatusesSettings.doNotSendSpeakingInGroupCallAction))
    
    return entries
}

public func molteagramStatusesSettingsController(context: AccountContext, exceptionsList: NotificationExceptionsList?, focusOnItemTag: MolteagramStatusesSettingsEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode, stories: NotificationExceptionMode)> = Promise()
    
    
    let arguments = MolteagramStatusesSettingsArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, updateDoNotReadStories: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotReadStories = value
            return settings
        }).start()
    }, updateDoNotReadMessages: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotReadMessages = value
            return settings
        }).start()
    }, updateDoNotSendOnline: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendOnline = value
            return settings
        }).start()
        
        if value == true {
            let _ = (context.account.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }).start()
        }
    }, updateDoNotSendTypingAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendTypingAction = value
            return settings
        }).start()
    }, updateDoNotSendChooseStickerAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendChooseStickerAction = value
            return settings
        }).start()
    }, updateDoNotSendEmojiInteractionSeen: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendEmojiInteractionSeen = value
            return settings
        }).start()
    }, updateDoNotSendGamePlayAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendGamePlayAction = value
            return settings
        }).start()
    }, updateDoNotSendRecordAudioAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendRecordAudioAction = value
            return settings
        }).start()
    }, updateDoNotSendRecordRoundAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendRecordRoundAction = value
            return settings
        }).start()
    }, updateDoNotSendRecordVideoAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendRecordVideoAction = value
            return settings
        }).start()
    }, updateDoNotSendUploadAudioAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendUploadAudioAction = value
            return settings
        }).start()
    }, updateDoNotSendUploadDocumentAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendUploadDocumentAction = value
            return settings
        }).start()
    }, updateDoNotSendUploadPhotoAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendUploadPhotoAction = value
            return settings
        }).start()
    }, updateDoNotSendUploadRoundAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendUploadRoundAction = value
            return settings
        }).start()
    }, updateDoNotSendUploadVideoAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendUploadVideoAction = value
            return settings
        }).start()
    }, updateDoNotSendSpeakingInGroupCallAction: { value in
        let _ = updateMolteagramStatusesSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.doNotSendSpeakingInGroupCallAction = value
            return settings
        }).start()
    })
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [MolteagramSpecificSharedDataKeys.molteagramStatusesSettings])
//    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    
    let exceptionsSignal = Signal<NotificationExceptionsList?, NoError>.single(exceptionsList) |> then(context.engine.peers.notificationExceptionsList() |> map(Optional.init))
    
    let defaultStorySettings = PeerStoryNotificationSettings.default
    
    notificationExceptions.set(exceptionsSignal |> map { list -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels: [PeerId : NotificationExceptionWrapper] = [:]
        var stories: [PeerId : NotificationExceptionWrapper] = [:]
        if let list = list {
            for (key, value) in list.settings {
                if let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != context.account.peerId {
                    if value.storySettings != defaultStorySettings {
                        stories[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                    }
                    
                    switch value.muteState {
                    case .default:
                        switch value.messageSound {
                        case .default:
                            break
                        default:
                            switch key.namespace {
                            case Namespaces.Peer.CloudUser:
                                users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                            default:
                                if case let .channel(peer) = peer, case .broadcast = peer.info {
                                    channels[key] = NotificationExceptionWrapper(settings: value, peer: .channel(peer))
                                } else {
                                    groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                }
                            }
                        }
                    default:
                        switch key.namespace {
                        case Namespaces.Peer.CloudUser:
                            users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                        default:
                            if case let .channel(peer) = peer, case .broadcast = peer.info {
                                channels[key] = NotificationExceptionWrapper(settings: value, peer: .channel(peer))
                            } else {
                                groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                            }
                        }
                    }
                }
            }
        }
        
        return (.users(users), .groups(groups), .channels(channels), .stories(stories))
    })
    
    let notificationsWarningSuppressed = Promise<Bool>(true)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsWarningSuppressed.set(.single(true)
        |> then(
            context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
            |> map { noticeView -> Bool in
                let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 {
                    return true
                } else {
                    return false
                }
            }))
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, sharedData)
        |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let molteagramStatusesSettings: MolteagramStatusesSettings
            if let settings = sharedData.entries[MolteagramSpecificSharedDataKeys.molteagramStatusesSettings]?.get(MolteagramStatusesSettings.self) {
                molteagramStatusesSettings = settings
            } else {
                molteagramStatusesSettings = MolteagramStatusesSettings.defaultSettings
            }
            
            let entries = molteagramStatusesSettingsEntries(molteagramStatusesSettings: molteagramStatusesSettings, presentationData: presentationData)
            
            var index = 0
            var scrollToItem: ListViewScrollToItem?
            if let focusOnItemTag = focusOnItemTag {
                for entry in entries {
                    if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
                        scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
                    }
                    index += 1
                }
            }
            
            let lang = presentationData.strings.primaryComponent.languageCode
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(MolteagramStrings.get("Molteagram.StatusesTitle", languageCode: lang)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: focusOnItemTag, initialScrollToItem: scrollToItem)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    if let focusOnItemTag {
        var didFocusOnItem = false
        controller.afterTransactionCompleted = { [weak controller] in
            if !didFocusOnItem, let controller {
                controller.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, tag.isEqual(to: focusOnItemTag) {
                        didFocusOnItem = true
                        itemNode.displayHighlight()
                    }
                }
            }
        }
    }
    
    return controller
}
