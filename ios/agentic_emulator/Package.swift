// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "agentic_emulator",
  platforms: [.iOS("18.0")],
  products: [
    .library(name: "agentic-emulator", targets: ["emulators", "emulators_host"])
  ],
  targets: [
    .target(
      name: "emulators_host",
      cSettings: [.headerSearchPath("include")],
      linkerSettings: [.linkedFramework("AudioToolbox")]
    ),
    .target(
      name: "emulators",
      dependencies: ["emulators_host"],
      linkerSettings: [.linkedFramework("GameController")]
    ),
  ]
)
