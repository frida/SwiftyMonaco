//
//  SyntaxHighlight.swift
//  
//
//  Created by Pavel Kasila on 20.03.21.
//

import Foundation

public enum SyntaxHighlight: Equatable {

    /// Uses Monaco's built-in language support
    /// e.g. "javascript", "cpp", "python"
    case monaco(languageId: String)

    /// Registers a custom Monarch tokenizer
    /// If the language already exists, this will override it
    case custom(
        languageId: String,
        configuration: String
    )

    /// Convenience for loading config from file
    public static func custom(languageId: String, fileURL: URL) -> SyntaxHighlight {
        let data = try! Data(contentsOf: fileURL)
        let config = String(data: data, encoding: .utf8)!
        return .custom(languageId: languageId, configuration: config)
    }
}

public extension SyntaxHighlight {
    static let swift = SyntaxHighlight.custom(languageId: "swift", fileURL: Bundle.module.url(forResource: "swift", withExtension: "js", subdirectory: "Languages")!)
    static let cpp = SyntaxHighlight.custom(languageId: "cpp", fileURL: Bundle.module.url(forResource: "cpp", withExtension: "js", subdirectory: "Languages")!)
    static let systemVerilog = SyntaxHighlight.custom(languageId: "system-verilog", fileURL: Bundle.module.url(forResource: "systemVerilog", withExtension: "js", subdirectory: "Languages")!)
}
