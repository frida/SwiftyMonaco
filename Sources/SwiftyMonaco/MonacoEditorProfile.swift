import Foundation
#if !os(macOS)
import UIKit
#endif

public struct MonacoEditorProfile: Equatable {
    public var syntax: SyntaxHighlight?
    public var projectFiles: [MonacoProjectFile]
    public var activePath: String?

    public var tsCompilerOptions: TypeScriptCompilerOptions?
    public var tsExtraLibs: [MonacoExtraLib]

    public var jsCompilerOptions: TypeScriptCompilerOptions?
    public var jsExtraLibs: [MonacoExtraLib]

    public var fsSnapshot: MonacoFSSnapshot?

    public var minimap: Bool
    public var scrollbar: Bool
    public var smoothCursor: Bool
    public var cursorBlink: CursorBlink
    public var fontSize: Int
    public var theme: Theme?
    public var customThemes: [MonacoCustomTheme]

    public init(
        syntax: SyntaxHighlight? = nil,
        projectFiles: [MonacoProjectFile] = [],
        activePath: String? = nil,
        tsCompilerOptions: TypeScriptCompilerOptions? = nil,
        tsExtraLibs: [MonacoExtraLib] = [],
        jsCompilerOptions: TypeScriptCompilerOptions? = nil,
        jsExtraLibs: [MonacoExtraLib] = [],
        fsSnapshot: MonacoFSSnapshot? = nil,
        minimap: Bool = true,
        scrollbar: Bool = true,
        smoothCursor: Bool = false,
        cursorBlink: CursorBlink = .blink,
        fontSize: Int = 12,
        theme: Theme? = nil,
        customThemes: [MonacoCustomTheme] = []
    ) {
        self.syntax = syntax
        self.projectFiles = projectFiles
        self.activePath = activePath
        self.tsCompilerOptions = tsCompilerOptions
        self.tsExtraLibs = tsExtraLibs
        self.jsCompilerOptions = jsCompilerOptions
        self.jsExtraLibs = jsExtraLibs
        self.fsSnapshot = fsSnapshot
        self.minimap = minimap
        self.scrollbar = scrollbar
        self.smoothCursor = smoothCursor
        self.cursorBlink = cursorBlink
        self.fontSize = fontSize
        self.theme = theme
        self.customThemes = customThemes
    }
}

public struct MonacoEditorProfileBuilder {
    private var profile: MonacoEditorProfile

    public init() {
        self.init(from: MonacoEditorProfile())
    }

    public init(from profile: MonacoEditorProfile) {
        self.profile = profile
    }

    public func build() -> MonacoEditorProfile {
        profile
    }

    public func syntax(_ syntax: SyntaxHighlight?) -> Self {
        var copy = self
        copy.profile.syntax = syntax
        return copy
    }

    public func projectFiles(_ files: [MonacoProjectFile]) -> Self {
        var copy = self
        copy.profile.projectFiles = files
        return copy
    }

    public func activePath(_ path: String?) -> Self {
        var copy = self
        copy.profile.activePath = path
        return copy
    }

    public func typescriptCompilerOptions(_ options: TypeScriptCompilerOptions?) -> Self {
        var copy = self
        copy.profile.tsCompilerOptions = options
        return copy
    }

    public func typescriptExtraLibs(_ libs: [MonacoExtraLib]) -> Self {
        var copy = self
        copy.profile.tsExtraLibs = libs
        return copy
    }

    public func javascriptCompilerOptions(_ options: TypeScriptCompilerOptions?) -> Self {
        var copy = self
        copy.profile.jsCompilerOptions = options
        return copy
    }

    public func javascriptExtraLibs(_ libs: [MonacoExtraLib]) -> Self {
        var copy = self
        copy.profile.jsExtraLibs = libs
        return copy
    }

    public func fsSnapshot(_ snapshot: MonacoFSSnapshot?) -> Self {
        var copy = self
        copy.profile.fsSnapshot = snapshot
        return copy
    }

    public func minimap(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.minimap = enabled
        return copy
    }

    public func scrollbar(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.scrollbar = enabled
        return copy
    }

    public func smoothCursor(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.smoothCursor = enabled
        return copy
    }

    public func cursorBlink(_ style: CursorBlink) -> Self {
        var copy = self
        copy.profile.cursorBlink = style
        return copy
    }

    public func fontSize(_ size: Int) -> Self {
        var copy = self
        copy.profile.fontSize = size
        return copy
    }

    public func theme(_ theme: Theme?) -> Self {
        var copy = self
        copy.profile.theme = theme
        return copy
    }

    public func customThemes(_ themes: [MonacoCustomTheme]) -> Self {
        var copy = self
        copy.profile.customThemes = themes
        return copy
    }
}

public struct MonacoProjectFile: Equatable, Hashable {
    public let path: String
    public let text: String
    public let languageId: String?

    public init(path: String, text: String, languageId: String? = nil) {
        self.path = path
        self.text = text
        self.languageId = languageId
    }
}

extension MonacoProjectFile {
    func toJavaScriptObjectLiteral() -> String {
        let escapedPath = path.replacingOccurrences(of: "'", with: "\\'")
        var parts = ["path: '\(escapedPath)'", "text: \(javaScriptUTF8Decode(text))"]
        if let languageId {
            let escapedLang = languageId.replacingOccurrences(of: "'", with: "\\'")
            parts.append("languageId: '\(escapedLang)'")
        }
        return "{ \(parts.joined(separator: ", ")) }"
    }
}

extension MonacoCustomTheme {
    func toJavaScriptArguments() -> String {
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        let rulesJSON = encodeJSON(rules.map(\.jsonRepresentation))
        let colorsJSON = encodeJSON(colors)
        return "'\(escapedName)', { base: '\(base.rawValue)', inherit: \(inherit), rules: \(rulesJSON), colors: \(colorsJSON) }"
    }
}

extension MonacoTokenRule {
    var jsonRepresentation: [String: String] {
        var dict: [String: String] = ["token": token]
        if let foreground { dict["foreground"] = foreground }
        if let background { dict["background"] = background }
        if let fontStyle { dict["fontStyle"] = fontStyle }
        return dict
    }
}

private func encodeJSON(_ value: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}

public struct MonacoFSSnapshot: Codable, Hashable {
    public var version: Int
    public var files: [MonacoFSSnapshotFile]

    public init(version: Int, files: [MonacoFSSnapshotFile]) {
        self.version = version
        self.files = files
    }

    public func withVersion(_ v: Int) -> MonacoFSSnapshot {
        MonacoFSSnapshot(version: v, files: files)
    }
}

public struct MonacoFSSnapshotFile: Codable, Hashable {
    public var path: String
    public var text: String

    public init(path: String, text: String) {
        self.path = path
        self.text = text
    }
}

public enum CursorBlink: Equatable {
    case blink, smooth, phase, expand, solid
}

public enum Theme: Equatable {
    case named(String)

    public static let light: Theme = .named("vs")
    public static let dark: Theme = .named("vs-dark")

    static func detectSystemDefault() -> Theme {
        #if os(macOS)
        return (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark") ? .dark : .light
        #else
        return (UITraitCollection.current.userInterfaceStyle == .dark) ? .dark : .light
        #endif
    }

    public var name: String {
        switch self {
        case .named(let name): return name
        }
    }
}

public struct MonacoCustomTheme: Equatable {
    public var name: String
    public var base: MonacoBaseTheme
    public var inherit: Bool
    public var rules: [MonacoTokenRule]
    public var colors: [String: String]

    public init(
        name: String,
        base: MonacoBaseTheme,
        inherit: Bool = true,
        rules: [MonacoTokenRule] = [],
        colors: [String: String] = [:]
    ) {
        self.name = name
        self.base = base
        self.inherit = inherit
        self.rules = rules
        self.colors = colors
    }
}

public enum MonacoBaseTheme: String, Equatable {
    case vs
    case vsDark = "vs-dark"
    case hcLight = "hc-light"
    case hcBlack = "hc-black"
}

public struct MonacoTokenRule: Equatable {
    public var token: String
    public var foreground: String?
    public var background: String?
    public var fontStyle: String?

    public init(token: String, foreground: String? = nil, background: String? = nil, fontStyle: String? = nil) {
        self.token = token
        self.foreground = foreground
        self.background = background
        self.fontStyle = fontStyle
    }
}
