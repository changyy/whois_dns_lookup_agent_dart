#!/usr/bin/env dart
// Keeps `pubspec.yaml` and `lib/src/version.dart` in sync.
//
// Usage:
//   dart run tool/update_version.dart                       # auto-generate from current Taipei time
//   dart run tool/update_version.dart 1.20260524.110000     # use a specific version
//   dart run tool/update_version.dart --check               # verify both files match (exit 0/1)
//
// Version format: 1.YYYYmmdd.HHMMSS  (zero-padded, Asia/Taipei = UTC+8, no DST).

import 'dart:io';

const _pubspecPath = 'pubspec.yaml';
const _versionDartPath = 'lib/src/version.dart';
final _versionRegex = RegExp(r'^1\.\d{8}\.\d{6}$');

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }
  if (args.contains('--check')) {
    await _check();
    return;
  }

  final version = args.isNotEmpty ? args.first : _generate();
  if (!_versionRegex.hasMatch(version)) {
    stderr.writeln('❌ invalid version: $version');
    stderr.writeln('   expected format: 1.YYYYmmdd.HHMMSS');
    exit(1);
  }

  await _updatePubspec(version);
  await _updateVersionDart(version);
  stdout.writeln('✅ bumped to $version');
  stdout.writeln('   - $_pubspecPath');
  stdout.writeln('   - $_versionDartPath');
  stdout.writeln('');
  stdout.writeln(
      'reminder: add a CHANGELOG.md entry for $version before committing.');
}

String _generate() {
  // Taipei is UTC+8 year-round (no DST), so an explicit offset gives the
  // same result no matter where the dev machine is.
  final taipei = DateTime.now().toUtc().add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  final ymd = '${taipei.year}${two(taipei.month)}${two(taipei.day)}';
  final hms = '${two(taipei.hour)}${two(taipei.minute)}${two(taipei.second)}';
  return '1.$ymd.$hms';
}

Future<void> _updatePubspec(String version) async {
  final file = File(_pubspecPath);
  if (!await file.exists()) {
    throw StateError('$_pubspecPath not found (run from package root)');
  }
  final lines = await file.readAsLines();
  var found = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('version:')) {
      lines[i] = 'version: $version';
      found = true;
      break;
    }
  }
  if (!found) {
    throw StateError('no `version:` line in $_pubspecPath');
  }
  await file.writeAsString('${lines.join('\n')}\n');
}

Future<void> _updateVersionDart(String version) async {
  final file = File(_versionDartPath);
  if (!await file.exists()) {
    throw StateError('$_versionDartPath not found');
  }
  final original = await file.readAsString();
  final pattern = RegExp(r"(static const String version = ')[^']+(';)");
  if (!pattern.hasMatch(original)) {
    throw StateError(
        "could not locate `static const String version = '...';` in $_versionDartPath");
  }
  final updated = original.replaceFirstMapped(
    pattern,
    (m) => '${m.group(1)}$version${m.group(2)}',
  );
  await file.writeAsString(updated);
}

Future<void> _check() async {
  final pubspecLine = await _readPubspecVersion();
  final dartConst = await _readVersionDart();
  if (pubspecLine == null) {
    stderr.writeln('❌ no `version:` in $_pubspecPath');
    exit(1);
  }
  if (dartConst == null) {
    stderr.writeln('❌ no version constant in $_versionDartPath');
    exit(1);
  }
  if (pubspecLine != dartConst) {
    stderr.writeln('❌ version mismatch:');
    stderr.writeln('   $_pubspecPath        : $pubspecLine');
    stderr.writeln('   $_versionDartPath    : $dartConst');
    stderr.writeln('   run: dart run tool/update_version.dart');
    exit(1);
  }
  stdout.writeln('✅ versions match: $pubspecLine');
}

Future<String?> _readPubspecVersion() async {
  final lines = await File(_pubspecPath).readAsLines();
  for (final line in lines) {
    if (line.startsWith('version:')) {
      return line.substring('version:'.length).trim();
    }
  }
  return null;
}

Future<String?> _readVersionDart() async {
  final text = await File(_versionDartPath).readAsString();
  final m =
      RegExp(r"static const String version = '([^']+)';").firstMatch(text);
  return m?.group(1);
}

void _printUsage() {
  stdout.writeln('Usage:');
  stdout.writeln(
      '  dart run tool/update_version.dart                      # auto-generate from current Taipei time');
  stdout.writeln(
      '  dart run tool/update_version.dart 1.20260524.110000    # set specific version');
  stdout.writeln(
      '  dart run tool/update_version.dart --check              # verify both files agree');
  stdout.writeln('');
  stdout.writeln(
      'Version format: 1.YYYYmmdd.HHMMSS (zero-padded, Asia/Taipei = UTC+8).');
}
