// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "emulators",
  platforms: [.iOS("13.0")],
  products: [
    .library(name: "emulators", targets: ["emulators", "emulators_host"])
  ],
  targets: [
    .target(
      name: "emulators_host",
      cSettings: [.headerSearchPath("include")]
    ),
    .target(name: "emulators", dependencies: ["emulators_host"]),
  ]
)
