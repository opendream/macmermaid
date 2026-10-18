import Foundation

/// SwiftPM's generated accessor differs between toolchains. Packaged apps must
/// resolve their embedded bundle explicitly, never a path baked into the build.
enum AppResources {
    static let bundle: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("MacMermaid_MacMermaid.bundle"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("The packaged MacMermaid resource bundle is missing.")
            }
            return bundle
        }
        // SwiftPM command-line execution and unit tests still use its accessor.
        return Bundle.module
    }()
}
