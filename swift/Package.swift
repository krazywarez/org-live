// swift-tools-version:6.4
import PackageDescription

let package = Package(
  name: "org-live",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui.git", from: "0.9.0"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.62.0"),
    .package(path: "../../org-swift"),
  ],
  targets: [
    .executableTarget(
      name: "OrgLive",
      dependencies: [
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "OrgSwift", package: "org-swift"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
    )
  ]
)
