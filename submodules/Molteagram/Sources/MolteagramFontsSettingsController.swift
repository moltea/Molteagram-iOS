import Foundation
import UIKit
import Display
import MolteagramCore
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import UniformTypeIdentifiers

private final class MolteagramFontsSettingsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let openCategoryWeights: (MolteagramFontCategory) -> Void
    let resetAllFonts: () -> Void
    let importFontPack: () -> Void
    
    init(context: AccountContext,
         presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void,
         pushController: @escaping (ViewController) -> Void,
         openCategoryWeights: @escaping (MolteagramFontCategory) -> Void,
         resetAllFonts: @escaping () -> Void,
         importFontPack: @escaping () -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.openCategoryWeights = openCategoryWeights
        self.resetAllFonts = resetAllFonts
        self.importFontPack = importFontPack
    }
}

private enum MolteagramFontsSection: Int32 {
    case fonts
    case reset
}

private enum MolteagramFontsEntry: ItemListNodeEntry {
    case fontCategory(PresentationTheme, String, String, MolteagramFontCategory, Int32)
    case fontInfo(PresentationTheme, String, Int32)
    case importPack(PresentationTheme, String)
    case resetAll(PresentationTheme, String)
    case restartNotice(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .fontCategory, .fontInfo:
            return MolteagramFontsSection.fonts.rawValue
        case .importPack, .resetAll, .restartNotice:
            return MolteagramFontsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case let .fontCategory(_, _, _, _, index):
            return index
        case let .fontInfo(_, _, index):
            return index
        case .importPack:
            return 99
        case .resetAll:
            return 100
        case .restartNotice:
            return 101
        }
    }
    
    var tag: ItemListItemTag? { return nil }
    
    static func ==(lhs: MolteagramFontsEntry, rhs: MolteagramFontsEntry) -> Bool {
        switch lhs {
        case let .fontCategory(lhsTheme, lhsTitle, lhsSubtitle, lhsCategory, lhsIndex):
            if case let .fontCategory(rhsTheme, rhsTitle, rhsSubtitle, rhsCategory, rhsIndex) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsCategory == rhsCategory, lhsIndex == rhsIndex {
                return true
            } else { return false }
        case let .fontInfo(lhsTheme, lhsText, lhsIndex):
            if case let .fontInfo(rhsTheme, rhsText, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsIndex == rhsIndex {
                return true
            } else { return false }
        case let .resetAll(lhsTheme, lhsTitle):
            if case let .resetAll(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                return true
            } else { return false }
        case let .importPack(lhsTheme, lhsTitle):
            if case let .importPack(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                return true
            } else { return false }
        case let .restartNotice(lhsTheme, lhsText):
            if case let .restartNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else { return false }
        }
    }
    
    static func <(lhs: MolteagramFontsEntry, rhs: MolteagramFontsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MolteagramFontsSettingsArguments
        switch self {
        case let .fontCategory(_, title, subtitle, category, _):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openCategoryWeights(category)
            })
        case let .fontInfo(_, text, _):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .resetAll(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.resetAllFonts()
            })
        case let .importPack(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.importFontPack()
            })
        case let .restartNotice(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func molteagramFontsEntries(fontSettings: MolteagramFontSettings, presentationData: PresentationData) -> [MolteagramFontsEntry] {
    var entries: [MolteagramFontsEntry] = []
    let lang = presentationData.strings.primaryComponent.languageCode
    let defaultLabel = MolteagramStrings.get("Molteagram.FontDefault", languageCode: lang)
    
    let categories: [(MolteagramFontCategory, String, String)] = [
        (.system,    MolteagramStrings.get("Molteagram.FontSystem", languageCode: lang), MolteagramStrings.get("Molteagram.FontSystemInfo", languageCode: lang)),
        (.monospace, MolteagramStrings.get("Molteagram.FontMonospace", languageCode: lang), MolteagramStrings.get("Molteagram.FontMonospaceInfo", languageCode: lang)),
        (.serif,     MolteagramStrings.get("Molteagram.FontSerif", languageCode: lang), MolteagramStrings.get("Molteagram.FontSerifInfo", languageCode: lang)),
        (.round,     MolteagramStrings.get("Molteagram.FontRound", languageCode: lang), MolteagramStrings.get("Molteagram.FontRoundInfo", languageCode: lang)),
    ]
    
    var idx: Int32 = 1
    for (category, title, info) in categories {
        let customCount = category.supportedWeights.filter { fontSettings.fontName(for: category, weight: $0) != nil }.count
        let totalWeights = category.supportedWeights.count
        let subtitle: String
        if customCount == 0 {
            subtitle = defaultLabel
        } else {
            subtitle = "\(customCount)/\(totalWeights)"
        }
        entries.append(.fontCategory(presentationData.theme, title, subtitle, category, idx))
        idx += 1
        entries.append(.fontInfo(presentationData.theme, info, idx))
        idx += 1
    }
    
    entries.append(.importPack(presentationData.theme, MolteagramStrings.get("Molteagram.FontImportPack", languageCode: lang)))
    entries.append(.resetAll(presentationData.theme, MolteagramStrings.get("Molteagram.FontResetAll", languageCode: lang)))
    entries.append(.restartNotice(presentationData.theme, MolteagramStrings.get("Molteagram.FontRestartNotice", languageCode: lang)))
    
    return entries
}

public func molteagramFontsSettingsController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentNativeControllerImpl: ((UIViewController) -> Void)?
    
    let fontSettingsPromise = ValuePromise<MolteagramFontSettings>(MolteagramFontSettings.load(), ignoreRepeated: true)
    
    let arguments = MolteagramFontsSettingsArguments(
        context: context,
        presentController: { controller, args in
            presentControllerImpl?(controller, args)
        },
        pushController: { controller in
            pushControllerImpl?(controller)
        },
        openCategoryWeights: { category in
            pushControllerImpl?(molteagramFontWeightsController(context: context, category: category, fontSettingsPromise: fontSettingsPromise))
        },
        resetAllFonts: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let lang = presentationData.strings.baseLanguageCode
            let alert = textAlertController(context: context, title: MolteagramStrings.get("Molteagram.FontResetAll", languageCode: lang), text: MolteagramStrings.get("Molteagram.FontResetAllConfirmation", languageCode: lang), actions: [
                TextAlertAction(type: .defaultAction, title: MolteagramStrings.get("Molteagram.Cancel", languageCode: lang), action: {}),
                TextAlertAction(type: .destructiveAction, title: MolteagramStrings.get("Molteagram.FontResetAll", languageCode: lang), action: {
                    MolteagramFontSettings.resetAll()
                    Font.clearCache()
                    fontSettingsPromise.set(MolteagramFontSettings.load())
                })
            ])
            presentControllerImpl?(alert, nil)
        },
        importFontPack: {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            let coordinator = FontPackPickerCoordinator(context: context, presentationData: context.sharedContext.currentPresentationData.with { $0 }, fontSettingsPromise: fontSettingsPromise, presentController: { controller, arguments in
                presentControllerImpl?(controller, arguments)
            })
            picker.delegate = coordinator
            _activeCoordinator = coordinator
            presentNativeControllerImpl?(picker)
        }
    )
    
    let signal = combineLatest(context.sharedContext.presentationData, fontSettingsPromise.get())
        |> map { presentationData, fontSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let lang = presentationData.strings.primaryComponent.languageCode
            let entries = molteagramFontsEntries(fontSettings: fontSettings, presentationData: presentationData)
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(MolteagramStrings.get("Molteagram.FontsTitle", languageCode: lang)),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: entries,
                style: .blocks
            )
            return (controllerState, (listState, arguments as MolteagramFontsSettingsArguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentNativeControllerImpl = { [weak controller] nativeController in
        controller?.view.window?.rootViewController?.present(nativeController, animated: true)
    }
    
    return controller
}

private final class MolteagramFontWeightsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let onWeightTapped: (MolteagramFontCategory, MolteagramFontWeight, Bool) -> Void
    
    init(context: AccountContext,
         presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void,
         onWeightTapped: @escaping (MolteagramFontCategory, MolteagramFontWeight, Bool) -> Void) {
        self.context = context
        self.presentController = presentController
        self.onWeightTapped = onWeightTapped
    }
}

private enum MolteagramFontWeightsSection: Int32 {
    case weights
}

private enum MolteagramFontWeightsEntry: ItemListNodeEntry {
    case weightHeader(PresentationTheme, String)
    case weight(PresentationTheme, MolteagramFontCategory, MolteagramFontWeight, String?, Int32)
    case restartNotice(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return MolteagramFontWeightsSection.weights.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .weightHeader:
            return 0
        case let .weight(_, _, _, _, index):
            return index
        case .restartNotice:
            return 100
        }
    }
    
    var tag: ItemListItemTag? { return nil }
    
    static func ==(lhs: MolteagramFontWeightsEntry, rhs: MolteagramFontWeightsEntry) -> Bool {
        switch lhs {
        case let .weightHeader(lhsTheme, lhsText):
            if case let .weightHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else { return false }
        case let .weight(lhsTheme, lhsCat, lhsWeight, lhsName, lhsIndex):
            if case let .weight(rhsTheme, rhsCat, rhsWeight, rhsName, rhsIndex) = rhs,
               lhsTheme === rhsTheme, lhsCat == rhsCat, lhsWeight == rhsWeight, lhsName == rhsName, lhsIndex == rhsIndex {
                return true
            } else { return false }
        case let .restartNotice(lhsTheme, lhsText):
            if case let .restartNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else { return false }
        }
    }
    
    static func <(lhs: MolteagramFontWeightsEntry, rhs: MolteagramFontWeightsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MolteagramFontWeightsArguments
        switch self {
        case let .weightHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .weight(_, category, weight, fontName, _):
            let lang = arguments.context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
            let subtitle = fontName ?? MolteagramStrings.get("Molteagram.FontDefault", languageCode: lang)
            let hasCustomFont = fontName != nil
            return ItemListDisclosureItem(presentationData: presentationData, title: weight.displayName, label: subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.onWeightTapped(category, weight, hasCustomFont)
            })
        case let .restartNotice(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func molteagramFontWeightsEntries(category: MolteagramFontCategory, fontSettings: MolteagramFontSettings, presentationData: PresentationData) -> [MolteagramFontWeightsEntry] {
    var entries: [MolteagramFontWeightsEntry] = []
    let lang = presentationData.strings.primaryComponent.languageCode
    entries.append(.weightHeader(presentationData.theme, MolteagramStrings.get("Molteagram.FontWeightsHeader", languageCode: lang)))
    
    for (index, weight) in category.supportedWeights.enumerated() {
        let fontName = fontSettings.fontName(for: category, weight: weight)
        entries.append(.weight(presentationData.theme, category, weight, fontName, Int32(index + 1)))
    }
    
    entries.append(.restartNotice(presentationData.theme, MolteagramStrings.get("Molteagram.FontRestartNotice", languageCode: lang)))
    
    return entries
}

/// Coordinator class that handles the document picker delegate
private final class FontImportCoordinator: NSObject, UIDocumentPickerDelegate {
    let category: MolteagramFontCategory
    let weight: MolteagramFontWeight
    let fontSettingsPromise: ValuePromise<MolteagramFontSettings>
    
    init(category: MolteagramFontCategory, weight: MolteagramFontWeight, fontSettingsPromise: ValuePromise<MolteagramFontSettings>) {
        self.category = category
        self.weight = weight
        self.fontSettingsPromise = fontSettingsPromise
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        MolteagramFontSettings.importFont(from: url, category: category, weight: weight)
        Font.clearCache()
        fontSettingsPromise.set(MolteagramFontSettings.load())
    }
}

// We need to hold a strong reference to the coordinator while the picker is active
private var _activeCoordinator: NSObject?

private final class FontPackPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    let context: AccountContext
    let presentationData: PresentationData
    let fontSettingsPromise: ValuePromise<MolteagramFontSettings>
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    
    init(context: AccountContext, presentationData: PresentationData, fontSettingsPromise: ValuePromise<MolteagramFontSettings>, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.fontSettingsPromise = fontSettingsPromise
        self.presentController = presentController
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        let result = MolteagramFontSettings.importFontPack(at: url)
        Font.clearCache()
        fontSettingsPromise.set(MolteagramFontSettings.load())
        
        let lang = presentationData.strings.primaryComponent.languageCode
        let title = MolteagramStrings.get("Molteagram.FontImportPackDialog", languageCode: lang)
        
        let text = String(format: MolteagramStrings.get("Molteagram.FontImportPackSuccess", languageCode: lang), result.imported, result.skipped)
        
        let alert = textAlertController(context: context, title: title, text: text, actions: [
            TextAlertAction(type: .defaultAction, title: "OK", action: {})
        ])
        presentController(alert, nil)
    }
}

private func openFontPicker(category: MolteagramFontCategory, weight: MolteagramFontWeight, fontSettingsPromise: ValuePromise<MolteagramFontSettings>, presentNative: @escaping (UIViewController) -> Void) {
    let coordinator = FontImportCoordinator(category: category, weight: weight, fontSettingsPromise: fontSettingsPromise)
    _activeCoordinator = coordinator
    
    var types: [UTType] = []
    if let ttf = UTType(filenameExtension: "ttf") { types.append(ttf) }
    if let otf = UTType(filenameExtension: "otf") { types.append(otf) }
    if types.isEmpty { types = [.data] }
    
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.delegate = coordinator
    picker.allowsMultipleSelection = false
    presentNative(picker)
}

private func clearFontWeight(category: MolteagramFontCategory, weight: MolteagramFontWeight, fontSettingsPromise: ValuePromise<MolteagramFontSettings>) {
    MolteagramFontSettings.deleteFont(for: category, weight: weight)
    var settings = MolteagramFontSettings.load()
    settings.setFontName(nil, for: category, weight: weight)
    settings.save()
    Font.clearCache()
    fontSettingsPromise.set(MolteagramFontSettings.load())
}

private func molteagramFontWeightsController(context: AccountContext, category: MolteagramFontCategory, fontSettingsPromise: ValuePromise<MolteagramFontSettings>) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentNativeControllerImpl: ((UIViewController) -> Void)?
    
    let arguments = MolteagramFontWeightsArguments(
        context: context,
        presentController: { controller, args in
            presentControllerImpl?(controller, args)
        },
        onWeightTapped: { category, weight, hasCustomFont in
            if hasCustomFont {
                let lang = context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
                let importTitle = MolteagramStrings.get("Molteagram.FontImport", languageCode: lang)
                let resetTitle = MolteagramStrings.get("Molteagram.FontDefault", languageCode: lang)
                let alert = textAlertController(
                    context: context,
                    title: weight.displayName,
                    text: "",
                    actions: [
                        TextAlertAction(type: .genericAction, title: importTitle, action: {
                            if let presentNative = presentNativeControllerImpl {
                                openFontPicker(category: category, weight: weight, fontSettingsPromise: fontSettingsPromise, presentNative: presentNative)
                            }
                        }),
                        TextAlertAction(type: .destructiveAction, title: resetTitle, action: {
                            clearFontWeight(category: category, weight: weight, fontSettingsPromise: fontSettingsPromise)
                        }),
                        TextAlertAction(type: .genericAction, title: MolteagramStrings.get("Molteagram.Cancel", languageCode: lang), action: {})
                    ]
                )
                presentControllerImpl?(alert, nil)
            } else {
                // No custom font — open picker directly
                if let presentNative = presentNativeControllerImpl {
                    openFontPicker(category: category, weight: weight, fontSettingsPromise: fontSettingsPromise, presentNative: presentNative)
                }
            }
        }
    )
    
    let categoryTitleKey: String
    switch category {
    case .system:    categoryTitleKey = "Molteagram.FontSystem"
    case .monospace: categoryTitleKey = "Molteagram.FontMonospace"
    case .serif:     categoryTitleKey = "Molteagram.FontSerif"
    case .round:     categoryTitleKey = "Molteagram.FontRound"
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, fontSettingsPromise.get())
        |> map { presentationData, fontSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let lang = presentationData.strings.primaryComponent.languageCode
            let entries = molteagramFontWeightsEntries(category: category, fontSettings: fontSettings, presentationData: presentationData)
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(MolteagramStrings.get(categoryTitleKey, languageCode: lang)),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: entries,
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    presentNativeControllerImpl = { [weak controller] nativeController in
        controller?.view.window?.rootViewController?.present(nativeController, animated: true)
    }
    
    return controller
}
