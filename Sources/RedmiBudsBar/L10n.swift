import Foundation
import Observation

/// Runtime language selection. UI strings use their English text as key and are looked up in the chosen
/// `.lproj` of the resource bundle, so the language can change live without restarting the app.
@Observable
final class Localizer: @unchecked Sendable {
    enum Choice: String, CaseIterable {
        case system
        case english = "en"
        case spanish = "es"
    }

    static let shared = Localizer()
    private static let defaultsKey = "appLanguage"
    static let supported = ["en", "es"]

    var choice: Choice {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: Self.defaultsKey)
            reload()
        }
    }

    private(set) var bundle: Bundle = .main
    private(set) var locale: Locale = .current

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        choice = stored.flatMap(Choice.init(rawValue:)) ?? .system
        reload()
    }

    /// The language code actually in use (`en` or `es`).
    var resolvedLanguage: String {
        switch choice {
        case .english, .spanish:
            return choice.rawValue
        case .system:
            for identifier in Locale.preferredLanguages {
                let code = Locale(identifier: identifier).language.languageCode?.identifier ?? ""
                if Self.supported.contains(code) { return code }
            }
            return "en"
        }
    }

    private func reload() {
        let language = resolvedLanguage
        locale = Locale(identifier: language)
        if let resources = Self.resourceBundle(),
           let path = resources.path(forResource: language, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = .main
        }
    }

    /// The SwiftPM resource bundle is copied into `Contents/Resources` by `build-app.sh`.
    /// `Bundle.module` is only used as a development fallback (`swift run`), where it resolves to the build directory.
    private static func resourceBundle() -> Bundle? {
        if let url = Bundle.main.url(forResource: "RedmiBudsBar_RedmiBudsBar", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        #if DEBUG
        return Bundle.module
        #else
        return nil
        #endif
    }
}

/// Looks up `key` (the English text) in the active language; formats `%` placeholders with `args`.
func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = Localizer.shared.bundle.localizedString(forKey: key, value: key, table: nil)
    return args.isEmpty ? format : String(format: format, locale: Localizer.shared.locale, arguments: args)
}
