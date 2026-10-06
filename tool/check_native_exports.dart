import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (!Platform.isMacOS) throw UnsupportedError('Run on macOS.');
  final root = File.fromUri(Platform.script).parent.parent;
  final native = '${root.path}/macos/emulator_palapa/Sources/emulators_host';
  final header = await File('$native/include/libretro_host.h').readAsString();
  final symbols = RegExp(r'EMU_API\s+[^;]+?\b(emu_\w+)\s*\(')
      .allMatches(header)
      .map((match) => match.group(1))
      .whereType<String>()
      .toList();
  if (symbols.isEmpty) throw StateError('No native exports found.');

  if (arguments case ['--app', final path]) {
    final executable = '$path/Contents/MacOS/Palapa';
    final result = await Process.run('xcrun', ['nm', '-gU', executable]);
    if (result.exitCode != 0) throw StateError('Cannot inspect $executable');
    final exports = const LineSplitter()
        .convert(result.stdout as String)
        .map((line) => line.trim().split(RegExp(r'\s+')).last)
        .toSet();
    final missing = symbols
        .where((name) => !exports.contains('_$name'))
        .toList();
    if (missing.isNotEmpty)
      throw StateError('Missing emulator exports: ${missing.join(', ')}');
    stdout.writeln(
      'All ${symbols.length} emulator exports are present in the app.',
    );
    return;
  }
  if (arguments.isNotEmpty)
    throw ArgumentError(
      'Usage: dart tool/check_native_exports.dart [--app Palapa.app]',
    );

  final temporary = await Directory.systemTemp.createTemp('emulator-exports-');
  try {
    final probe = File('${temporary.path}/probe.c');
    await probe.writeAsString('''
#include <dlfcn.h>
#include <stdio.h>
int main(void) {
  const char *names[] = {${symbols.map(jsonEncode).join(',')}};
  int missing = 0;
  for (unsigned i = 0; i < sizeof(names)/sizeof(names[0]); ++i) {
    if (!dlsym(RTLD_DEFAULT, names[i])) { fprintf(stderr, "%s\\n", names[i]); missing++; }
  }
  return missing ? 1 : 0;
}
''');
    final binary = '${temporary.path}/probe';
    final compiled = await Process.run('xcrun', [
      'clang',
      '-O3',
      '-Wl,-dead_strip',
      '-I$native/include',
      '$native/libretro_host.c',
      probe.path,
      '-framework',
      'AudioToolbox',
      '-o',
      binary,
    ]);
    if (compiled.exitCode != 0)
      throw StateError('Native build failed: ${compiled.stderr}');
    final result = await Process.run(binary, []);
    if (result.exitCode != 0)
      throw StateError('Release linking removed exports: ${result.stderr}');
    stdout.writeln(
      'All ${symbols.length} emulator exports survived optimized release linking.',
    );
  } finally {
    await temporary.delete(recursive: true);
  }
}
