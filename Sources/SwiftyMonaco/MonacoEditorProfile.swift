import Foundation
#if !os(macOS)
import UIKit
#endif

public struct MonacoEditorProfile: Equatable {
    public var documentPath: String?
    public var syntax: SyntaxHighlight?

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

    public init(
        documentPath: String? = nil,
        syntax: SyntaxHighlight? = nil,
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
        theme: Theme? = nil
    ) {
        self.documentPath = documentPath
        self.syntax = syntax
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

    public func documentPath(_ path: String?) -> Self {
        var copy = self
        copy.profile.documentPath = path
        return copy
    }

    public func syntax(_ syntax: SyntaxHighlight?) -> Self {
        var copy = self
        copy.profile.syntax = syntax
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
    case light, dark

    static func detectSystemDefault() -> Theme {
        #if os(macOS)
        return (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark") ? .dark : .light
        #else
        return (UITraitCollection.current.userInterfaceStyle == .dark) ? .dark : .light
        #endif
    }
}
