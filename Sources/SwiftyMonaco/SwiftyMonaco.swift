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
    var syntax: SyntaxHighlight?
    var _introspector: MonacoIntrospector? = nil
    var _tsCompilerOptions: TypeScriptCompilerOptions? = nil
    var _tsExtraLibs: [MonacoExtraLib] = []
    var _jsCompilerOptions: TypeScriptCompilerOptions? = nil
    var _jsExtraLibs: [MonacoExtraLib] = []
    var _minimap: Bool = true
    var _scrollbar: Bool = true
    var _smoothCursor: Bool = false
    var _cursorBlink: CursorBlink = .blink
    var _fontSize: Int = 12
    var _theme: Theme? = nil
    
    public init(text: Binding<String>) {
        self.text = text
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
        doUpdateViewController(nsViewController, coordinator: context.coordinator)
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
        if coordinator.lastKnownText != newText {
            viewController.setText(newText)
            coordinator.lastKnownText = newText
        }

        let newTsOpts = _tsCompilerOptions
        if coordinator.lastKnownTsCompilerOptions != newTsOpts {
            viewController.setTypeScriptCompilerOptions(newTsOpts)
            coordinator.lastKnownTsCompilerOptions = newTsOpts
        }

        let newTsLibs = _tsExtraLibs
        if coordinator.lastKnownTsExtraLibs != newTsLibs {
            viewController.setTypeScriptExtraLibs(newTsLibs)
            coordinator.lastKnownTsExtraLibs = newTsLibs
        }

        let newJsOpts = _jsCompilerOptions
        if coordinator.lastKnownJsCompilerOptions != newJsOpts {
            viewController.setJavaScriptCompilerOptions(newJsOpts)
            coordinator.lastKnownJsCompilerOptions = newJsOpts
        }

        let newJsLibs = _jsExtraLibs
        if coordinator.lastKnownJsExtraLibs != newJsLibs {
            viewController.setJavaScriptExtraLibs(newJsLibs)
            coordinator.lastKnownJsExtraLibs = newJsLibs
        }
    }
}

// MARK: - Modifiers
public extension SwiftyMonaco {
    func syntaxHighlight(_ syntax: SyntaxHighlight) -> Self {
        var m = self
        m.syntax = syntax
        return m
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
        copy._tsCompilerOptions = options
        return copy
    }
}

public extension SwiftyMonaco {
    func typescriptExtraLib(_ lib: String, named filePath: String) -> Self {
        var copy = self
        copy._tsExtraLibs.append(MonacoExtraLib(lib, filePath: filePath))
        return copy
    }
}

public extension SwiftyMonaco {
    func javascriptCompilerOptions(_ options: TypeScriptCompilerOptions) -> Self {
        var copy = self
        copy._jsCompilerOptions = options
        return copy
    }
}

public extension SwiftyMonaco {
    func javascriptExtraLib(_ lib: String, named filePath: String) -> Self {
        var copy = self
        copy._jsExtraLibs.append(MonacoExtraLib(lib, filePath: filePath))
        return copy
    }
}

public extension SwiftyMonaco {
    func minimap(_ enabled: Bool) -> Self {
        var m = self
        m._minimap = enabled
        return m
    }
}

public extension SwiftyMonaco {
    func scrollbar(_ enabled: Bool) -> Self {
        var m = self
        m._scrollbar = enabled
        return m
    }
}

public extension SwiftyMonaco {
    func smoothCursor(_ enabled: Bool) -> Self {
        var m = self
        m._smoothCursor = enabled
        return m
    }
}

public extension SwiftyMonaco {
    func cursorBlink(_ style: CursorBlink) -> Self {
        var m = self
        m._cursorBlink = style
        return m
    }
}

public extension SwiftyMonaco {
    func fontSize(_ size: Int) -> Self {
        var m = self
        m._fontSize = size
        return m
    }
}

public extension SwiftyMonaco {
    func theme(_ theme: Theme) -> Self {
        var m = self
        m._theme = theme
        return m
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
    var lastKnownTsCompilerOptions: TypeScriptCompilerOptions?
    var lastKnownTsExtraLibs: [MonacoExtraLib]
    var lastKnownJsCompilerOptions: TypeScriptCompilerOptions?
    var lastKnownJsExtraLibs: [MonacoExtraLib]

    init(_ parent: SwiftyMonaco) {
        self.parent = parent
        self.lastKnownText = parent.text.wrappedValue
        self.lastKnownTsCompilerOptions = parent._tsCompilerOptions
        self.lastKnownTsExtraLibs = parent._tsExtraLibs
        self.lastKnownJsCompilerOptions = parent._jsCompilerOptions
        self.lastKnownJsExtraLibs = parent._jsExtraLibs
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

    public func monacoView(getSyntax controller: MonacoViewController) -> SyntaxHighlight? {
        parent.syntax
    }

    public func monacoView(getTypeScriptCompilerOptions controller: MonacoViewController) -> TypeScriptCompilerOptions? {
        parent._tsCompilerOptions
    }

    public func monacoView(getTypeScriptExtraLibs controller: MonacoViewController) -> [MonacoExtraLib] {
        return parent._tsExtraLibs
    }

    public func monacoView(getJavaScriptCompilerOptions controller: MonacoViewController) -> TypeScriptCompilerOptions? {
        parent._jsCompilerOptions
    }

    public func monacoView(getJavaScriptExtraLibs controller: MonacoViewController) -> [MonacoExtraLib] {
        return parent._jsExtraLibs
    }

    public func monacoView(getMinimap controller: MonacoViewController) -> Bool {
        parent._minimap
    }

    public func monacoView(getScrollbar controller: MonacoViewController) -> Bool {
        parent._scrollbar
    }

    public func monacoView(getSmoothCursor controller: MonacoViewController) -> Bool {
        parent._smoothCursor
    }

    public func monacoView(getCursorBlink controller: MonacoViewController) -> CursorBlink {
        parent._cursorBlink
    }

    public func monacoView(getFontSize controller: MonacoViewController) -> Int {
        parent._fontSize
    }

    public func monacoView(getTheme controller: MonacoViewController) -> Theme? {
        parent._theme
    }

    public func monacoView(controller: MonacoViewController,
                           didReceiveConsoleMessage message: MonacoConsoleMessage) {
        let joined = message.arguments.joined(separator: " ")
        print("[Monaco JS \(message.level.rawValue)] \(joined)")
    }
}
