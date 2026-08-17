import 'dart:io';

import 'package:emulators/emulators.dart';
import 'package:flutter/widgets.dart';

/// Pass the core, and optionally a folder to keep cartridges in:
///
///   flutter run -d macos --dart-define=CORE=/path/to/snes9x2010_libretro.dylib
void main() {
  runApp(const EmulatorsExample());
}

const _corePath = String.fromEnvironment('CORE');
const _libraryRoot = String.fromEnvironment('LIBRARY');

class EmulatorsExample extends StatelessWidget {
  const EmulatorsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'emulators',
      color: const Color(0xff101014),
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQueryData.fromView(View.of(context)).padding.top + 16,
          16,
          16,
        ),
        child: EmulatorScreen(
          corePath: _corePath.isEmpty ? null : _corePath,
          libraryRoot: _libraryRoot.isEmpty
              ? Directory.current.path
              : _libraryRoot,
        ),
      ),
    );
  }
}
