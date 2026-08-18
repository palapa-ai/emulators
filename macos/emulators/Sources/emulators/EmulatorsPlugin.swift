import Foundation

/// SwiftPM forbids mixing Swift and C in one target, and Xcode's package
/// integration will not accept a Swift-less plugin target — so the C host is
/// its own target and this one exists to carry it into the app.
public enum Emulators {
  public static let hostVersion = "0.0.1"
}
