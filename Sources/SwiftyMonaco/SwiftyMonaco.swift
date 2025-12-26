//
//  SwiftyMonaco.swift
//
//
//  Created by Pavel Kasila on 20.03.21.
//

import SwiftUI

#if os(macOS)
typealias ViewControllerRepresentable = NSViewControllerRepresentable
#else
typealias ViewControllerRepresentable = UIViewControllerRepresentable
#endif

public struct SwiftyMonaco: ViewControllerRepresentable {
    var text: Binding<String>
    var profile: MonacoEditorProfile
    var _introspector: MonacoIntrospector? = nil

    public init(text: Binding<String>, profile: MonacoEditorProfile = MonacoEditorProfile()) {
        self.text = text
        self.profile = profile
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    #if os(macOS)
    public func makeNSViewController(context: Context) -> MonacoViewController {
        return doMakeViewController(context: context)
    }

    public func updateNSViewController(_ nsViewController: MonacoViewController, context: Context) {
        doUpdateViewController(nsViewController, coordinator: context.coordinator)
    }
    #endif

    #if os(iOS)
    public func makeUIViewController(context: Context) -> MonacoViewController {
        return doMakeViewController(context: context)
    }

    public func updateUIViewController(_ uiViewController: MonacoViewController, context: Context) {
        doUpdateViewController(uiViewController, coordinator: context.coordinator)
    }
    #endif

    private func doMakeViewController(context: Context) -> MonacoViewController {
        let vc = MonacoViewController()
        vc.delegate = context.coordinator
        _introspector?.controller = vc
        return vc
    }

    private func doUpdateViewController(_ viewController: MonacoViewController, coordinator: Coordinator) {
        coordinator.parent = self

        let newText = text.wrappedValue
        let newProfile = profile

        if coordinator.lastKnownText != newText || coordinator.lastKnownProfile != newProfile {
            coordinator.lastKnownText = newText
            coordinator.lastKnownProfile = newProfile
            viewController.reconfigure()
        }
    }
}

public extension SwiftyMonaco {
    static func prewarmPool(profile: MonacoEditorProfile, count: Int = 1) {
        MonacoWebViewPool.shared.prewarm(profile: profile, count: count)
    }
}

// MARK: - Modifiers
public extension SwiftyMonaco {
    func documentPath(_ path: String?) -> Self {
        var copy = self
        copy.profile.documentPath = path
        return copy
    }
}

public extension SwiftyMonaco {
    func syntaxHighlight(_ syntax: SyntaxHighlight) -> Self {
        var copy = self
        copy.profile.syntax = syntax
        return copy
    }
}

public extension SwiftyMonaco {
    public func introspector(_ introspector: MonacoIntrospector) -> Self {
        var copy = self
        copy._introspector = introspector
        return copy
    }
}

public extension SwiftyMonaco {
    func typescriptCompilerOptions(_ options: TypeScriptCompilerOptions) -> Self {
        var copy = self
        copy.profile.tsCompilerOptions = options
        return copy
    }
}

public extension SwiftyMonaco {
    func typescriptExtraLib(_ lib: String, named filePath: String) -> Self {
        var copy = self
        copy.profile.tsExtraLibs.append(MonacoExtraLib(lib, filePath: filePath))
        return copy
    }
}

public extension SwiftyMonaco {
    func javascriptCompilerOptions(_ options: TypeScriptCompilerOptions) -> Self {
        var copy = self
        copy.profile.jsCompilerOptions = options
        return copy
    }
}

public extension SwiftyMonaco {
    func javascriptExtraLib(_ lib: String, named filePath: String) -> Self {
        var copy = self
        copy.profile.jsExtraLibs.append(MonacoExtraLib(lib, filePath: filePath))
        return copy
    }
}

public extension SwiftyMonaco {
    func fsSnapshot(_ snapshot: MonacoFSSnapshot?) -> Self {
        var copy = self
        copy.profile.fsSnapshot = snapshot
        return copy
    }
}

public extension SwiftyMonaco {
    func minimap(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.minimap = enabled
        return copy
    }
}

public extension SwiftyMonaco {
    func scrollbar(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.scrollbar = enabled
        return copy
    }
}

public extension SwiftyMonaco {
    func smoothCursor(_ enabled: Bool) -> Self {
        var copy = self
        copy.profile.smoothCursor = enabled
        return copy
    }
}

public extension SwiftyMonaco {
    func cursorBlink(_ style: CursorBlink) -> Self {
        var copy = self
        copy.profile.cursorBlink = style
        return copy
    }
}

public extension SwiftyMonaco {
    func fontSize(_ size: Int) -> Self {
        var copy = self
        copy.profile.fontSize = size
        return copy
    }
}

public extension SwiftyMonaco {
    func theme(_ theme: Theme) -> Self {
        var copy = self
        copy.profile.theme = theme
        return copy
    }
}

@MainActor
public final class MonacoIntrospector: ObservableObject {
    fileprivate weak var controller: MonacoViewController?

    public init() {}

    public func topLevelSymbols() async -> [MonacoTopLevelSymbol] {
        guard let controller else {
            assertionFailure("MonacoIntrospector is not attached")
            return []
        }
        return await controller.topLevelSymbols()
    }
}

public struct MonacoTopLevelSymbol: Hashable {
    public let kind: MonacoSymbolKind
    public let text: String
}

public enum MonacoSymbolKind: String, Hashable, Codable {
    case `class`
    case function
    case `const`
    case `let`
    case `var`
}

public class Coordinator: NSObject, MonacoViewControllerDelegate {
    var parent: SwiftyMonaco
    var lastKnownText: String
    var lastKnownProfile: MonacoEditorProfile

    init(_ parent: SwiftyMonaco) {
        self.parent = parent
        self.lastKnownText = parent.text.wrappedValue
        self.lastKnownProfile = parent.profile
    }

    public func monacoView(getProfile controller: MonacoViewController) -> MonacoEditorProfile {
        let profile = parent.profile
        lastKnownProfile = profile
        return profile
    }

    public func monacoView(readText controller: MonacoViewController) -> String {
        let value = parent.text.wrappedValue
        lastKnownText = value
        return value
    }

    public func monacoView(controller: MonacoViewController, textDidChange text: String) {
        lastKnownText = text
        parent.text.wrappedValue = text
    }

    public func monacoView(controller: MonacoViewController,
                           didReceiveConsoleMessage message: MonacoConsoleMessage) {
        let joined = message.arguments.joined(separator: " ")
        print("[Monaco JS \(message.level.rawValue)] \(joined)")
    }
}
