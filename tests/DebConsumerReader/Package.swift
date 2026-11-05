// swift-tools-version:5.9
import PackageDescription
// Test-only dependencies, matching TrollFools' pinned consumer versions.
let package = Package(name: "DebReader", platforms: [.macOS(.v12)], dependencies: [
    .package(url: "https://github.com/tsolomko/BitByteData", exact: "2.0.4"),
    .package(url: "https://github.com/LebJe/ArArchiveKit", exact: "0.3.0"),
    .package(url: "https://github.com/tsolomko/SWCompression", exact: "4.8.6")
], targets: [.executableTarget(name: "DebReader", dependencies: ["ArArchiveKit", "SWCompression"])])
