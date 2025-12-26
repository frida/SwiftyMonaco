import Foundation
import WebKit

final class MonacoEngine: NSObject {
    weak var delegate: MonacoEngineDelegate?

    let webView: WKWebView

    private var hasCreatedEditor = false
    private(set) var lastProfile: MonacoEditorProfile?
    private var lastThemeId: String?
    private var lastText: String?
    private var lastVisible: Bool?

    private var htmlLoaded = false
    private var pendingLoadContinuations: [CheckedContinuation<Void, Never>] = []
    private var pendingTopLevelSymbolsContinuations: [CheckedContinuation<[MonacoTopLevelSymbol], Never>] = []

    private let configureLock = AsyncLock()

    override init() {
        let configuration = WKWebViewConfiguration()
        let contentController = configuration.userContentController

        let consoleScript = WKUserScript(
            source: Self.makeConsoleHookJS(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(consoleScript)

        let webView = WKWebView(frame: .zero, configuration: configuration)

        #if os(iOS)
        webView.backgroundColor = .none
        #else
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif

        self.webView = webView

        super.init()

        contentController.add(UpdateTextScriptHandler(self), name: "updateText")
        contentController.add(TopLevelSymbolsScriptHandler(self), name: "topLevelSymbols")
        contentController.add(ConsoleScriptHandler(self), name: "console")
    }

    func prepareForReuse() {
        delegate = nil

        if lastText != nil {
            lastText = ""
        }
        lastVisible = false
        webView.evaluateJavaScript("document.body.style.opacity = '0'; window.editor?.clearText();", completionHandler: nil)
    }

    func configure(
        profile: MonacoEditorProfile,
        text: String,
        visible: Bool
    ) async throws {
        await configureLock.lock()
        defer { configureLock.unlock() }

        await ensureHTMLLoaded()

        guard let script = makeConfigurationScript(
            profile: profile,
            text: text,
            visible: visible
        ) else {
            return
        }

        try await evaluate(script)
    }

    func noteExternalTextChange(_ text: String) {
        lastText = text
    }

    func topLevelSymbols() async -> [MonacoTopLevelSymbol] {
        await withCheckedContinuation { continuation in
            pendingTopLevelSymbolsContinuations.append(continuation)

            if pendingTopLevelSymbolsContinuations.count == 1 {
                webView.evaluateJavaScript("window.editor.requestTopLevelSymbols();", in: nil, in: WKContentWorld.page, completionHandler: nil)
            }
        }
    }

    @MainActor
    private func ensureHTMLLoaded() async {
        if htmlLoaded {
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if htmlLoaded {
                continuation.resume()
                return
            }

            pendingLoadContinuations.append(continuation)

            if webView.url == nil {
                webView.navigationDelegate = self
                webView.load(URLRequest(url: Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "_Resources")!))
            }
        }
    }

    @MainActor
    private func evaluate(_ javascript: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javascript, in: nil, in: WKContentWorld.page) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeConfigurationScript(
        profile: MonacoEditorProfile,
        text: String,
        visible: Bool
    ) -> String? {
        let previousProfile = lastProfile

        var configurationJS = ""
        var needMonaco = false

        func tsOptionsLiteral(_ opts: TypeScriptCompilerOptions?) -> String {
            opts?.toJavaScriptObjectLiteral() ?? "{}"
        }

        if previousProfile?.tsCompilerOptions != profile.tsCompilerOptions {
            let literal = tsOptionsLiteral(profile.tsCompilerOptions)
            configurationJS += "editor.updateDefaultTypescriptCompilerOptions(\(literal));\n"
        }

        if previousProfile?.tsExtraLibs != profile.tsExtraLibs {
            if profile.tsExtraLibs.isEmpty {
                configurationJS += "editor.updateDefaultTypescriptExtraLibs([]);\n"
            } else {
                let libs = profile.tsExtraLibs
                    .map { $0.toJavaScriptObjectLiteral() }
                    .joined(separator: ",\n        ")
                configurationJS += """
                editor.updateDefaultTypescriptExtraLibs([
                    \(libs)
                ]);
                """ + "\n"
            }
        }

        if previousProfile?.jsCompilerOptions != profile.jsCompilerOptions {
            let literal = tsOptionsLiteral(profile.jsCompilerOptions)
            configurationJS += "editor.updateDefaultJavascriptCompilerOptions(\(literal));\n"
        }

        if previousProfile?.jsExtraLibs != profile.jsExtraLibs {
            if profile.jsExtraLibs.isEmpty {
                configurationJS += "editor.updateDefaultJavascriptExtraLibs([]);\n"
            } else {
                let libs = profile.jsExtraLibs
                    .map { $0.toJavaScriptObjectLiteral() }
                    .joined(separator: ",\n        ")
                configurationJS += """
                editor.updateDefaultJavascriptExtraLibs([
                    \(libs)
                ]);
                """ + "\n"
            }
        }

        if previousProfile?.fsSnapshot != profile.fsSnapshot {
            if let snapshot = profile.fsSnapshot {
                let data = try? JSONEncoder().encode(snapshot)
                let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
                configurationJS += "editor.setFSSnapshot(\(json));\n"
            } else {
                configurationJS += "editor.setFSSnapshot(null);\n"
            }
        }

        var languageIdToSet: String? = nil
        if let syntax = profile.syntax {
            switch syntax {
            case .monaco(let languageId):
                languageIdToSet = languageId

            case .custom(let languageId, let configuration):
                languageIdToSet = languageId

                if !hasCreatedEditor || previousProfile?.syntax != profile.syntax {
                    configurationJS += """
                    monaco.languages.register({ id: '\(languageId)' });

                    monaco.languages.setMonarchTokensProvider('\(languageId)', (function() {
                        \(configuration)
                    })());
                    """
                    needMonaco = true
                }
            }
        }

        if previousProfile?.documentPath != profile.documentPath {
            if let p = profile.documentPath {
                let escaped = p
                    .replacingOccurrences(of: "'", with: "\\'")
                configurationJS += "editor.setDocumentPath('\(escaped)');\n"
            } else {
                configurationJS += "editor.setDocumentPath(null);\n"
            }
        }

        if let languageId = languageIdToSet {
            if !hasCreatedEditor || previousProfile?.syntax != profile.syntax {
                configurationJS += "editor.setLanguageId('\(languageId)');\n"
            }
        }

        if lastText != text {
            let b64 = text.data(using: .utf8)?.base64EncodedString() ?? ""
            configurationJS += "editor.setText(atob('\(b64)'));\n"
            lastText = text
        }

        var uiOptionsParts: [String] = []

        let effectiveThemeId: String = {
            switch profile.theme ?? Theme.detectSystemDefault() {
            case .light: return "vs"
            case .dark:  return "vs-dark"
            }
        }()

        if !hasCreatedEditor || previousProfile?.minimap != profile.minimap {
            uiOptionsParts.append("minimap: { enabled: \(profile.minimap) }")
        }

        if !hasCreatedEditor || previousProfile?.scrollbar != profile.scrollbar {
            let vertical = profile.scrollbar ? "'visible'" : "'hidden'"
            uiOptionsParts.append("scrollbar: { vertical: \(vertical) }")
        }

        if !hasCreatedEditor || previousProfile?.smoothCursor != profile.smoothCursor {
            uiOptionsParts.append("cursorSmoothCaretAnimation: \(profile.smoothCursor)")
        }

        if !hasCreatedEditor || previousProfile?.cursorBlink != profile.cursorBlink {
            uiOptionsParts.append("cursorBlinking: '\(profile.cursorBlink)'")
        }

        if !hasCreatedEditor || previousProfile?.fontSize != profile.fontSize {
            uiOptionsParts.append("fontSize: \(profile.fontSize)")
        }

        if !hasCreatedEditor || lastThemeId != effectiveThemeId {
            uiOptionsParts.append("theme: '\(effectiveThemeId)'")
        }

        if !uiOptionsParts.isEmpty {
            let optionsObject = uiOptionsParts.joined(separator: ", ")
            if !hasCreatedEditor {
                configurationJS += "editor.create({ automaticLayout: true, \(optionsObject) });\n"
                hasCreatedEditor = true
            } else {
                configurationJS += "editor.updateOptions({ \(optionsObject) });\n"
            }
        }

        lastProfile = profile
        lastThemeId = effectiveThemeId

        if lastVisible != visible {
            configurationJS += "document.body.style.opacity = '\(visible ? "1" : "0")';\n"
            lastVisible = visible
        }

        guard !configurationJS.isEmpty else { return nil }

        let script: String
        if needMonaco {
            script = """
            editor.withMonaco(monaco => {
            \(configurationJS)
            });
            """
        } else {
            script = configurationJS
        }

        return script
    }
}

protocol MonacoEngineDelegate: AnyObject {
    func monacoEngine(_ engine: MonacoEngine, didChangeText text: String)
    func monacoEngine(_ engine: MonacoEngine, didReceiveConsoleMessage message: MonacoConsoleMessage)
}

public struct MonacoConsoleMessage {
    public enum Level: String {
        case log
        case warn
        case error
        case info
        case debug
        case uncaughtError
        case unhandledRejection
    }

    public let level: Level
    public let arguments: [String]
}

extension MonacoEngine: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        htmlLoaded = true

        let continuations = pendingLoadContinuations
        pendingLoadContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private extension MonacoEngine {
    final class UpdateTextScriptHandler: NSObject, WKScriptMessageHandler {
        private unowned let engine: MonacoEngine

        init(_ engine: MonacoEngine) {
            self.engine = engine
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                let encodedText = message.body as? String,
                let data = Data(base64Encoded: encodedText),
                let text = String(data: data, encoding: .utf8)
            else {
                fatalError("Unexpected message body")
            }

            engine.noteExternalTextChange(text)
            engine.delegate?.monacoEngine(engine, didChangeText: text)
        }
    }
}

private extension MonacoEngine {
    final class TopLevelSymbolsScriptHandler: NSObject, WKScriptMessageHandler {
        private unowned let engine: MonacoEngine

        init(_ engine: MonacoEngine) {
            self.engine = engine
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let array = message.body as? [Any] else {
                fatalError("Unexpected message body")
            }

            let symbols: [MonacoTopLevelSymbol] = array.map { element in
                guard
                    let dict = element as? [String: Any],
                    let rawKind = dict["kind"] as? String,
                    let text = dict["text"] as? String,
                    let kind = MonacoSymbolKind(rawValue: rawKind)
                else {
                    fatalError("Unexpected message body")
                }

                return MonacoTopLevelSymbol(kind: kind, text: text)
            }

            let continuations = engine.pendingTopLevelSymbolsContinuations
            engine.pendingTopLevelSymbolsContinuations.removeAll()

            for continuation in continuations {
                continuation.resume(returning: symbols)
            }
        }
    }
}

private extension MonacoEngine {
    private static func makeConsoleHookJS() -> String {
        return """
        (function() {
            const orig = {
                log: console.log,
                warn: console.warn,
                error: console.error,
                info: console.info,
                debug: console.debug
            };

            console.log = function () { orig.log.apply(console, arguments); send('log', arguments); };
            console.warn = function () { orig.warn.apply(console, arguments); send('warn', arguments); };
            console.error = function () { orig.error.apply(console, arguments); send('error', arguments); };
            console.info = function () { orig.info.apply(console, arguments); send('info', arguments); };
            console.debug = function () { orig.debug.apply(console, arguments); send('debug', arguments); };

            window.onerror = (message, source, lineno, colno, error) => {
                send('uncaughtError', [message, source, lineno, colno, error?.stack ?? null]);
            };

            window.onunhandledrejection = event => {
                const reason = event.reason ?? {};
                send('unhandledRejection', [reason.message ?? String(reason), reason.stack ?? null]);
            };

            function send(type, args) {
                try {
                    window.webkit.messageHandlers.console.postMessage({
                        type: type,
                        args: Array.prototype.slice.call(args).map(function(a) {
                            try { return JSON.stringify(a); } catch (e) { return String(a); }
                        })
                    });
                } catch (e) {
                }
            }
        })();
        """
    }

    final class ConsoleScriptHandler: NSObject, WKScriptMessageHandler {
        private unowned let engine: MonacoEngine

        init(_ engine: MonacoEngine) {
            self.engine = engine
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                let dict = message.body as? [String: Any],
                let typeString = dict["type"] as? String,
                let argsAny = dict["args"] as? [Any]
            else {
                return
            }

            let level = MonacoConsoleMessage.Level(rawValue: typeString) ?? .log
            let args = argsAny.map { String(describing: $0) }

            let consoleMessage = MonacoConsoleMessage(level: level, arguments: args)
            engine.delegate?.monacoEngine(engine, didReceiveConsoleMessage: consoleMessage)
        }
    }
}

private final class AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if !isLocked {
                isLocked = true
                cont.resume()
            } else {
                waiters.append(cont)
            }
        }
    }

    func unlock() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            let cont = waiters.removeFirst()
            cont.resume()
        }
    }
}
