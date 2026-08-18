import Foundation
import GameController

/// Bit positions match EMU_BUTTON_* in libretro_host.h.
private enum Pad: UInt32 {
  case b = 0, y, select, start, up, down, left, right, a, x, l, r
}

/// GameController names buttons by position, so the SNES mapping is written
/// once here rather than guessed from per-device indices: the bottom face
/// button is B and the right one is A, the reverse of the Xbox naming.
@_cdecl("emu_gamepad_buttons")
public func emu_gamepad_buttons() -> UInt32 {
  guard let pad = GCController.controllers().first?.extendedGamepad else {
    return 0
  }

  var mask: UInt32 = 0

  func hold(_ button: Pad, _ pressed: Bool) {
    if pressed { mask |= 1 << button.rawValue }
  }

  hold(.b, pad.buttonA.isPressed)
  hold(.a, pad.buttonB.isPressed)
  hold(.y, pad.buttonX.isPressed)
  hold(.x, pad.buttonY.isPressed)
  hold(.l, pad.leftShoulder.isPressed)
  hold(.r, pad.rightShoulder.isPressed)
  hold(.start, pad.buttonMenu.isPressed)
  hold(.select, pad.buttonOptions?.isPressed ?? false)
  hold(.up, pad.dpad.up.isPressed)
  hold(.down, pad.dpad.down.isPressed)
  hold(.left, pad.dpad.left.isPressed)
  hold(.right, pad.dpad.right.isPressed)

  return mask
}

@_cdecl("emu_gamepad_connected")
public func emu_gamepad_connected() -> Int32 {
  GCController.controllers().first?.extendedGamepad != nil ? 1 : 0
}

private var nameBuffer: UnsafeMutablePointer<CChar>?

/// Owned by this module and replaced on each call, so callers may read it but
/// must not free it.
@_cdecl("emu_gamepad_name")
public func emu_gamepad_name() -> UnsafePointer<CChar>? {
  guard let controller = GCController.controllers().first else { return nil }

  nameBuffer.map { free($0) }
  nameBuffer = strdup(controller.vendorName ?? "Controller")
  return UnsafePointer(nameBuffer)
}
