//
//  MonacoViewController.swift
//
//
//  Created by Pavel Kasila on 20.03.21.
//

#if os(macOS)
import AppKit
public typealias ViewController = NSViewController
#else
import UIKit
public typealias ViewController = UIViewController
#endif
import WebKit

public class MonacoViewController: ViewController {
    var delegate: MonacoViewControllerDelegate?

    private(set) var engine: MonacoEngine!

    deinit {
        if engine != nil {
            MonacoWebViewPool.shared.release(engine)
        }
    }

    public override func loadView() {
        let profile = delegate?.monacoView(getProfile: self) ?? MonacoEditorProfile()

        let engine = MonacoWebViewPool.shared.acquire(profile: profile)
        self.engine = engine
        engine.delegate = self

        view = engine.webView

        #if os(macOS)
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceModeChanged(sender:)),
            name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        #endif
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        reconfigure()
    }

    func reconfigure() {
        let profile = delegate?.monacoView(getProfile: self) ?? MonacoEditorProfile()
        let text = delegate?.monacoView(readText: self) ?? ""

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.engine.configure(
                    profile: profile,
                    text: text,
                    visible: true
                )
            } catch let error as NSError {
                await self.presentJavascriptError(error)
            }
        }
    }

    @MainActor
    private func presentJavascriptError(_ error: NSError) {
        var message = "JavaScript error.\n\n"
        message += "Description: \(error.localizedDescription)\n"

        if let exception = error.userInfo["WKJavaScriptExceptionMessage"] as? String {
            message += "Exception: \(exception)\n"
        }

        if let line = error.userInfo["WKJavaScriptExceptionLineNumber"] {
            message += "Line: \(line)\n"
        }

        if let column = error.userInfo["WKJavaScriptExceptionColumnNumber"] {
            message += "Column: \(column)\n"
        }

        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "JavaScript Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #else
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        #endif
    }

    public func topLevelSymbols() async -> [MonacoTopLevelSymbol] {
        await engine.topLevelSymbols()
    }

    private func updateTheme() {
        let profile = delegate?.monacoView(getProfile: self) ?? MonacoEditorProfile()
        guard profile.theme == nil else {
            return
        }

        reconfigure()
    }

    #if os(macOS)
    @objc private func interfaceModeChanged(sender: NSNotification) {
        updateTheme()
    }
    #else
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTheme()
    }
    #endif
}

public protocol MonacoViewControllerDelegate {
    func monacoView(getProfile controller: MonacoViewController) -> MonacoEditorProfile
    func monacoView(readText controller: MonacoViewController) -> String
    func monacoView(controller: MonacoViewController, textDidChange: String)
    func monacoView(controller: MonacoViewController, didReceiveConsoleMessage message: MonacoConsoleMessage)
}

extension MonacoViewController: MonacoEngineDelegate {
    func monacoEngine(_ engine: MonacoEngine, didChangeText text: String) {
        delegate?.monacoView(controller: self, textDidChange: text)
    }

    func monacoEngine(_ engine: MonacoEngine, didReceiveConsoleMessage message: MonacoConsoleMessage) {
        delegate?.monacoView(controller: self, didReceiveConsoleMessage: message)
    }
}
