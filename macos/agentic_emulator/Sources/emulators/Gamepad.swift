import Foundation
import GameController

/// Bit positions match EMU_BUTTON_* in libretro_host.h.
private enum Pad: UInt32 {
  case b = 0
  case y, select, start, up, down, left, right, a, x, l, r
}

/// GameController's own element names. A pad with no extended profile still
/// reports every element under these, and reading them is the only way a
/// retro USB pad works: the legacy `GCGamepad` profile this used to fall back
/// to has been deprecated since 10.15 and reports nothing pressed.
private enum Element {
  static let a = "Button A"
  static let b = "Button B"
  static let x = "Button X"
  static let y = "Button Y"
  static let leftShoulder = "Left Shoulder"
  static let rightShoulder = "Right Shoulder"
  static let leftTrigger = "Left Trigger"
  static let rightTrigger = "Right Trigger"
  static let menu = "Button Menu"
  static let options = "Button Options"
  static let dpad = "Direction Pad"
}

private func firstController() -> GCController? {
  GCController.controllers().first
}

@available(macOS 11.0, *)
private func genericProfile(_ controller: GCController) -> GCPhysicalInputProfile? {
  let profile = controller.physicalInputProfile
  return profile.buttons.isEmpty ? nil : profile
}

/// GameController names buttons by position, so the SNES mapping is written
/// once here rather than guessed from per-device indices: the bottom face
/// button is B and the right one is A, the reverse of the Xbox naming.
@_cdecl("emu_gamepad_buttons")
public func emu_gamepad_buttons() -> UInt32 {
  guard let controller = firstController() else { return 0 }

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

  guard #available(macOS 11.0, *) else { return mask }
  guard let profile = genericProfile(controller) else { return mask }

  func down(_ names: String...) -> Bool {
    names.contains { profile.buttons[$0]?.isPressed ?? false }
  }

  hold(.a, down(Element.a))
  hold(.b, down(Element.b))
  hold(.x, down(Element.x))
  hold(.y, down(Element.y))
  hold(.l, down(Element.leftShoulder))
  hold(.r, down(Element.rightShoulder))
  hold(.start, down(Element.menu, Element.rightTrigger))
  hold(.select, down(Element.options, Element.leftTrigger))

  if let dpad = profile.dpads[Element.dpad] {
    hold(.up, dpad.up.isPressed)
    hold(.down, dpad.down.isPressed)
    hold(.left, dpad.left.isPressed)
    hold(.right, dpad.right.isPressed)
  }

  return mask
}

/// Bit order matches PadElement on the Dart side. Raw physical elements, not
/// the SNES mapping — this is what a remapping UI has to show.
@_cdecl("emu_gamepad_raw")
public func emu_gamepad_raw() -> UInt32 {
  guard let controller = firstController() else { return 0 }

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
    hold(false)  // home needs macOS 11; the slot stays so bit order holds
    hold(pad.dpad.up.isPressed)
    hold(pad.dpad.down.isPressed)
    hold(pad.dpad.left.isPressed)
    hold(pad.dpad.right.isPressed)
    hold(pad.leftThumbstickButton?.isPressed ?? false)
    hold(pad.rightThumbstickButton?.isPressed ?? false)
    return mask
  }

  guard #available(macOS 11.0, *) else { return mask }
  guard let profile = genericProfile(controller) else { return mask }

  func down(_ name: String) -> Bool {
    profile.buttons[name]?.isPressed ?? false
  }

  let dpad = profile.dpads[Element.dpad]

  hold(down(Element.a))
  hold(down(Element.b))
  hold(down(Element.x))
  hold(down(Element.y))
  hold(down(Element.leftShoulder))
  hold(down(Element.rightShoulder))
  hold(down(Element.leftTrigger))
  hold(down(Element.rightTrigger))
  hold(down(Element.menu))
  hold(down(Element.options))
  hold(false)
  hold(dpad?.up.isPressed ?? false)
  hold(dpad?.down.isPressed ?? false)
  hold(dpad?.left.isPressed ?? false)
  hold(dpad?.right.isPressed ?? false)

  return mask
}

@_cdecl("emu_gamepad_connected")
public func emu_gamepad_connected() -> Int32 {
  guard let controller = firstController() else { return 0 }
  if controller.extendedGamepad != nil { return 1 }
  if #available(macOS 11.0, *) { return genericProfile(controller) != nil ? 1 : 0 }
  return 0
}

private var nameBuffer: UnsafeMutablePointer<CChar>?

/// Owned by this module and replaced on each call, so callers may read it but
/// must not free it.
@_cdecl("emu_gamepad_name")
public func emu_gamepad_name() -> UnsafePointer<CChar>? {
  guard let controller = firstController() else { return nil }

  nameBuffer.map { free($0) }
  // The profile is part of the name because it is the difference between a
  // pad being seen and a pad actually working.
  var profile = " (unsupported)"
  if controller.extendedGamepad != nil {
    profile = ""
  } else if #available(macOS 11.0, *), genericProfile(controller) != nil {
    profile = ""
  }
  nameBuffer = strdup((controller.vendorName ?? "Controller") + profile)
  return UnsafePointer(nameBuffer)
}
