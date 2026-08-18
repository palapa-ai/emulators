import Foundation
import emulators_host

/// SwiftPM forbids mixing Swift and C in one target, and Xcode's package
/// integration will not accept a Swift-less plugin target — so the C host is
/// its own target and this one carries it into the app.
///
/// Taking the address of an entry point keeps the linker from dead-stripping
/// the host out of the binary Dart then looks it up in.
public enum Emulators {
  public static let hostVersion = "0.0.1"

  @discardableResult
  public static func keepHostLinked() -> UnsafeRawPointer {
    unsafeBitCast(emu_open, to: UnsafeRawPointer.self)
  }
}
