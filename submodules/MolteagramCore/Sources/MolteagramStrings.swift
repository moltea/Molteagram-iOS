import Foundation

public struct MolteagramStrings {
    public static func get(_ key: String, languageCode: String) -> String {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            let translatedString = NSLocalizedString(key, tableName: "MolteagramLocalizable", bundle: languageBundle, value: "", comment: "")
            if translatedString != key && !translatedString.isEmpty {
                return translatedString
            }
        }
        if let fallbackPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let fallbackBundle = Bundle(path: fallbackPath) {
            return NSLocalizedString(key, tableName: "MolteagramLocalizable", bundle: fallbackBundle, value: key, comment: "")
        }
        return key
    }
}
