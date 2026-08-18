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
  guard let controller = GCController.controllers().first else { return 0 }

  var mask: UInt32 = 0

  func hold(_ button: Pad, _ pressed: Bool) {
    if pressed { mask |= 1 << button.rawValue }
  }

  if let pad = controller.extendedGamepad {
    // A SNES pad labels its buttons the SNES way, so the names line up
    // one-to-one — reading them positionally (bottom = B) is what put A on Y.
    hold(.a, pad.buttonA.isPressed)
    hold(.b, pad.buttonB.isPressed)
    hold(.x, pad.buttonX.isPressed)
    hold(.y, pad.buttonY.isPressed)
    hold(.l, pad.leftShoulder.isPressed)
    hold(.r, pad.rightShoulder.isPressed)
    // Retro pads put Select and Start wherever they like; accept every slot
    // they plausibly land on rather than guess one.
    hold(
      .start,
      pad.buttonMenu.isPressed || pad.rightTrigger.isPressed
        || (pad.rightThumbstickButton?.isPressed ?? false))
    hold(
      .select,
      (pad.buttonOptions?.isPressed ?? false) || pad.leftTrigger.isPressed
        || (pad.leftThumbstickButton?.isPressed ?? false))
    hold(.up, pad.dpad.up.isPressed)
    hold(.down, pad.dpad.down.isPressed)
    hold(.left, pad.dpad.left.isPressed)
    hold(.right, pad.dpad.right.isPressed)
    return mask
  }

  // Retro pads often expose only the legacy profile, which has no menu or
  // options button — Start and Select ride the shoulders there instead.
  if let pad = controller.gamepad {
    hold(.a, pad.buttonA.isPressed)
    hold(.b, pad.buttonB.isPressed)
    hold(.x, pad.buttonX.isPressed)
    hold(.y, pad.buttonY.isPressed)
    hold(.select, pad.leftShoulder.isPressed)
    hold(.start, pad.rightShoulder.isPressed)
    hold(.up, pad.dpad.up.isPressed)
    hold(.down, pad.dpad.down.isPressed)
    hold(.left, pad.dpad.left.isPressed)
    hold(.right, pad.dpad.right.isPressed)
  }

  return mask
}

/// Bit order matches PadElement on the Dart side. Raw physical elements, not
/// the SNES mapping — this is what a remapping UI has to show.
@_cdecl("emu_gamepad_raw")
public func emu_gamepad_raw() -> UInt32 {
  guard let controller = GCController.controllers().first else { return 0 }

  var mask: UInt32 = 0
  var bit: UInt32 = 0

  func hold(_ pressed: Bool) {
    if pressed { mask |= 1 << bit }
    bit += 1
  }

  if let pad = controller.extendedGamepad {
    hold(pad.buttonA.isPressed)
    hold(pad.buttonB.isPressed)
    hold(pad.buttonX.isPressed)
    hold(pad.buttonY.isPressed)
    hold(pad.leftShoulder.isPressed)
    hold(pad.rightShoulder.isPressed)
    hold(pad.leftTrigger.isPressed)
    hold(pad.rightTrigger.isPressed)
    hold(pad.buttonMenu.isPressed)
    hold(pad.buttonOptions?.isPressed ?? false)
    hold(false) // home needs macOS 11; the slot stays so bit order holds
    hold(pad.dpad.up.isPressed)
    hold(pad.dpad.down.isPressed)
    hold(pad.dpad.left.isPressed)
    hold(pad.dpad.right.isPressed)
    hold(pad.leftThumbstickButton?.isPressed ?? false)
    hold(pad.rightThumbstickButton?.isPressed ?? false)
    return mask
  }

  if let pad = controller.gamepad {
    hold(pad.buttonA.isPressed)
    hold(pad.buttonB.isPressed)
    hold(pad.buttonX.isPressed)
    hold(pad.buttonY.isPressed)
    hold(pad.leftShoulder.isPressed)
    hold(pad.rightShoulder.isPressed)
    hold(false)
    hold(false)
    hold(false)
    hold(false)
    hold(false)
    hold(pad.dpad.up.isPressed)
    hold(pad.dpad.down.isPressed)
    hold(pad.dpad.left.isPressed)
    hold(pad.dpad.right.isPressed)
  }

  return mask
}

@_cdecl("emu_gamepad_connected")
public func emu_gamepad_connected() -> Int32 {
  guard let controller = GCController.controllers().first else { return 0 }
  return controller.extendedGamepad != nil || controller.gamepad != nil ? 1 : 0
}

private var nameBuffer: UnsafeMutablePointer<CChar>?

/// Owned by this module and replaced on each call, so callers may read it but
/// must not free it.
@_cdecl("emu_gamepad_name")
public func emu_gamepad_name() -> UnsafePointer<CChar>? {
  guard let controller = GCController.controllers().first else { return nil }

  nameBuffer.map { free($0) }
  // The profile is part of the name because it is the difference between a
  // pad being seen and a pad actually working.
  let profile =
    controller.extendedGamepad != nil
    ? "" : (controller.gamepad != nil ? " (basic)" : " (unsupported)")
  nameBuffer = strdup((controller.vendorName ?? "Controller") + profile)
  return UnsafePointer(nameBuffer)
}
