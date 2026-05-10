import Foundation
import UIKit
import Display
import MolteagramCore
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import UniformTypeIdentifiers
import ZipArchive
import UndoUI

private struct MolteagramAccountArchiveManifest: Codable {
    let version: Int32
    let accounts: [MolteagramAccountArchiveRecord]
}

private struct MolteagramAccountArchiveRecord: Codable {
    let recordId: Int64
    let userId: Int64
    let title: String
    let folderName: String
    let record: AccountRecord<TelegramAccountRecordAttribute>
}

private struct MolteagramSelectableAccount: Equatable {
    let recordId: AccountRecordId
    let userId: Int64
    let title: String
    let status: String
    let folderName: String
    let record: AccountRecord<TelegramAccountRecordAttribute>
    let enabled: Bool
}

private var activeAccountsDocumentCoordinator: NSObject?

private final class MolteagramAccountsSettingsArguments {
    let toggleAccount: (Int64) -> Void
    let toggleAll: () -> Void
    let exportAccounts: () -> Void
    let importAccounts: () -> Void

    init(toggleAccount: @escaping (Int64) -> Void, toggleAll: @escaping () -> Void, exportAccounts: @escaping () -> Void, importAccounts: @escaping () -> Void) {
        self.toggleAccount = toggleAccount
        self.toggleAll = toggleAll
        self.exportAccounts = exportAccounts
        self.importAccounts = importAccounts
    }
}

private final class MolteagramAccountImportCoordinator: NSObject, UIDocumentPickerDelegate {
    let context: AccountContext
    let pushController: (ViewController) -> Void
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void

    init(context: AccountContext, pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void) {
        self.context = context
        self.pushController = pushController
        self.presentController = presentController
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let accounts = inspectMolteagramAccountsArchive(context: self.context, archiveUrl: url)
        if accounts.isEmpty {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let lang = presentationData.strings.primaryComponent.languageCode
            self.presentController(textAlertController(context: self.context, title: MolteagramStrings.get("Molteagram.Accounts", languageCode: lang), text: MolteagramStrings.get("Molteagram.AccountsImportInvalidArchive", languageCode: lang), actions: [
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
            ]), nil)
            return
        }
        self.pushController(molteagramAccountsImportSelectionController(context: self.context, archiveUrl: url, accounts: accounts))
    }
}

private enum MolteagramAccountsSection: Int32 {
    case accounts
    case actions
    case info
}

private enum MolteagramAccountsEntry: ItemListNodeEntry {
    case selectAll(PresentationTheme, String, Bool)
    case account(PresentationTheme, Int32, MolteagramSelectableAccount, Bool)
    case export(PresentationTheme, String, Bool)
    case `import`(PresentationTheme, String)
    case info(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .selectAll, .account:
            return MolteagramAccountsSection.accounts.rawValue
        case .export, .import:
            return MolteagramAccountsSection.actions.rawValue
        case .info:
            return MolteagramAccountsSection.info.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .selectAll:
            return 0
        case let .account(_, index, _, _):
            return 100 + index
        case .export:
            return 1_000_000
        case .import:
            return 1_000_001
        case .info:
            return 1_000_002
        }
    }

    var tag: ItemListItemTag? {
        return nil
    }

    static func ==(lhs: MolteagramAccountsEntry, rhs: MolteagramAccountsEntry) -> Bool {
        switch lhs {
        case let .selectAll(lhsTheme, lhsTitle, lhsChecked):
            if case let .selectAll(rhsTheme, rhsTitle, rhsChecked) = rhs {
                return lhsTheme === rhsTheme && lhsTitle == rhsTitle && lhsChecked == rhsChecked
            }
        case let .account(lhsTheme, lhsIndex, lhsAccount, lhsChecked):
            if case let .account(rhsTheme, rhsIndex, rhsAccount, rhsChecked) = rhs {
                return lhsTheme === rhsTheme && lhsIndex == rhsIndex && lhsAccount == rhsAccount && lhsChecked == rhsChecked
            }
        case let .export(lhsTheme, lhsTitle, lhsEnabled):
            if case let .export(rhsTheme, rhsTitle, rhsEnabled) = rhs {
                return lhsTheme === rhsTheme && lhsTitle == rhsTitle && lhsEnabled == rhsEnabled
            }
        case let .import(lhsTheme, lhsTitle):
            if case let .import(rhsTheme, rhsTitle) = rhs {
                return lhsTheme === rhsTheme && lhsTitle == rhsTitle
            }
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
        }
        return false
    }

    static func <(lhs: MolteagramAccountsEntry, rhs: MolteagramAccountsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MolteagramAccountsSettingsArguments
        switch self {
        case let .selectAll(_, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.toggleAll()
            })
        case let .account(_, _, account, checked):
            return ItemListCheckboxItem(presentationData: presentationData, title: account.title, subtitle: account.status, style: .left, checked: checked, enabled: account.enabled, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.toggleAccount(account.recordId.int64)
            })
        case let .export(_, title, enabled):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                if enabled {
                    arguments.exportAccounts()
                }
            })
        case let .import(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.importAccounts()
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func molteagramAccountsEntries(accounts: [MolteagramSelectableAccount], selectedIds: Set<Int64>, presentationData: PresentationData, isImport: Bool) -> [MolteagramAccountsEntry] {
    let lang = presentationData.strings.primaryComponent.languageCode
    let enabledAccounts = accounts.filter(\.enabled)
    let selectedEnabledCount = enabledAccounts.filter { selectedIds.contains($0.recordId.int64) }.count
    let allSelected = !enabledAccounts.isEmpty && selectedEnabledCount == enabledAccounts.count

    var entries: [MolteagramAccountsEntry] = []
    entries.append(.selectAll(presentationData.theme, MolteagramStrings.get("Molteagram.AccountsSelectAll", languageCode: lang), allSelected))
    for (index, account) in accounts.enumerated() {
        entries.append(.account(presentationData.theme, Int32(index), account, selectedIds.contains(account.recordId.int64)))
    }
    entries.append(.export(presentationData.theme, isImport ? MolteagramStrings.get("Molteagram.AccountsImportSelected", languageCode: lang) : MolteagramStrings.get("Molteagram.AccountsExportSelected", languageCode: lang), selectedEnabledCount > 0))
    if !isImport {
        entries.append(.import(presentationData.theme, MolteagramStrings.get("Molteagram.AccountsImport", languageCode: lang)))
        entries.append(.info(presentationData.theme, MolteagramStrings.get("Molteagram.AccountsArchiveInfo", languageCode: lang)))
    }
    return entries
}

public func molteagramAccountsSettingsController(context: AccountContext) -> ViewController {
    let selectedIds = ValuePromise<Set<Int64>>(Set(), ignoreRepeated: true)
    let selectedIdsState = Atomic<Set<Int64>>(value: Set())
    let selectionInitialized = Atomic<Bool>(value: false)
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentNativeControllerImpl: ((UIViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var currentAccounts: [MolteagramSelectableAccount] = []

    let arguments = MolteagramAccountsSettingsArguments(toggleAccount: { id in
        let updated = selectedIdsState.modify { current in
            var current = current
            if current.contains(id) {
                current.remove(id)
            } else {
                current.insert(id)
            }
            return current
        }
        selectedIds.set(updated)
    }, toggleAll: {
        let updated = selectedIdsState.modify { current in
            let enabledIds = Set(currentAccounts.filter(\.enabled).map { $0.recordId.int64 })
            if enabledIds.isSubset(of: current), !enabledIds.isEmpty {
                return Set()
            } else {
                return enabledIds
            }
        }
        selectedIds.set(updated)
    }, exportAccounts: {
        let selected = selectedIdsState.with { $0 }
        let accounts = currentAccounts.filter { selected.contains($0.recordId.int64) && $0.enabled }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let lang = presentationData.strings.primaryComponent.languageCode
        guard let archiveUrl = exportMolteagramAccounts(context: context, accounts: accounts) else {
            presentControllerImpl?(textAlertController(context: context, title: MolteagramStrings.get("Molteagram.Accounts", languageCode: lang), text: MolteagramStrings.get("Molteagram.AccountsExportFailed", languageCode: lang), actions: [
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
            ]), nil)
            return
        }
        presentNativeControllerImpl?(UIDocumentPickerViewController(forExporting: [archiveUrl], asCopy: true))
    }, importAccounts: {
        let coordinator = MolteagramAccountImportCoordinator(context: context, pushController: { controller in
            pushControllerImpl?(controller)
        }, presentController: { controller, arguments in
            presentControllerImpl?(controller, arguments)
        })
        activeAccountsDocumentCoordinator = coordinator
        var types: [UTType] = []
        if let type = UTType(filenameExtension: "molaccs") {
            types.append(type)
        }
        if types.isEmpty {
            types = [.data]
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = coordinator
        picker.allowsMultipleSelection = false
        presentNativeControllerImpl?(picker)
    })

    let records = context.sharedContext.accountManager.accountRecords()
    let signal = combineLatest(context.sharedContext.presentationData, context.sharedContext.activeAccountsWithInfo, records, selectedIds.get())
    |> map { presentationData, activeAccountsWithInfo, recordsView, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let lang = presentationData.strings.primaryComponent.languageCode
        let userIdPrefix = MolteagramStrings.get("Molteagram.AccountsUserIdPrefix", languageCode: lang)
        let recordsById = Dictionary(uniqueKeysWithValues: recordsView.records.map { ($0.id, $0) })
        let accounts = activeAccountsWithInfo.accounts.compactMap { accountWithInfo -> MolteagramSelectableAccount? in
            guard let record = recordsById[accountWithInfo.account.id] else {
                return nil
            }
            let userId = accountWithInfo.account.peerId.toInt64()
            return MolteagramSelectableAccount(recordId: record.id, userId: userId, title: accountWithInfo.peer.compactDisplayTitle, status: "\(userIdPrefix) \(userId)", folderName: accountRecordIdPathName(record.id), record: record, enabled: true)
        }
        currentAccounts = accounts
        if !selectionInitialized.with({ $0 }), !accounts.isEmpty {
            let initialSelection = Set(accounts.map { $0.recordId.int64 })
            let _ = selectionInitialized.swap(true)
            let _ = selectedIdsState.swap(initialSelection)
            Queue.mainQueue().async {
                selectedIds.set(initialSelection)
            }
        }

        let effectiveSelectedIds = selectedIdsState.with { $0 }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(MolteagramStrings.get("Molteagram.Accounts", languageCode: lang)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: molteagramAccountsEntries(accounts: accounts, selectedIds: effectiveSelectedIds, presentationData: presentationData, isImport: false), style: .blocks)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    presentNativeControllerImpl = { [weak controller] c in
        controller?.present(c, animated: true)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

private func molteagramAccountsImportSelectionController(context: AccountContext, archiveUrl: URL, accounts: [MolteagramSelectableAccount]) -> ViewController {
    let initialSelectedIds = Set(accounts.filter(\.enabled).map { $0.recordId.int64 })
    let selectedIds = ValuePromise<Set<Int64>>(initialSelectedIds, ignoreRepeated: true)
    let selectedIdsState = Atomic<Set<Int64>>(value: initialSelectedIds)
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    let arguments = MolteagramAccountsSettingsArguments(toggleAccount: { id in
        let updated = selectedIdsState.modify { current in
            var current = current
            if current.contains(id) {
                current.remove(id)
            } else {
                current.insert(id)
            }
            return current
        }
        selectedIds.set(updated)
    }, toggleAll: {
        let updated = selectedIdsState.modify { current in
            let enabledIds = Set(accounts.filter(\.enabled).map { $0.recordId.int64 })
            if enabledIds.isSubset(of: current), !enabledIds.isEmpty {
                return Set()
            } else {
                return enabledIds
            }
        }
        selectedIds.set(updated)
    }, exportAccounts: {
        let selected = selectedIdsState.with { $0 }
        let result = importMolteagramAccounts(context: context, archiveUrl: archiveUrl, selectedRecordIds: selected)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let lang = presentationData.strings.primaryComponent.languageCode
        let text = String(format: MolteagramStrings.get("Molteagram.AccountsImportResult", languageCode: lang), result.imported, result.skipped)
        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: text, timeout: 5.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), nil)
    }, importAccounts: {})

    let signal = combineLatest(context.sharedContext.presentationData, selectedIds.get())
    |> map { presentationData, selected -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let lang = presentationData.strings.primaryComponent.languageCode
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(MolteagramStrings.get("Molteagram.AccountsImport", languageCode: lang)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: molteagramAccountsEntries(accounts: accounts, selectedIds: selected, presentationData: presentationData, isImport: true), style: .blocks)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    return controller
}

private func exportMolteagramAccounts(context: AccountContext, accounts: [MolteagramSelectableAccount]) -> URL? {
    let rootPath = context.sharedContext.basePath
    let exportRoot = NSTemporaryDirectory() + "molaccs_export_" + UUID().uuidString
    let payloadPath = exportRoot + "/payload"
    let accountsPath = payloadPath + "/accounts"
    let archivePath = NSTemporaryDirectory() + "MolteagramAccounts-\(Int32(Date().timeIntervalSince1970)).molaccs"
    let fileManager = FileManager.default

    try? fileManager.removeItem(atPath: exportRoot)
    try? fileManager.removeItem(atPath: archivePath)
    guard (try? fileManager.createDirectory(atPath: accountsPath, withIntermediateDirectories: true)) != nil else {
        return nil
    }

    var archiveRecords: [MolteagramAccountArchiveRecord] = []
    for account in accounts {
        let sourcePath = rootPath + "/" + account.folderName
        let destinationPath = accountsPath + "/" + account.folderName
        guard fileManager.fileExists(atPath: sourcePath) else {
            continue
        }
        try? fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
        archiveRecords.append(MolteagramAccountArchiveRecord(recordId: account.recordId.int64, userId: account.userId, title: account.title, folderName: account.folderName, record: account.record))
    }

    guard !archiveRecords.isEmpty, let manifestData = try? JSONEncoder().encode(MolteagramAccountArchiveManifest(version: 1, accounts: archiveRecords)) else {
        try? fileManager.removeItem(atPath: exportRoot)
        return nil
    }
    do {
        try manifestData.write(to: URL(fileURLWithPath: payloadPath + "/manifest.json"), options: [.atomic])
    } catch {
        try? fileManager.removeItem(atPath: exportRoot)
        return nil
    }

    guard SSZipArchive.createZipFile(atPath: archivePath, withContentsOfDirectory: payloadPath) else {
        try? fileManager.removeItem(atPath: exportRoot)
        return nil
    }
    try? fileManager.removeItem(atPath: exportRoot)
    return URL(fileURLWithPath: archivePath)
}

private func inspectMolteagramAccountsArchive(context: AccountContext, archiveUrl: URL) -> [MolteagramSelectableAccount] {
    let importRoot = NSTemporaryDirectory() + "molaccs_inspect_" + UUID().uuidString
    let fileManager = FileManager.default
    try? fileManager.removeItem(atPath: importRoot)
    try? fileManager.createDirectory(atPath: importRoot, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(atPath: importRoot)
    }

    guard SSZipArchive.unzipFile(atPath: archiveUrl.path, toDestination: importRoot), let manifestData = try? Data(contentsOf: URL(fileURLWithPath: importRoot + "/manifest.json")), let manifest = try? JSONDecoder().decode(MolteagramAccountArchiveManifest.self, from: manifestData), manifest.version == 1 else {
        return []
    }

    let existingRecordIds = context.sharedContext.accountManager.transaction { transaction -> Set<AccountRecordId> in
        return Set(transaction.getRecords().map(\.id))
    }
    |> take(1)
    var recordIds = Set<AccountRecordId>()
    let semaphore = DispatchSemaphore(value: 0)
    let _ = existingRecordIds.startStandalone(next: { ids in
        recordIds = ids
        semaphore.signal()
    })
    semaphore.wait()

    var existingUserIds = Set<Int64>()
    let activeSemaphore = DispatchSemaphore(value: 0)
    let _ = (context.sharedContext.activeAccountsWithInfo |> take(1)).startStandalone(next: { value in
        existingUserIds = Set(value.accounts.map { $0.account.peerId.toInt64() })
        activeSemaphore.signal()
    })
    activeSemaphore.wait()

    return manifest.accounts.map { item in
        let recordId = item.record.id
        let expectedFolderName = accountRecordIdPathName(recordId)
        let accountPath = importRoot + "/accounts/" + item.folderName
        let structurallyValid = item.recordId == recordId.int64 && item.userId != 0 && item.folderName == expectedFolderName && !item.folderName.contains("/") && fileManager.fileExists(atPath: accountPath + "/postbox")
        let duplicate = recordIds.contains(recordId) || existingUserIds.contains(item.userId)
        let enabled = structurallyValid && !duplicate
        let lang = context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
        let userIdPrefix = MolteagramStrings.get("Molteagram.AccountsUserIdPrefix", languageCode: lang)
        let status: String
        if duplicate {
            status = "\(userIdPrefix) \(item.userId) • \(MolteagramStrings.get("Molteagram.AccountsDuplicate", languageCode: lang))"
        } else if !structurallyValid {
            status = "\(userIdPrefix) \(item.userId) • \(MolteagramStrings.get("Molteagram.AccountsInvalid", languageCode: lang))"
        } else {
            status = "\(userIdPrefix) \(item.userId)"
        }
        return MolteagramSelectableAccount(recordId: recordId, userId: item.userId, title: item.title, status: status, folderName: item.folderName, record: item.record, enabled: enabled)
    }
}

private func importMolteagramAccounts(context: AccountContext, archiveUrl: URL, selectedRecordIds: Set<Int64>) -> (imported: Int, skipped: Int) {
    let rootPath = context.sharedContext.basePath
    let importRoot = NSTemporaryDirectory() + "molaccs_import_" + UUID().uuidString
    let fileManager = FileManager.default
    try? fileManager.removeItem(atPath: importRoot)
    try? fileManager.createDirectory(atPath: importRoot, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(atPath: importRoot)
    }

    guard SSZipArchive.unzipFile(atPath: archiveUrl.path, toDestination: importRoot), let manifestData = try? Data(contentsOf: URL(fileURLWithPath: importRoot + "/manifest.json")), let manifest = try? JSONDecoder().decode(MolteagramAccountArchiveManifest.self, from: manifestData), manifest.version == 1 else {
        return (0, 0)
    }

    let availableAccounts = inspectMolteagramAccountsArchive(context: context, archiveUrl: archiveUrl)
    let availableIds = Set(availableAccounts.filter(\.enabled).map { $0.recordId.int64 })

    var imported = 0
    var skipped = 0
    for item in manifest.accounts {
        let recordId = item.record.id
        guard selectedRecordIds.contains(recordId.int64) else {
            continue
        }
        guard availableIds.contains(recordId.int64) else {
            skipped += 1
            continue
        }
        let sourcePath = importRoot + "/accounts/" + item.folderName
        let destinationPath = rootPath + "/" + accountRecordIdPathName(recordId)
        guard fileManager.fileExists(atPath: sourcePath), !fileManager.fileExists(atPath: destinationPath) else {
            skipped += 1
            continue
        }
        do {
            try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
            let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
                transaction.updateRecord(recordId, { _ in
                    return item.record
                })
            }).startStandalone()
            imported += 1
        } catch {
            skipped += 1
        }
    }

    return (imported, skipped)
}
