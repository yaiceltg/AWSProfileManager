import Foundation

// Handle CLI flags before SwiftUI takes over the run loop, so `--version` and
// `--help` print and exit without opening a window.
let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--version") || arguments.contains("-v") {
    print("\(AppInfo.name) \(AppInfo.version) (build \(AppInfo.build))")
    exit(0)
}

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    \(AppInfo.name) \(AppInfo.version)

    Usage: AWSProfileManager [options]

    Options:
      -v, --version   Print the version and exit
      -h, --help      Print this help and exit

    With no options, launches the app window.
    """)
    exit(0)
}

AWSProfileManagerApp.main()
