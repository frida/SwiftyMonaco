public struct TypeScriptCompilerOptions: Equatable {
    public var target: TypeScriptScriptTarget?
    public var lib: [TypeScriptLib]?
    public var module: TypeScriptModuleKind?
    public var moduleResolution: TypeScriptModuleResolutionKind?
    public var typeRoots: [String]?
    public var strict: Bool?

    public init(
        target: TypeScriptScriptTarget? = nil,
        lib: [TypeScriptLib]? = nil,
        module: TypeScriptModuleKind? = nil,
        moduleResolution: TypeScriptModuleResolutionKind? = nil,
        typeRoots: [String]? = nil,
        strict: Bool? = nil,
    ) {
        self.target = target
        self.lib = lib
        self.module = module
        self.moduleResolution = moduleResolution
        self.typeRoots = typeRoots
        self.strict = strict
    }
}

public struct TypeScriptExtraLib: Equatable {
    public let content: String
    public let filePath: String

    public init(_ content: String, filePath: String) {
        self.content = content
        self.filePath = filePath
    }
}

public enum TypeScriptScriptTarget: Int {
    case es3    = 0
    case es5    = 1
    case es2015 = 2
    case es2016 = 3
    case es2017 = 4
    case es2018 = 5
    case es2019 = 6
    case es2020 = 7
    case es2021 = 8
    case es2022 = 9
    case es2023 = 10
    case es2024 = 11
    case esNext = 99
    case json   = 100
}

public enum TypeScriptModuleKind: Int {
    case none     = 0
    case commonJS = 1
    case amd      = 2
    case umd      = 3
    case system   = 4
    case es2015   = 5
    case es2020   = 6
    case es2022   = 7
    case esNext   = 99
    case node16   = 100
    case node18   = 101
    case node20   = 102
    case nodeNext = 199
    case preserve = 200
}

public enum TypeScriptModuleResolutionKind: Int {
    case classic = 1
    case nodeJs  = 2
    case node16  = 3
    case nodeNext = 99
    case bundler = 100

    public static var node10: TypeScriptModuleResolutionKind { .nodeJs }
}

public enum TypeScriptLib: String {
    case es5              = "es5"
    case es6              = "es6"
    case es2015           = "es2015"
    case es7              = "es7"
    case es2016           = "es2016"
    case es2017           = "es2017"
    case es2018           = "es2018"
    case es2019           = "es2019"
    case es2020           = "es2020"
    case es2021           = "es2021"
    case es2022           = "es2022"
    case es2023           = "es2023"
    case es2024           = "es2024"
    case esnext           = "esnext"

    case dom              = "dom"
    case domIterable      = "dom.iterable"
    case domAsynciterable = "dom.asynciterable"
    case webworker        = "webworker"
    case webworkerImportscripts = "webworker.importscripts"
    case webworkerIterable      = "webworker.iterable"
    case webworkerAsynciterable = "webworker.asynciterable"
    case scripthost       = "scripthost"

    case es2015Core              = "es2015.core"
    case es2015Collection        = "es2015.collection"
    case es2015Generator         = "es2015.generator"
    case es2015Iterable          = "es2015.iterable"
    case es2015Promise           = "es2015.promise"
    case es2015Proxy             = "es2015.proxy"
    case es2015Reflect           = "es2015.reflect"
    case es2015Symbol            = "es2015.symbol"
    case es2015SymbolWellknown   = "es2015.symbol.wellknown"

    case es2016ArrayInclude      = "es2016.array.include"
    case es2016Intl              = "es2016.intl"

    case es2017Arraybuffer       = "es2017.arraybuffer"
    case es2017Date              = "es2017.date"
    case es2017Object            = "es2017.object"
    case es2017Sharedmemory      = "es2017.sharedmemory"
    case es2017String            = "es2017.string"
    case es2017Intl              = "es2017.intl"
    case es2017Typedarrays       = "es2017.typedarrays"

    case es2018Asyncgenerator    = "es2018.asyncgenerator"
    case es2018Asynciterable     = "es2018.asynciterable"
    case es2018Intl              = "es2018.intl"
    case es2018Promise           = "es2018.promise"
    case es2018Regexp            = "es2018.regexp"

    case es2019Array             = "es2019.array"
    case es2019Object            = "es2019.object"
    case es2019String            = "es2019.string"
    case es2019Symbol            = "es2019.symbol"
    case es2019Intl              = "es2019.intl"

    case es2020Bigint            = "es2020.bigint"
    case es2020Date              = "es2020.date"
    case es2020Promise           = "es2020.promise"
    case es2020Sharedmemory      = "es2020.sharedmemory"
    case es2020String            = "es2020.string"
    case es2020SymbolWellknown   = "es2020.symbol.wellknown"
    case es2020Intl              = "es2020.intl"
    case es2020Number            = "es2020.number"

    case es2021Promise           = "es2021.promise"
    case es2021String            = "es2021.string"
    case es2021Weakref           = "es2021.weakref"
    case es2021Intl              = "es2021.intl"

    case es2022Array             = "es2022.array"
    case es2022Error             = "es2022.error"
    case es2022Intl              = "es2022.intl"
    case es2022Object            = "es2022.object"
    case es2022String            = "es2022.string"
    case es2022Regexp            = "es2022.regexp"

    case es2023Array             = "es2023.array"
    case es2023Collection        = "es2023.collection"
    case es2023Intl              = "es2023.intl"

    case es2024Arraybuffer       = "es2024.arraybuffer"
    case es2024Collection        = "es2024.collection"
    case es2024Object            = "es2024.object"
    case es2024Promise           = "es2024.promise"
    case es2024Regexp            = "es2024.regexp"
    case es2024Sharedmemory      = "es2024.sharedmemory"
    case es2024String            = "es2024.string"

    case esnextArray             = "esnext.array"
    case esnextCollection        = "esnext.collection"
    case esnextSymbol            = "esnext.symbol"
    case esnextAsynciterable     = "esnext.asynciterable"
    case esnextIntl              = "esnext.intl"
    case esnextDisposable        = "esnext.disposable"
    case esnextBigint            = "esnext.bigint"
    case esnextString            = "esnext.string"
    case esnextPromise           = "esnext.promise"
    case esnextWeakref           = "esnext.weakref"
    case esnextDecorators        = "esnext.decorators"
    case esnextObject            = "esnext.object"
    case esnextRegexp            = "esnext.regexp"
    case esnextIterator          = "esnext.iterator"
    case esnextFloat16           = "esnext.float16"
    case esnextError             = "esnext.error"
    case esnextSharedmemory      = "esnext.sharedmemory"

    case decoratorsLib           = "decorators"
    case decoratorsLegacy        = "decorators.legacy"
}

extension TypeScriptCompilerOptions {
    func toJavaScriptObjectLiteral() -> String {
        var parts: [String] = []

        if let target {
            parts.append("target: \(target.rawValue)")
        }
        if let lib {
            let libJS = lib
                .map { "'\($0.rawValue)'" }
                .joined(separator: ", ")
            parts.append("lib: [\(libJS)]")
        }
        if let module {
            parts.append("module: \(module.rawValue)")
        }
        if let moduleResolution {
            parts.append("moduleResolution: \(moduleResolution.rawValue)")
        }
        if let typeRoots {
            let rootsJS = typeRoots
                .map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" }
                .joined(separator: ", ")
            parts.append("typeRoots: [\(rootsJS)]")
        }
        if let strict {
            parts.append("strict: \(strict ? "true" : "false")")
        }

        return "{ \(parts.joined(separator: ", ")) }"
    }

    var isEmpty: Bool {
        return target == nil &&
               (lib?.isEmpty ?? true) &&
               module == nil &&
               moduleResolution == nil &&
               (typeRoots?.isEmpty ?? true) &&
               strict == nil
    }
}
