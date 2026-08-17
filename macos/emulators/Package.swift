// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "emulators",
  platforms: [.macOS("11.0")],
  products: [
    .library(name: "emulators", targets: ["emulators"])
  ],
  targets: [
    .target(
      name: "emulators",
      cSettings: [.headerSearchPath("include")]
    )
  ]
)
