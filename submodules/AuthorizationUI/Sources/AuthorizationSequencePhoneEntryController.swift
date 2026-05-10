import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ProgressNavigationButtonNode
import AccountContext
import CountrySelectionUI
import PhoneNumberFormat
import DebugSettingsUI
import MessageUI
import AuthenticationServices
import UniformTypeIdentifiers
import ZipArchive
import MolteagramCore

private struct MolteagramPhoneAccountArchiveManifest: Codable {
    let version: Int32
    let accounts: [MolteagramPhoneAccountArchiveRecord]
}

private struct MolteagramPhoneAccountArchiveRecord: Codable {
    let recordId: Int64
    let userId: Int64
    let title: String
    let folderName: String
    let record: AccountRecord<TelegramAccountRecordAttribute>
}

private struct MolteagramPhoneSelectableAccount: Equatable {
    let recordId: AccountRecordId
    let userId: Int64
    let title: String
    let status: String
    let folderName: String
    let record: AccountRecord<TelegramAccountRecordAttribute>
    let enabled: Bool
}

private final class MolteagramPhoneAccountImportCoordinator: NSObject, UIDocumentPickerDelegate {
    private weak var controller: AuthorizationSequencePhoneEntryController?
    
    init(controller: AuthorizationSequencePhoneEntryController) {
        self.controller = controller
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        self.controller?.prepareMolteagramAccountsImport(url: url)
    }
}

private final class MolteagramPhoneAccountImportSelectionController: UITableViewController {
    private let accounts: [MolteagramPhoneSelectableAccount]
    private let languageCode: String
    private var selectedIds: Set<Int64>
    private let importAction: (Set<Int64>) -> Void
    
    init(accounts: [MolteagramPhoneSelectableAccount], languageCode: String, importAction: @escaping (Set<Int64>) -> Void) {
        self.accounts = accounts
        self.languageCode = languageCode
        self.selectedIds = Set(accounts.filter(\.enabled).map { $0.recordId.int64 })
        self.importAction = importAction
        super.init(style: .insetGrouped)
        self.title = MolteagramStrings.get("Molteagram.AccountsImportButton", languageCode: languageCode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: MolteagramStrings.get("Molteagram.AccountsImportAction", languageCode: self.languageCode), style: .done, target: self, action: #selector(self.importPressed))
        self.updateImportButton()
    }
    
    private var enabledIds: Set<Int64> {
        return Set(self.accounts.filter(\.enabled).map { $0.recordId.int64 })
    }
    
    private var allEnabledSelected: Bool {
        let enabledIds = self.enabledIds
        return !enabledIds.isEmpty && enabledIds.isSubset(of: self.selectedIds)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return self.accounts.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = self.allEnabledSelected ? MolteagramStrings.get("Molteagram.AccountsDeselectAll", languageCode: self.languageCode) : MolteagramStrings.get("Molteagram.AccountsSelectAll", languageCode: self.languageCode)
            cell.textLabel?.textColor = self.view.tintColor
            cell.selectionStyle = self.enabledIds.isEmpty ? .none : .default
            return cell
        }
        let account = self.accounts[indexPath.row]
        cell.textLabel?.text = account.title
        cell.detailTextLabel?.text = account.status
        cell.selectionStyle = account.enabled ? .default : .none
        cell.textLabel?.isEnabled = account.enabled
        cell.detailTextLabel?.isEnabled = account.enabled
        cell.accessoryType = self.selectedIds.contains(account.recordId.int64) ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let enabledIds = self.enabledIds
            guard !enabledIds.isEmpty else {
                return
            }
            if self.allEnabledSelected {
                self.selectedIds.subtract(enabledIds)
            } else {
                self.selectedIds.formUnion(enabledIds)
            }
            tableView.reloadData()
            self.updateImportButton()
            return
        }
        let account = self.accounts[indexPath.row]
        guard account.enabled else {
            return
        }
        if self.selectedIds.contains(account.recordId.int64) {
            self.selectedIds.remove(account.recordId.int64)
        } else {
            self.selectedIds.insert(account.recordId.int64)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        self.updateImportButton()
    }
    
    private func updateImportButton() {
        self.navigationItem.rightBarButtonItem?.isEnabled = !self.selectedIds.isEmpty
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true)
    }
    
    @objc private func importPressed() {
        let selectedIds = self.selectedIds
        self.dismiss(animated: true) {
            self.importAction(selectedIds)
        }
    }
}

public final class AuthorizationSequencePhoneEntryController: ViewController, MFMailComposeViewControllerDelegate, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount?
    private let apiId: Int32
    private let apiHash: String
    private let isTestingEnvironment: Bool
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    private let network: Network
    private let presentationData: PresentationData
    private let openUrl: (String) -> Void
    
    private let back: () -> Void
    
    private var currentData: (Int32, String?, String)?
        
    var codeNode: ASDisplayNode {
        return self.controllerNode.codeNode
    }
    
    var numberNode: ASDisplayNode {
        return self.controllerNode.numberNode
    }
    
    var buttonNode: ASDisplayNode {
        return self.controllerNode.buttonNode
    }
    
    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
            self.confirmationController?.inProgress = self.inProgress
        }
    }
    public var loginWithNumber: ((String, Bool) -> Void)?
    public var loginWithPasskey: ((AuthorizationPasskeyData, Bool) -> Void)?
    var accountUpdated: ((UnauthorizedAccount) -> Void)?
    
    weak var confirmationController: PhoneConfirmationController?
    
    private let termsDisposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    private var importCoordinator: MolteagramPhoneAccountImportCoordinator?
    
    public init(sharedContext: SharedAccountContext, account: UnauthorizedAccount?, countriesConfiguration: CountriesConfiguration? = nil, apiId: Int32, apiHash: String, isTestingEnvironment: Bool, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]), network: Network, presentationData: PresentationData, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.sharedContext = sharedContext
        self.account = account
        self.apiId = apiId
        self.apiHash = apiHash
        self.isTestingEnvironment = isTestingEnvironment
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.network = network
        self.presentationData = presentationData
        self.openUrl = openUrl
        self.back = back
                
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        if !otherAccountPhoneNumbers.1.isEmpty {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "___close", style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        
        if let countriesConfiguration {
            AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.termsDisposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.back()
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    public func updateData(countryCode: Int32, countryName: String?, number: String) {
        self.currentData = (countryCode, countryName, number)
        if self.isNodeLoaded {
            self.controllerNode.codeAndNumber = (countryCode, countryName, number)
        }
    }
    
    private var shouldAnimateIn = false
    private var transitionInArguments: (buttonFrame: CGRect, buttonTitle: String, animationSnapshot: UIView, textSnapshot: UIView)?
    private var didStartTransitionIn = false
    
    func animateWithSplashController(_ controller: AuthorizationSequenceSplashController) {
        self.shouldAnimateIn = true
        
        if let animationSnapshot = controller.animationSnapshot, let textSnapshot = controller.textSnaphot {
            self.transitionInArguments = (controller.buttonFrame, controller.buttonTitle, animationSnapshot, textSnapshot)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(sharedContext: self.sharedContext, account: self.account, strings: self.presentationData.strings, theme: self.presentationData.theme, debugAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            self?.present(debugController(sharedContext: strongSelf.sharedContext, context: nil, modal: true), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, hasOtherAccounts: self.otherAccountPhoneNumbers.0 != nil)
        self.controllerNode.isImportAccountsHiddenForTransition = self.transitionInArguments != nil
        self.controllerNode.accountUpdated = { [weak self] account in
            guard let strongSelf = self else {
                return
            }
            strongSelf.account = account
            strongSelf.accountUpdated?(account)
        }
        self.controllerNode.retryPasskey = { [weak self] in
            guard let self else {
                return
            }
            self.loadAndPresentPasskey(force: true)
        }
        
        if let (code, name, number) = self.currentData {
            self.controllerNode.codeAndNumber = (code, name, number)
        }
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, glass: true)
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self, let currentData = strongSelf.currentData {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: currentData.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                controller.dismissed = { 
                    self?.controllerNode.activateInput()
                }
                strongSelf.push(controller)
            }
        }
        self.controllerNode.checkPhone = { [weak self] in
            self?.nextPressed()
        }
        self.controllerNode.importAccounts = { [weak self] in
            self?.openMolteagramAccountsImport()
        }
        
        if let account = self.account {
            loadServerCountryCodes(accountManager: sharedContext.accountManager, engine: TelegramEngineUnauthorized(account: account), completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.controllerNode.updateCountryCode()
                }
            })
        } else {
            self.controllerNode.updateCountryCode()
        }
        
        self.loadAndPresentPasskey(force: false)
    }
    
    private func openMolteagramAccountsImport() {
        let coordinator = MolteagramPhoneAccountImportCoordinator(controller: self)
        self.importCoordinator = coordinator
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
        self.present(picker, animated: true)
    }
    
    fileprivate func prepareMolteagramAccountsImport(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let localUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "molaccs_phone_selected_" + UUID().uuidString + ".molaccs")
        do {
            try? FileManager.default.removeItem(at: localUrl)
            try FileManager.default.copyItem(at: url, to: localUrl)
        } catch {
            self.presentMolteagramImportResult(imported: 0, skipped: 0, invalidArchive: true)
            return
        }
        let accounts = self.inspectMolteagramAccountsArchive(url: localUrl)
        guard !accounts.isEmpty else {
            self.presentMolteagramImportResult(imported: 0, skipped: 0, invalidArchive: true)
            return
        }
        let lang = self.presentationData.strings.primaryComponent.languageCode
        let controller = MolteagramPhoneAccountImportSelectionController(accounts: accounts, languageCode: lang, importAction: { [weak self] selectedIds in
            guard let self else {
                return
            }
            let result = self.performMolteagramAccountsImport(url: localUrl, selectedRecordIds: selectedIds)
            self.presentMolteagramImportResult(imported: result.imported, skipped: result.skipped, invalidArchive: result.invalidArchive)
        })
        let navigationController = UINavigationController(rootViewController: controller)
        self.present(navigationController, animated: true)
    }
    
    private func presentMolteagramImportResult(imported: Int, skipped: Int, invalidArchive: Bool) {
        let message: String
        let lang = self.presentationData.strings.primaryComponent.languageCode
        if invalidArchive {
            message = MolteagramStrings.get("Molteagram.AccountsImportInvalidArchive", languageCode: lang)
        } else {
            message = String(format: MolteagramStrings.get("Molteagram.AccountsImportResult", languageCode: lang), imported, skipped)
        }
        let alertController = UIAlertController(title: MolteagramStrings.get("Molteagram.Accounts", languageCode: lang), message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: self.presentationData.strings.Common_OK, style: .default, handler: nil))
        self.present(alertController, animated: true)
    }
    
    private func inspectMolteagramAccountsArchive(url: URL) -> [MolteagramPhoneSelectableAccount] {
        let importRoot = NSTemporaryDirectory() + "molaccs_phone_inspect_" + UUID().uuidString
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: importRoot)
        try? fileManager.createDirectory(atPath: importRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(atPath: importRoot)
        }
        
        guard SSZipArchive.unzipFile(atPath: url.path, toDestination: importRoot), let manifestData = try? Data(contentsOf: URL(fileURLWithPath: importRoot + "/manifest.json")), let manifest = try? JSONDecoder().decode(MolteagramPhoneAccountArchiveManifest.self, from: manifestData), manifest.version == 1, !manifest.accounts.isEmpty else {
            return []
        }
        
        let existingRecordIdsSignal = self.sharedContext.accountManager.transaction { transaction -> Set<AccountRecordId> in
            return Set(transaction.getRecords().map(\.id))
        }
        var existingRecordIds = Set<AccountRecordId>()
        let recordsSemaphore = DispatchSemaphore(value: 0)
        let _ = (existingRecordIdsSignal |> take(1)).startStandalone(next: { ids in
            existingRecordIds = ids
            recordsSemaphore.signal()
        })
        recordsSemaphore.wait()
        
        var existingUserIds = Set<Int64>()
        let accountsSemaphore = DispatchSemaphore(value: 0)
        let _ = (self.sharedContext.activeAccountContexts |> take(1)).startStandalone(next: { value in
            let (_, activeAccounts, _) = value
            existingUserIds = Set(activeAccounts.map { $0.1.account.peerId.toInt64() })
            accountsSemaphore.signal()
        })
        accountsSemaphore.wait()
        
        let lang = self.presentationData.strings.primaryComponent.languageCode
        return manifest.accounts.map { item in
            let recordId = item.record.id
            let expectedFolderName = accountRecordIdPathName(recordId)
            let sourcePath = importRoot + "/accounts/" + item.folderName
            let structurallyValid = item.recordId == recordId.int64 && item.userId != 0 && item.folderName == expectedFolderName && !item.folderName.contains("/") && fileManager.fileExists(atPath: sourcePath + "/postbox")
            let duplicate = existingRecordIds.contains(recordId) || existingUserIds.contains(item.userId)
            let enabled = structurallyValid && !duplicate
            let userIdPrefix = MolteagramStrings.get("Molteagram.AccountsUserIdPrefix", languageCode: lang)
            let status: String
            if duplicate {
                status = "\(userIdPrefix) \(item.userId) • \(MolteagramStrings.get("Molteagram.AccountsDuplicate", languageCode: lang))"
            } else if !structurallyValid {
                status = "\(userIdPrefix) \(item.userId) • \(MolteagramStrings.get("Molteagram.AccountsInvalid", languageCode: lang))"
            } else {
                status = "\(userIdPrefix) \(item.userId)"
            }
            return MolteagramPhoneSelectableAccount(recordId: recordId, userId: item.userId, title: item.title, status: status, folderName: item.folderName, record: item.record, enabled: enabled)
        }
    }
    
    private func performMolteagramAccountsImport(url: URL, selectedRecordIds: Set<Int64>) -> (imported: Int, skipped: Int, invalidArchive: Bool, firstImportedId: AccountRecordId?) {
        let rootPath = self.sharedContext.basePath
        let importRoot = NSTemporaryDirectory() + "molaccs_phone_import_" + UUID().uuidString
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: importRoot)
        try? fileManager.createDirectory(atPath: importRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(atPath: importRoot)
        }
        
        guard SSZipArchive.unzipFile(atPath: url.path, toDestination: importRoot), let manifestData = try? Data(contentsOf: URL(fileURLWithPath: importRoot + "/manifest.json")), let manifest = try? JSONDecoder().decode(MolteagramPhoneAccountArchiveManifest.self, from: manifestData), manifest.version == 1, !manifest.accounts.isEmpty else {
            return (0, 0, true, nil)
        }
        
        let existingRecordIdsSignal = self.sharedContext.accountManager.transaction { transaction -> Set<AccountRecordId> in
            return Set(transaction.getRecords().map(\.id))
        }
        var existingRecordIds = Set<AccountRecordId>()
        let recordsSemaphore = DispatchSemaphore(value: 0)
        let _ = (existingRecordIdsSignal |> take(1)).startStandalone(next: { ids in
            existingRecordIds = ids
            recordsSemaphore.signal()
        })
        recordsSemaphore.wait()
        
        var existingUserIds = Set<Int64>()
        let accountsSemaphore = DispatchSemaphore(value: 0)
        let _ = (self.sharedContext.activeAccountContexts |> take(1)).startStandalone(next: { value in
            let (_, activeAccounts, _) = value
            existingUserIds = Set(activeAccounts.map { $0.1.account.peerId.toInt64() })
            accountsSemaphore.signal()
        })
        accountsSemaphore.wait()
        
        var importedUserIds = Set<Int64>()
        var importedRecords: [(AccountRecordId, AccountRecord<TelegramAccountRecordAttribute>)] = []
        var imported = 0
        var skipped = 0
        var firstImportedId: AccountRecordId?
        for item in manifest.accounts {
            let recordId = item.record.id
            guard selectedRecordIds.contains(recordId.int64) else {
                continue
            }
            let expectedFolderName = accountRecordIdPathName(recordId)
            let sourcePath = importRoot + "/accounts/" + item.folderName
            let destinationPath = rootPath + "/" + expectedFolderName
            let structurallyValid = item.recordId == recordId.int64 && item.userId != 0 && item.folderName == expectedFolderName && !item.folderName.contains("/") && fileManager.fileExists(atPath: sourcePath + "/postbox")
            guard structurallyValid, !existingRecordIds.contains(recordId), !existingUserIds.contains(item.userId), !importedUserIds.contains(item.userId), !fileManager.fileExists(atPath: destinationPath) else {
                skipped += 1
                continue
            }
            do {
                try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                existingRecordIds.insert(recordId)
                importedUserIds.insert(item.userId)
                importedRecords.append((recordId, item.record))
                if firstImportedId == nil {
                    firstImportedId = recordId
                }
                imported += 1
            } catch {
                skipped += 1
            }
        }
        
        if let firstImportedId, !importedRecords.isEmpty {
            let _ = (self.sharedContext.accountManager.transaction { transaction -> Void in
                for (recordId, record) in importedRecords {
                    transaction.updateRecord(recordId, { _ in
                        return record
                    })
                }
                transaction.setCurrentId(firstImportedId)
                transaction.removeAuth()
            }).startStandalone()
        }
        
        return (imported, skipped, false, firstImportedId)
    }
    
    private func loadAndPresentPasskey(force: Bool) {
        if #available(iOS 16.0, *) {
            Task { @MainActor [weak self] in
                guard let self, let account = self.account else {
                    return
                }
                
                let decodeBase64: (String) -> Data? = { string in
                    var string = string.replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
                    while string.count % 4 != 0 {
                        string.append("=")
                    }
                    return Data(base64Encoded: string)
                }
                
                let engine = TelegramEngineUnauthorized(account: account)
                let passkeyDataString = await engine.auth.requestPasskeyLoginData(apiId: self.apiId, apiHash: self.apiHash).get()
                guard let passkeyDataString, let passkeyData = passkeyDataString.data(using: .utf8) else {
                    return
                }
                guard let params = try? JSONSerialization.jsonObject(with: passkeyData) as? [String: Any] else {
                    return
                }
                guard let pkDict = params["publicKey"] as? [String: Any] else {
                    return
                }
                guard let relyingPartyIdentifier = pkDict["rpId"] as? String else {
                    return
                }
                guard let challengeBase64 = pkDict["challenge"] as? String else {
                    return
                }
                guard let challengeData = decodeBase64(challengeBase64) else {
                    return
                }
                
                let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyIdentifier)
                let platformKeyRequest = platformProvider.createCredentialAssertionRequest(challenge: challengeData)
                let authController = ASAuthorizationController(authorizationRequests: [platformKeyRequest])
                authController.delegate = self
                authController.presentationContextProvider = self
                if force {
                    authController.performRequests()
                } else {
                    authController.performRequests(options: [.preferImmediatelyAvailableCredentials])
                }
            }
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor [weak self] in
            guard let self, let account = self.account else {
                return
            }
            
            let encodeBase64URL: (Data) -> String = { data in
                var string = data.base64EncodedString()
                string = string
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                string = string.replacingOccurrences(of: "=", with: "")
                return string
            }
            
            if #available(iOS 17.0, *) {
                if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                    guard let clientData = String(data: credential.rawClientDataJSON, encoding: .utf8) else {
                        return
                    }
                    guard let userHandle = String(data: credential.userID, encoding: .utf8) else {
                        return
                    }
                    let passkey = AuthorizationPasskeyData(
                        id: encodeBase64URL(credential.credentialID),
                        clientData: clientData,
                        authenticatorData: credential.rawAuthenticatorData,
                        signature: credential.signature,
                        userHandle: userHandle
                    )
                    self.loginWithPasskey?(passkey, self.controllerNode.syncContacts)
                    
                    /*if let clientData = String(data: credential.rawClientDataJSON, encoding: .utf8), let attestationObject = credential.rawAttestationObject {
                        let passkey = await component.context.engine.auth.requestCreatePasskey(id: encodeBase64URL(credential.credentialID), clientData: clientData, attestationObject: attestationObject).get()
                        if let passkey {
                            if self.passkeysData == nil {
                                self.passkeysData = []
                                self.passkeysData?.insert(passkey, at: 0)
                            }
                            self.state?.updated(transition: .immediate)
                        }
                    }*/
                    let _ = account
                    let _ = credential
                }
            }
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        if (error as NSError).domain == "com.apple.AuthenticationServices.AuthorizationError" && (error as NSError).code == 1001 {
            self.controllerNode.updateDisplayPasskeyLoginOption()
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout, transition: .immediate)
            }
        }
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = self.view.window?.windowScene else {
            preconditionFailure()
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }
    
    public func updateCountryCode() {
        self.controllerNode.updateCountryCode()
    }
    
    private var animatingIn = false
    
    private func startTransitionInIfNeeded() {
        guard self.shouldAnimateIn, !self.didStartTransitionIn else {
            return
        }
        guard let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments else {
            self.shouldAnimateIn = false
            self.animatingIn = false
            self.controllerNode.activateInput()
            return
        }
        
        self.shouldAnimateIn = false
        self.didStartTransitionIn = true
        self.controllerNode.animateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
        Queue.mainQueue().after(0.45) { [weak self] in
            guard let self else {
                return
            }
            self.animatingIn = false
            self.controllerNode.completeTransitionIn()
            self.controllerNode.activateInput()
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.shouldAnimateIn {
            self.animatingIn = true
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.controllerNode.willAnimateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
            }
            Queue.mainQueue().justDispatch {
                self.controllerNode.activateInput()
            }
        } else {
            self.controllerNode.activateInput()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatingIn {
            self.controllerNode.activateInput()
        } else {
            Queue.mainQueue().after(0.25) { [weak self] in
                self?.startTransitionInIfNeeded()
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let confirmationController = self.confirmationController {
            confirmationController.transitionOut()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
    
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if self.shouldAnimateIn, let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            self.startTransitionInIfNeeded()
        }
    }
    
    public func dismissConfirmation() {
        self.confirmationController?.dismissAnimated()
        self.confirmationController = nil
    }
    
    @objc func nextPressed() {
        guard self.confirmationController == nil else {
            return
        }
        let (_, _, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            let logInNumber = cleanPhoneNumber(self.controllerNode.currentNumber, removePlus: true)
            var existing: (String, AccountRecordId)?
            for (number, id, isTestingEnvironment) in self.otherAccountPhoneNumbers.1 {
                if isTestingEnvironment == self.isTestingEnvironment && cleanPhoneNumber(number, removePlus: true) == logInNumber {
                    existing = (number, id)
                }
            }
            
            if let (_, id) = existing {
                var actions: [TextAlertAction] = []
                if let (current, _, _) = self.otherAccountPhoneNumbers.0, logInNumber != cleanPhoneNumber(current, removePlus: true) {
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorizedSwitch, action: { [weak self] in
                        self?.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
                        self?.back()
                    }))
                }
                actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {}))
                self.present(textAlertController(sharedContext: self.sharedContext, title: nil, text: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorized, actions: actions), in: .window(.root))
            } else {
                if let validLayout = self.validLayout, validLayout.size.width > 320.0 {
                    let (code, formattedNumber) = self.controllerNode.formattedCodeAndNumber

                    let confirmationController = PhoneConfirmationController(theme: self.presentationData.theme, strings: self.presentationData.strings, code: code, number: formattedNumber, sourceController: self)
                    confirmationController.proceed = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loginWithNumber?(strongSelf.controllerNode.currentNumber, strongSelf.controllerNode.syncContacts)
                        }
                    }
                    (self.navigationController as? NavigationController)?.presentOverlay(controller: confirmationController, inGlobal: true, blockInteraction: true)
                    self.confirmationController = confirmationController
                } else {
                    var actions: [TextAlertAction] = []
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_Edit, action: {}))
                    actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Login_Yes, action: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loginWithNumber?(strongSelf.controllerNode.currentNumber, strongSelf.controllerNode.syncContacts)
                        }
                    }))
                    self.present(textAlertController(sharedContext: self.sharedContext, title: logInNumber, text: self.presentationData.strings.Login_PhoneNumberConfirmation, actions: actions), in: .window(.root))
                }
            }
        } else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
