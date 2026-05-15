import Foundation

public enum MonacoWebBundle {
    public static let bundle = Bundle.module

    public static var indexURL: URL {
        bundle.url(forResource: "index", withExtension: "html", subdirectory: "Resources")!
    }
}
