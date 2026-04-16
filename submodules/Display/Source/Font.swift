import Foundation
import UIKit
import MolteagramCore

public struct Font {
    public enum Design {
        case regular
        case serif
        case monospace
        case round
        case camera
        
        var key: String {
            switch self {
            case .regular:
                return "regular"
            case .serif:
                return "serif"
            case .monospace:
                return "monospace"
            case .round:
                return "round"
            case .camera:
                return "camera"
            }
        }
    }
    
    public struct Traits: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let italic = Traits(rawValue: 1 << 0)
        public static let monospacedNumbers = Traits(rawValue: 1 << 1)
    }
    
    public enum Width {
        case standard
        case condensed
        case compressed
        case expanded
        
        @available(iOS 16.0, *)
        var width: UIFont.Width {
            switch self {
            case .standard:
                return .standard
            case .condensed:
                return .condensed
            case .compressed:
                return .compressed
            case .expanded:
                return .expanded
            }
        }
        
        var key: String {
            switch self {
            case .standard:
                return "standard"
            case .condensed:
                return "condensed"
            case .compressed:
                return "compressed"
            case .expanded:
                return "expanded"
            }
        }
    }
    
    public enum Weight {
        case regular
        case thin
        case light
        case medium
        case semibold
        case bold
        case heavy
        
        var isBold: Bool {
            switch self {
                case .medium, .semibold, .bold, .heavy:
                    return true
                default:
                    return false
            }
        }
        
        public init(_ value: CGFloat) {
            self.init(UIFont.Weight(value))
        }

        public init(_ weight: UIFont.Weight) {
            if weight == .thin {
                self = .thin
            } else if weight == .light {
                self = .light
            } else if weight == .medium {
                self = .medium
            } else if weight == .semibold {
                self = .semibold
            } else if weight == .bold {
                self = .bold
            } else if weight == .heavy {
                self = .heavy
            } else {
                self = .regular
            }
        }
        
        var weight: UIFont.Weight {
            switch self {
                case .thin:
                    return .thin
                case .light:
                    return .light
                case .medium:
                    return .medium
                case .semibold:
                    return .semibold
                case .bold:
                    return .bold
                case .heavy:
                    return .heavy
                default:
                    return .regular
            }
        }
        
        var key: String {
            switch self {
            case .regular:
                return "regular"
            case .thin:
                return "thin"
            case .light:
                return "light"
            case .medium:
                return "medium"
            case .semibold:
                return "semibold"
            case .bold:
                return "bold"
            case .heavy:
                return "heavy"
            }
        }
    }
    
    private final class Cache {
        private var lock: pthread_rwlock_t
        private var fonts: [String: UIFont] = [:]
        
        init() {
            self.lock = pthread_rwlock_t()
            let status = pthread_rwlock_init(&self.lock, nil)
            assert(status == 0)
        }
        
        func get(_ key: String) -> UIFont? {
            let font: UIFont?
            pthread_rwlock_rdlock(&self.lock)
            font = self.fonts[key]
            pthread_rwlock_unlock(&self.lock)
            return font
        }
        
        func set(_ font: UIFont, key: String) {
            pthread_rwlock_wrlock(&self.lock)
            self.fonts[key] = font
            pthread_rwlock_unlock(&self.lock)
        }
        
        func clear() {
            pthread_rwlock_wrlock(&self.lock)
            self.fonts.removeAll()
            pthread_rwlock_unlock(&self.lock)
        }
    }

    private static let cache = Cache()
    
    /// Call when custom font settings change to invalidate the cache.
    public static func clearCache() {
        cache.clear()
        _cachedFontSettings = nil
    }
    
    // MARK: - Custom font lookup
    
    private static var _cachedFontSettings: MolteagramFontSettings?
    
    private static func customFontSettings() -> MolteagramFontSettings {
        if let cached = _cachedFontSettings {
            return cached
        }
        let settings = MolteagramFontSettings.load()
        _cachedFontSettings = settings
        return settings
    }
    
    /// Try to get a custom font for the given category and weight.
    /// Returns nil if no custom font is set → caller should fall back to default.
    private static func customFont(category: MolteagramFontCategory, weight: MolteagramFontWeight, size: CGFloat) -> UIFont? {
        let settings = customFontSettings()
        guard let name = settings.fontName(for: category, weight: weight) else { return nil }
        if let font = UIFont(name: name, size: size), font.fontName == name, font.familyName != ".LastResort" {
            let wghtValue = MolteagramFontSettings.wghtValue(for: weight)
            let wghtTag = 0x77676874
            let variationDescriptor = font.fontDescriptor.addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): [wghtTag: wghtValue]
            ])
            return UIFont(descriptor: variationDescriptor, size: size)
        }
        return nil
    }
    
    /// Map Font.Weight + Traits to MolteagramFontWeight.
    private static func molteagramWeight(from weight: Weight, traits: Traits) -> MolteagramFontWeight {
        if traits.contains(.italic) {
            return weight.isBold ? .boldItalic : .italic
        }
        switch weight {
        case .thin:     return .thin
        case .light:    return .light
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        case .heavy:    return .heavy
        }
    }
    
    /// Map Font.Design to MolteagramFontCategory.
    private static func molteagramCategory(from design: Design) -> MolteagramFontCategory? {
        switch design {
        case .regular:  return .system
        case .serif:    return .serif
        case .monospace: return .monospace
        case .round:    return .round
        case .camera:   return nil  // never customizable
        }
    }
    
    public static func with(size: CGFloat, design: Design = .regular, weight: Weight = .regular, width: Width = .standard, traits: Traits = []) -> UIFont {
        let key = "\(size)_\(design.key)_\(weight.key)_\(width.key)_\(traits.rawValue)"
        
        if let cachedFont = self.cache.get(key) {
            return cachedFont
        }
        // Try custom font override
        if let category = molteagramCategory(from: design) {
            let mWeight = molteagramWeight(from: weight, traits: traits)
            if let customFont = customFont(category: category, weight: mWeight, size: size) {
                self.cache.set(customFont, key: key)
                return customFont
            }
        }
        if #available(iOS 13.0, *), design != .camera {
            let descriptor: UIFontDescriptor
            if #available(iOS 14.0, *) {
                descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            } else {
                descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor
            }

            var symbolicTraits = descriptor.symbolicTraits
            if traits.contains(.italic) {
                symbolicTraits.insert(.traitItalic)
            }
            var updatedDescriptor: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolicTraits)
            if traits.contains(.monospacedNumbers) {
                updatedDescriptor = updatedDescriptor?.addingAttributes([
                UIFontDescriptor.AttributeName.featureSettings: [
                  [UIFontDescriptor.FeatureKey.featureIdentifier:
                   kNumberSpacingType,
                   UIFontDescriptor.FeatureKey.typeIdentifier:
                   kMonospacedNumbersSelector]
                ]])
            }
            switch design {
                case .serif:
                    updatedDescriptor = updatedDescriptor?.withDesign(.serif)
                case .monospace:
                    updatedDescriptor = updatedDescriptor?.withDesign(.monospaced)
                case .round:
                    updatedDescriptor = updatedDescriptor?.withDesign(.rounded)
                default:
                    updatedDescriptor = updatedDescriptor?.withDesign(.default)
            }
            if #available(iOS 14.0, *) {
                if weight != .regular {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight.weight]
                    ])
                }
            }
            if #available(iOS 16.0, *) {
                if width != .standard {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.width: width.width]
                    ])
                }
            }
            
            let font: UIFont
            if let updatedDescriptor = updatedDescriptor {
                font = UIFont(descriptor: updatedDescriptor, size: size)
            } else {
                font = UIFont(descriptor: descriptor, size: size)
            }
            
            self.cache.set(font, key: key)
            
            return font
        } else {
            let font: UIFont
            switch design {
                case .regular:
                    if traits.contains(.italic) {
                        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight.weight).fontDescriptor.withSymbolicTraits([.traitItalic]) {
                            font = UIFont(descriptor: descriptor, size: size)
                        } else {
                            font = UIFont.italicSystemFont(ofSize: size)
                        }
                    } else {
                        return UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
                case .serif:
                    if weight.isBold && traits.contains(.italic) {
                        font = UIFont(name: "Georgia-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        font = UIFont(name: "Georgia-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        font = UIFont(name: "Georgia-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        font = UIFont(name: "Georgia", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .monospace:
                    if weight.isBold && traits.contains(.italic) {
                        font = UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if weight.isBold {
                        font = UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else if traits.contains(.italic) {
                        font = UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    } else {
                        font = UIFont(name: "Menlo", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
                    }
                case .round:
                    font = UIFont(name: ".SFCompactRounded-Semibold", size: size) ?? UIFont.systemFont(ofSize: size)
                case .camera:
                    func encodeText(string: String, key: Int16) -> String {
                        let nsString = string as NSString
                        let result = NSMutableString()
                        for i in 0 ..< nsString.length {
                            var c: unichar = nsString.character(at: i)
                            c = unichar(Int16(c) + key)
                            result.append(NSString(characters: &c, length: 1) as String)
                        }
                        return result as String
                    }
                    if case .semibold = weight {
                        font = UIFont(name: encodeText(string: "TGDbnfsb.Tfnjcpme", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    } else {
                        font = UIFont(name: encodeText(string: "TGDbnfsb.Sfhvmbs", key: -1), size: size) ?? UIFont.systemFont(ofSize: size, weight: weight.weight)
                    }
            }
            
            self.cache.set(font, key: key)
            
            return font
        }
    }
    
    public static func regular(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .regular, size: size) { return custom }
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .medium, size: size) { return custom }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.medium)
    }
    
    public static func semibold(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .semibold, size: size) { return custom }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.semibold)
    }
    
    public static func bold(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .bold, size: size) { return custom }
        if #available(iOS 8.2, *) {
            return UIFont.boldSystemFont(ofSize: size)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        }
    }
    
    public static func heavy(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .heavy, size: size) { return custom }
        return self.with(size: size, design: .regular, weight: .heavy, traits: [])
    }
    
    public static func light(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .light, size: size) { return custom }
        return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.light)
    }
    
    public static func semiboldItalic(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .boldItalic, size: size) { return custom }
        if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.italicSystemFont(ofSize: size)
        }
    }
    
    public static func monospace(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .monospace, weight: .regular, size: size - 1.0) { return custom }
        return UIFont(name: "Menlo-Regular", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldMonospace(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .monospace, weight: .bold, size: size - 1.0) { return custom }
        return UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italicMonospace(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .monospace, weight: .italic, size: size - 1.0) { return custom }
        return UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldItalicMonospace(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .monospace, weight: .boldItalic, size: size - 1.0) { return custom }
        return UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        if let custom = customFont(category: .system, weight: .italic, size: size) { return custom }
        return UIFont.italicSystemFont(ofSize: size)
    }
    public static func with(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let weightEnum: MolteagramFontWeight
        if weight == .thin { weightEnum = .thin }
        else if weight == .ultraLight { weightEnum = .thin }
        else if weight == .light { weightEnum = .light }
        else if weight == .medium { weightEnum = .medium }
        else if weight == .semibold { weightEnum = .semibold }
        else if weight == .bold { weightEnum = .bold }
        else if weight == .heavy { weightEnum = .heavy }
        else if weight == .black { weightEnum = .heavy }
        else { weightEnum = .regular }
        
        if let custom = customFont(category: .system, weight: weightEnum, size: size) { return custom }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont? = nil, textColor: UIColor = UIColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }
}
