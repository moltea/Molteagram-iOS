import Foundation
import UIKit
import CoreText
import ZipArchive

public enum MolteagramFontWeight: String, CaseIterable, Codable {
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case light
    case thin
    case italic
    case boldItalic
    
    public var displayName: String {
        switch self {
        case .regular:    return "Regular"
        case .medium:     return "Medium"
        case .semibold:   return "Semibold"
        case .bold:       return "Bold"
        case .heavy:      return "Heavy"
        case .light:      return "Light"
        case .thin:       return "Thin"
        case .italic:     return "Italic"
        case .boldItalic: return "Bold Italic"
        }
    }
}

public enum MolteagramFontCategory: String, CaseIterable, Codable {
    case system
    case monospace
    case serif
    case round
    
    public var supportedWeights: [MolteagramFontWeight] {
        switch self {
        case .system:
            return [.regular, .medium, .semibold, .bold, .heavy, .light, .thin, .italic, .boldItalic]
        case .monospace:
            return [.regular, .bold, .italic, .boldItalic]
        case .serif:
            return [.regular, .bold, .italic, .boldItalic]
        case .round:
            return [.semibold]
        }
    }
}

public struct MolteagramFontSettings: Codable, Equatable {
    public var fontNames: [String: String]
    
    public init(fontNames: [String: String] = [:]) {
        self.fontNames = fontNames
    }
    
    public static let `default` = MolteagramFontSettings()
    
    public func fontName(for category: MolteagramFontCategory, weight: MolteagramFontWeight) -> String? {
        return fontNames[Self.key(category, weight)]
    }
    
    public mutating func setFontName(_ name: String?, for category: MolteagramFontCategory, weight: MolteagramFontWeight) {
        fontNames[Self.key(category, weight)] = name
    }
    
    public mutating func clearAll() {
        fontNames.removeAll()
    }
    
    private static func key(_ category: MolteagramFontCategory, _ weight: MolteagramFontWeight) -> String {
        return "\(category.rawValue).\(weight.rawValue)"
    }
    
    private static let userDefaultsKey = "MolteagramFontSettings"
    
    private static var _groupDefaults: UserDefaults? = {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let suffix = ".NotificationService"
        let baseId = bundleId.hasSuffix(suffix) ? String(bundleId.dropLast(suffix.count)) : bundleId
        return UserDefaults(suiteName: "group.\(baseId)")
    }()
    
    public static func load() -> MolteagramFontSettings {
        guard let defaults = _groupDefaults,
              let data = defaults.data(forKey: userDefaultsKey) else {
            return .default
        }
        return (try? JSONDecoder().decode(MolteagramFontSettings.self, from: data)) ?? .default
    }
    
    public func save() {
        guard let defaults = Self._groupDefaults,
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
    
    public static var fontsDirectoryURL: URL? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let suffix = ".NotificationService"
        let baseId = bundleId.hasSuffix(suffix) ? String(bundleId.dropLast(suffix.count)) : bundleId
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(baseId)") else { return nil }
        return containerURL.appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MolteagramFonts", isDirectory: true)
    }
    
    public static func fileName(for category: MolteagramFontCategory, weight: MolteagramFontWeight, ext: String = "ttf") -> String {
        return "\(category.rawValue).\(weight.rawValue).\(ext)"
    }
    
    public static func fileURL(for category: MolteagramFontCategory, weight: MolteagramFontWeight, ext: String = "ttf") -> URL? {
        return fontsDirectoryURL?.appendingPathComponent(fileName(for: category, weight: weight, ext: ext))
    }
    
    @discardableResult
    public static func importFont(from sourceURL: URL, category: MolteagramFontCategory, weight: MolteagramFontWeight) -> String? {
        guard let fontsDir = fontsDirectoryURL else { return nil }
        
        try? FileManager.default.createDirectory(at: fontsDir, withIntermediateDirectories: true)
        
        let ext = sourceURL.pathExtension.lowercased()
        let validExt = (ext == "otf" || ext == "ttf") ? ext : "ttf"
        
        let destURL = fontsDir.appendingPathComponent(fileName(for: category, weight: weight, ext: validExt))
        
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                deleteFont(for: category, weight: weight)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: destURL.path)
        } catch {
            return nil
        }
        
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(destURL as CFURL, .process, &error)
        
        guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(destURL as CFURL) as? [CTFontDescriptor],
              let firstDescriptor = fontDescriptors.first,
              let postScriptName = CTFontDescriptorCopyAttribute(firstDescriptor, kCTFontNameAttribute) as? String else {
            try? FileManager.default.removeItem(at: destURL)
            return nil
        }
        
        var settings = load()
        settings.setFontName(postScriptName, for: category, weight: weight)
        settings.save()
        return postScriptName
    }
    
    public static func deleteFont(for category: MolteagramFontCategory, weight: MolteagramFontWeight) {
        guard let fontsDir = fontsDirectoryURL else { return }
        for ext in ["ttf", "otf"] {
            let url = fontsDir.appendingPathComponent(fileName(for: category, weight: weight, ext: ext))
            if FileManager.default.fileExists(atPath: url.path) {
                var error: Unmanaged<CFError>?
                CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &error)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    public static func resetAll() {
        if let fontsDir = fontsDirectoryURL {
            if let files = try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil) {
                for file in files {
                    var error: Unmanaged<CFError>?
                    CTFontManagerUnregisterFontsForURL(file as CFURL, .process, &error)
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
        
        var settings = MolteagramFontSettings()
        settings.save()
    }
    
    public static func registerAllCustomFonts() {
        guard let fontsDir = fontsDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            let ext = file.pathExtension.lowercased()
            if ext == "ttf" || ext == "otf" {
                var error: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(file as CFURL, .process, &error) {
                    // фолбек
                }
            }
        }
    }
    
    public static func wghtValue(for weight: MolteagramFontWeight) -> CGFloat {
        switch weight {
        case .thin:       return 100
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .italic:     return 400
        case .boldItalic: return 700
        }
    }
    
    public static func importFontPack(at url: URL) -> (imported: Int, skipped: Int, report: String) {
        let tempDir = NSTemporaryDirectory() + "molfonts_" + UUID().uuidString
        let fm = FileManager.default
        try? fm.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fm.removeItem(atPath: tempDir)
        }
        
        guard SSZipArchive.unzipFile(atPath: url.path, toDestination: tempDir) else {
            return (0, 0, "Failed to unzip archive.")
        }
        
        var importedCount = 0
        var skippedCount = 0
        var report = ""
        
        let categories: [(String, MolteagramFontCategory)] = [
            ("System", .system),
            ("Mono", .monospace),
            ("Serif", .serif),
            ("Round", .round)
        ]
        
        let weights: [(String, MolteagramFontWeight)] = [
            ("BoldItalic", .boldItalic),
            ("Italic", .italic),
            ("Thin", .thin),
            ("Light", .light),
            ("Regular", .regular),
            ("Medium", .medium),
            ("Semibold", .semibold),
            ("Bold", .bold),
            ("Heavy", .heavy)
        ]
        
        // Use an enumerator to find files recursively (in case of subfolders in zip)
        let enumerator = fm.enumerator(at: URL(fileURLWithPath: tempDir), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var files: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                files.append(fileURL)
            }
        }
        
        // Phase 1: Variable Fonts (e.g., SystemVariable.ttf)
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            let lowerName = fileName.lowercased()
            if !lowerName.hasSuffix(".ttf") && !lowerName.hasSuffix(".otf") {
                continue
            }
            
            for (catPrefix, category) in categories {
                if lowerName.hasPrefix(catPrefix.lowercased() + "variable") {
                    let psName = importFont(from: fileURL, category: category, weight: .regular)
                    if let psName = psName {
                        // Apply this same font (PS name) to ALL weights in the category as a base
                        var settings = load()
                        for weight in category.supportedWeights {
                            settings.setFontName(psName, for: category, weight: weight)
                        }
                        settings.save()
                        importedCount += 1
                        report += "✓ \(catPrefix) -> Variable (\(psName))\n"
                    } else {
                        report += "✗ \(catPrefix) -> Variable (Import failed)\n"
                    }
                }
            }
        }
        
        // Phase 2: Static Fonts (e.g., SystemBold.ttf) - these will override Variable fonts for specific weights
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            let lowerName = fileName.lowercased()
            if !lowerName.hasSuffix(".ttf") && !lowerName.hasSuffix(".otf") || lowerName.contains("variable") {
                continue
            }
            
            var matched = false
            for (catPrefix, category) in categories {
                if lowerName.hasPrefix(catPrefix.lowercased()) {
                    let remaining = fileName.dropFirst(catPrefix.count)
                    for (weightSuffix, weight) in weights {
                        if remaining.lowercased().hasPrefix(weightSuffix.lowercased()) {
                            if let psName = importFont(from: fileURL, category: category, weight: weight) {
                                importedCount += 1
                                matched = true
                                report += "✓ \(catPrefix) -> \(weightSuffix) (\(psName))\n"
                                break
                            } else {
                                report += "✗ \(catPrefix) -> \(weightSuffix) (Failed)\n"
                            }
                        }
                    }
                }
                if matched { break }
            }
            
            if !matched {
                skippedCount += 1
                report += "! Unknown file: \(fileName)\n"
            }
        }
        
        if report.isEmpty { report = "No supported fonts found." }
        return (importedCount, skippedCount, report)
    }
}
