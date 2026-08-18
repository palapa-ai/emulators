import 'dart:convert';
import 'dart:ffi';

/// Allocation and C strings, taken from libc directly rather than through a
/// package: the whole need is four calls.
final DynamicLibrary _libc = DynamicLibrary.process();

final Pointer<Void> Function(int, int) _calloc = _libc
    .lookupFunction<Pointer<Void> Function(IntPtr, IntPtr),
        Pointer<Void> Function(int, int)>('calloc');

final void Function(Pointer<Void>) _free = _libc
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'free',
    );

final class Utf8 extends Opaque {}

Pointer<Uint8> allocate(int bytes) => _calloc(bytes, 1).cast<Uint8>();

void release(Pointer<NativeType> pointer) => _free(pointer.cast());

extension StringToNative on String {
  Pointer<Utf8> toNative() {
    final bytes = utf8.encode(this);
    final pointer = allocate(bytes.length + 1);
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    return pointer.cast();
  }
}

extension NativeToString on Pointer<Utf8> {
  String toDart() {
    final bytes = cast<Uint8>();
    var length = 0;
    while (bytes[length] != 0) {
      length++;
    }
    return utf8.decode(bytes.asTypedList(length));
  }
}
