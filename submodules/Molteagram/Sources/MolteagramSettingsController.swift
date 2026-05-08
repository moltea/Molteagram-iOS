import Foundation
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

private final class MolteagramSettingsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
        
    let openStatusesSettings: () -> Void
    let openFontsSettings: () -> Void
    
    let updateSaveDeletedMessages: (Bool) -> Void
    let updateSaveEditedMessages: (Bool) -> Void
    let updateSaveSecretImages: (Bool) -> Void
    let updateDisableMarkingAsConsumed: (Bool) -> Void
    let updateAllowSecretScreenshots: (Bool) -> Void
    let updateAllowSecretDownload: (Bool) -> Void
    
    let updateShowUserId: (Bool) -> Void
    let updateShowGroupsId: (Bool) -> Void
    let updateShowChannelsId: (Bool) -> Void
    
    let updateDisableAds: (Bool) -> Void
    let updateHideSimilarChannels: (Bool) -> Void
    let updateShowSecondsInMessages: (Bool) -> Void
    
    let updateForceAllowCopy: (Bool) -> Void
    
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping(ViewController)->Void, openStatusesSettings: @escaping () -> Void, openFontsSettings: @escaping () -> Void, updateSaveDeletedMessages: @escaping (Bool) -> Void, updateSaveEditedMessages: @escaping (Bool) -> Void, updateSaveSecretImages: @escaping (Bool) -> Void, updateDisableMarkingAsConsumed: @escaping (Bool) -> Void, updateAllowSecretScreenshots: @escaping (Bool) -> Void, updateAllowSecretDownload: @escaping (Bool) -> Void,
         updateShowUserId: @escaping (Bool) -> Void, updateShowGroupsId: @escaping (Bool) -> Void, updateShowChannelsId: @escaping (Bool) -> Void, updateDisableAds: @escaping (Bool) -> Void, updateHideSimilarChannels: @escaping (Bool) -> Void, updateShowSecondsInMessages: @escaping (Bool) -> Void, updateForceAllowCopy: @escaping (Bool) -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        
        self.openStatusesSettings = openStatusesSettings
        self.openFontsSettings = openFontsSettings
        
        self.updateSaveDeletedMessages = updateSaveDeletedMessages
        self.updateSaveEditedMessages = updateSaveEditedMessages
        self.updateSaveSecretImages = updateSaveSecretImages
        self.updateDisableMarkingAsConsumed = updateDisableMarkingAsConsumed
        self.updateAllowSecretScreenshots = updateAllowSecretScreenshots
        self.updateAllowSecretDownload = updateAllowSecretDownload
        
        self.updateShowUserId = updateShowUserId
        self.updateShowGroupsId = updateShowGroupsId
        self.updateShowChannelsId = updateShowChannelsId
        
        self.updateDisableAds = updateDisableAds
        self.updateHideSimilarChannels = updateHideSimilarChannels
        self.updateShowSecondsInMessages = updateShowSecondsInMessages
        
        self.updateForceAllowCopy = updateForceAllowCopy
    }
}

private enum MolteagramSettingsSection: Int32 {
    case categories
    case messages
    case disappearingImages
    case uiImprovements
    case misc
}

public enum MolteagramSettingsEntryTag: ItemListItemTag {
    case statusesSettings
    case fontsSettings
    
    case saveDeletedMessages
    case saveEditedMessages
    
    case saveSecretImages
    case disableMarkingAsConsumed
    case allowSecretScreenshots
    case allowSecretDownload
    
    case showUserId
    case showGroupsId
    case showChannelsId
    
    case disableAds
    case hideSimilarChannels
    case showSecondsInMessages
    
    case forceAllowCopy
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? MolteagramSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum MolteagramSettingsEntry: ItemListNodeEntry {
    case statusesSettings(PresentationTheme, String, String, String)
    case fontsSettings(PresentationTheme, String, String, String)
    
    case messagesHeader(PresentationTheme, String)
    case saveDeletedMessages(PresentationTheme, String, Bool)
    case saveEditedMessages(PresentationTheme, String, Bool)
    
    case secretImagesHeader(PresentationTheme, String)
    case saveSecretImages(PresentationTheme, String, Bool)
    case disableMarkingAsConsumed(PresentationTheme, String, Bool)
    case allowSecretScreenshots(PresentationTheme, String, Bool)
    case allowSecretDownload(PresentationTheme, String, Bool)
    
    case uiImprovementsHeader(PresentationTheme, String)
    case showUserId(PresentationTheme, String, Bool)
    case showGroupsId(PresentationTheme, String, Bool)
    case showChannelsId(PresentationTheme, String, Bool)
    case disableAds(PresentationTheme, String, Bool)
    case hideSimilarChannels(PresentationTheme, String, Bool)
    case showSecondsInMessages(PresentationTheme, String, Bool)
    
    case miscHeader(PresentationTheme, String)
    case forceAllowCopy(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .statusesSettings, .fontsSettings:
                return MolteagramSettingsSection.categories.rawValue
            case .messagesHeader, .saveDeletedMessages, .saveEditedMessages:
                return MolteagramSettingsSection.messages.rawValue
            case .secretImagesHeader, .saveSecretImages, .disableMarkingAsConsumed, .allowSecretScreenshots, .allowSecretDownload:
                return MolteagramSettingsSection.disappearingImages.rawValue
            case .uiImprovementsHeader, .showUserId, .showGroupsId, .showChannelsId, .disableAds, .hideSimilarChannels, .showSecondsInMessages:
                return MolteagramSettingsSection.uiImprovements.rawValue
            case .miscHeader, .forceAllowCopy:
                return MolteagramSettingsSection.misc.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .statusesSettings:
                return 0
            case .fontsSettings:
                return 1
            case .messagesHeader:
                return 2
            case .saveDeletedMessages:
                return 3
            case .saveEditedMessages:
                return 4
            case .secretImagesHeader:
                return 5
            case .saveSecretImages:
                return 6
            case .disableMarkingAsConsumed:
                return 7
            case .allowSecretScreenshots:
                return 8
            case .allowSecretDownload:
                return 9
            case .uiImprovementsHeader:
                return 10
            case .showUserId:
                return 11
            case .showGroupsId:
                return 12
            case .showChannelsId:
                return 13
            case .disableAds:
                return 14
            case .hideSimilarChannels:
                return 15
            case .showSecondsInMessages:
                return 16
            case .miscHeader:
                return 17
            case .forceAllowCopy:
                return 18
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .statusesSettings:
                return MolteagramSettingsEntryTag.statusesSettings
            case .fontsSettings:
                return MolteagramSettingsEntryTag.fontsSettings
            
            case .saveDeletedMessages:
                return MolteagramSettingsEntryTag.saveDeletedMessages
            case .saveEditedMessages:
                return MolteagramSettingsEntryTag.saveEditedMessages
            
            case .saveSecretImages:
                return MolteagramSettingsEntryTag.saveSecretImages
            case .disableMarkingAsConsumed:
                return MolteagramSettingsEntryTag.disableMarkingAsConsumed
            case .allowSecretScreenshots:
                return MolteagramSettingsEntryTag.allowSecretScreenshots
            case .allowSecretDownload:
                return MolteagramSettingsEntryTag.allowSecretDownload
            
            case .showUserId:
                return MolteagramSettingsEntryTag.showUserId
            case .showGroupsId:
                return MolteagramSettingsEntryTag.showGroupsId
            case .showChannelsId:
                return MolteagramSettingsEntryTag.showChannelsId
            case .disableAds:
                return MolteagramSettingsEntryTag.disableAds
            case .hideSimilarChannels:
                return MolteagramSettingsEntryTag.hideSimilarChannels
            case .showSecondsInMessages:
                return MolteagramSettingsEntryTag.showSecondsInMessages
                
            case .forceAllowCopy:
                return MolteagramSettingsEntryTag.forceAllowCopy
            default:
                return nil
        }
    }
    
    static func ==(lhs: MolteagramSettingsEntry, rhs: MolteagramSettingsEntry) -> Bool {
        switch lhs {
            case let .statusesSettings(lhsTheme, lhsTitle, lhsSubtitle, lhsLabel):
                if case let .statusesSettings(rhsTheme, rhsTitle, rhsSubtitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .fontsSettings(lhsTheme, lhsTitle, lhsSubtitle, lhsLabel):
                if case let .fontsSettings(rhsTheme, rhsTitle, rhsSubtitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .messagesHeader(lhsTheme, lhsText):
                if case let .messagesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .saveDeletedMessages(lhsTheme, lhsText, lhsValue):
                if case let .saveDeletedMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .saveEditedMessages(lhsTheme, lhsText, lhsValue):
                if case let .saveEditedMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .secretImagesHeader(lhsTheme, lhsText):
                if case let .secretImagesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .saveSecretImages(lhsTheme, lhsText, lhsValue):
                if case let .saveSecretImages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .disableMarkingAsConsumed(lhsTheme, lhsText, lhsValue):
                if case let .disableMarkingAsConsumed(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .allowSecretScreenshots(lhsTheme, lhsText, lhsValue):
                if case let .allowSecretScreenshots(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .allowSecretDownload(lhsTheme, lhsText, lhsValue):
                if case let .allowSecretDownload(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .uiImprovementsHeader(lhsTheme, lhsText):
                if case let .uiImprovementsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .showUserId(lhsTheme, lhsText, lhsValue):
                if case let .showUserId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showGroupsId(lhsTheme, lhsText, lhsValue):
                if case let .showGroupsId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showChannelsId(lhsTheme, lhsText, lhsValue):
                if case let .showChannelsId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .disableAds(lhsTheme, lhsText, lhsValue):
                if case let .disableAds(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .hideSimilarChannels(lhsTheme, lhsText, lhsValue):
                if case let .hideSimilarChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showSecondsInMessages(lhsTheme, lhsText, lhsValue):
                if case let .showSecondsInMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .forceAllowCopy(lhsTheme, lhsText, lhsValue):
                if case let .forceAllowCopy(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: MolteagramSettingsEntry, rhs: MolteagramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MolteagramSettingsArguments
        switch self {
            case let .statusesSettings(_, title, subtitle, label):
                return NotificationsCategoryItemListItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.emojiStatus, title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openStatusesSettings()
                })
            case let .fontsSettings(_, title, subtitle, label):
                return NotificationsCategoryItemListItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesSettings.fonts, title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openFontsSettings()
                })
            case let .messagesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .saveDeletedMessages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSaveDeletedMessages(updatedValue)
                }, tag: self.tag)
            case let .saveEditedMessages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSaveEditedMessages(updatedValue)
                }, tag: self.tag)
            case let .secretImagesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .saveSecretImages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSaveSecretImages(updatedValue)
                }, tag: self.tag)
            case let .disableMarkingAsConsumed(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDisableMarkingAsConsumed(updatedValue)
                }, tag: self.tag)
            case let .allowSecretScreenshots(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateAllowSecretScreenshots(updatedValue)
                }, tag: self.tag)
            case let .allowSecretDownload(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateAllowSecretDownload(updatedValue)
                }, tag: self.tag)
            case let .uiImprovementsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .showUserId(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateShowUserId(updatedValue)
                }, tag: self.tag)
            case let .showGroupsId(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateShowGroupsId(updatedValue)
                }, tag: self.tag)
            case let .showChannelsId(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateShowChannelsId(updatedValue)
                }, tag: self.tag)
            case let .disableAds(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDisableAds(updatedValue)
                }, tag: self.tag)
            case let .hideSimilarChannels(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateHideSimilarChannels(updatedValue)
                }, tag: self.tag)
            case let .showSecondsInMessages(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateShowSecondsInMessages(updatedValue)
                }, tag: self.tag)
            case let .miscHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .forceAllowCopy(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateForceAllowCopy(updatedValue)
                }, tag: self.tag)
        }
    }
}

private func molteagramSettingsEntries(molteagramSettings: MolteagramSettings, presentationData: PresentationData) -> [MolteagramSettingsEntry] {
    var entries: [MolteagramSettingsEntry] = []
    
    let lang = presentationData.strings.primaryComponent.languageCode
    entries.append(.statusesSettings(presentationData.theme, MolteagramStrings.get("Molteagram.StatusesTab", languageCode: lang), "", ""))
    entries.append(.fontsSettings(presentationData.theme, MolteagramStrings.get("Molteagram.Fonts", languageCode: lang), "", ""))
    
    entries.append(.messagesHeader(presentationData.theme, MolteagramStrings.get("Molteagram.MessagesHeader", languageCode: lang)))
    entries.append(.saveDeletedMessages(presentationData.theme, MolteagramStrings.get("Molteagram.SaveDeletedMessages", languageCode: lang), molteagramSettings.saveDeletedMessages))
    entries.append(.saveEditedMessages(presentationData.theme, MolteagramStrings.get("Molteagram.SaveEditedMessages", languageCode: lang), molteagramSettings.saveEditedMessages))
    
    entries.append(.secretImagesHeader(presentationData.theme, MolteagramStrings.get("Molteagram.DisappearingMediaHeader", languageCode: lang)))
    entries.append(.saveSecretImages(presentationData.theme, MolteagramStrings.get("Molteagram.SaveDisappearingMedia", languageCode: lang), molteagramSettings.saveSecretImages))
    entries.append(.disableMarkingAsConsumed(presentationData.theme, MolteagramStrings.get("Molteagram.MarkingAsConsumed", languageCode: lang), molteagramSettings.disableMarkingAsConsumed ? false : true))
    entries.append(.allowSecretScreenshots(presentationData.theme, MolteagramStrings.get("Molteagram.AllowSecretScreenshots", languageCode: lang), molteagramSettings.allowSecretScreenshots))
    entries.append(.allowSecretDownload(presentationData.theme, MolteagramStrings.get("Molteagram.AllowSecretDownload", languageCode: lang), molteagramSettings.allowSecretDownload))
    
    entries.append(.uiImprovementsHeader(presentationData.theme, MolteagramStrings.get("Molteagram.UiImprovementsHeader", languageCode: lang)))
    entries.append(.showUserId(presentationData.theme, MolteagramStrings.get("Molteagram.ShowUserId", languageCode: lang), molteagramSettings.showUserId))
    entries.append(.showGroupsId(presentationData.theme, MolteagramStrings.get("Molteagram.ShowGroupsId", languageCode: lang), molteagramSettings.showGroupsId))
    entries.append(.showChannelsId(presentationData.theme, MolteagramStrings.get("Molteagram.ShowChannelsId", languageCode: lang), molteagramSettings.showChannelsId))
    entries.append(.disableAds(presentationData.theme, MolteagramStrings.get("Molteagram.DisableAds", languageCode: lang), molteagramSettings.disableAds))
    entries.append(.hideSimilarChannels(presentationData.theme, MolteagramStrings.get("Molteagram.HideSimilarChannels", languageCode: lang), molteagramSettings.hideSimilarChannels))
    entries.append(.showSecondsInMessages(presentationData.theme, MolteagramStrings.get("Molteagram.ShowSecondsInMessages", languageCode: lang), molteagramSettings.showSecondsInMessages))
    
    entries.append(.miscHeader(presentationData.theme, MolteagramStrings.get("Molteagram.MiscHeader", languageCode: lang)))
    entries.append(.forceAllowCopy(presentationData.theme, MolteagramStrings.get("Molteagram.ForceAllowCopy", languageCode: lang), molteagramSettings.forceAllowCopy))
    
    return entries
}

public func molteagramSettingsController(context: AccountContext, exceptionsList: NotificationExceptionsList?, focusOnItemTag: MolteagramSettingsEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode, stories: NotificationExceptionMode)> = Promise()
    
    
    let arguments = MolteagramSettingsArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, openStatusesSettings: {
        pushControllerImpl?(molteagramStatusesSettingsController(
            context: context, exceptionsList: exceptionsList
        ))
    }, openFontsSettings: {
        pushControllerImpl?(molteagramFontsSettingsController(context: context))
    }, updateSaveDeletedMessages: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.saveDeletedMessages = value
            return settings
        }).start()
    }, updateSaveEditedMessages: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.saveEditedMessages = value
            return settings
        }).start()
    }, updateSaveSecretImages: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.saveSecretImages = value
            return settings
        }).start()
    }, updateDisableMarkingAsConsumed: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.disableMarkingAsConsumed = !value
            return settings
        }).start()
    }, updateAllowSecretScreenshots: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.allowSecretScreenshots = value
            return settings
        }).start()
    }, updateAllowSecretDownload: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.allowSecretDownload = value
            return settings
        }).start()
    }, updateShowUserId: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.showUserId = value
            return settings
        }).start()
    }, updateShowGroupsId: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.showGroupsId = value
            return settings
        }).start()
    }, updateShowChannelsId: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.showChannelsId = value
            return settings
        }).start()
    }, updateDisableAds: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.disableAds = value
            return settings
        }).start()
    }, updateHideSimilarChannels: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.hideSimilarChannels = value
            return settings
        }).start()
    }, updateShowSecondsInMessages: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.showSecondsInMessages = value
            return settings
        }).start()
    }, updateForceAllowCopy: { value in
        let _ = updateMolteagramSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.forceAllowCopy = value
            return settings
        }).start()
    })
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [MolteagramSpecificSharedDataKeys.molteagramSettings])
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
                                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
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
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
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
            
            let molteagramSettings: MolteagramSettings
            if let settings = sharedData.entries[MolteagramSpecificSharedDataKeys.molteagramSettings]?.get(MolteagramSettings.self) {
                molteagramSettings = settings
            } else {
                molteagramSettings = MolteagramSettings.defaultSettings
            }
            
            let entries = molteagramSettingsEntries(molteagramSettings: molteagramSettings, presentationData: presentationData)
            
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
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(MolteagramStrings.get("Molteagram.SettingsTitle", languageCode: lang)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
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
