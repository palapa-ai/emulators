// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "emulators",
  platforms: [.iOS("13.0")],
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
