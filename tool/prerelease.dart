#!/usr/bin/env dart
// Pre-release preflight: runs every check pub.dev (and good hygiene) cares
// about, in dependency order. Stops at the first failure with a clear
// message — none of the 'one step quietly failed three steps ago' surprise.
//
// Usage:
//   dart run tool/prerelease.dart            # full run, stop on first failure
//   dart run tool/prerelease.dart --keep-going  # run all, summarise at end
//
// Does NOT actually publish — `dart pub publish --dry-run` is the last step.

import 'dart:io';

class Step {
  const Step(this.name, this.command, {this.rationale});
  final String name;
  final List<String> command;
  final String? rationale;
}

const _steps = <Step>[
  Step(
    'pub get',
    ['dart', 'pub', 'get'],
    rationale: 'lockfile fresh, deps resolved',
  ),
  Step(
    'version sync check',
    ['dart', 'run', 'tool/update_version.dart', '--check'],
    rationale: 'pubspec.yaml and lib/src/version.dart agree',
  ),
  Step(
    'format check',
    ['dart', 'format', '--set-exit-if-changed', '.'],
    rationale: 'no reformatting needed (pub.dev penalises unformatted code)',
  ),
  Step(
    'analyze',
    ['dart', 'analyze', '--fatal-infos'],
    rationale: 'zero warnings/lints/infos',
  ),
  Step(
    'test',
    ['dart', 'test'],
    rationale: 'all unit tests pass',
  ),
  Step(
    'doc',
    ['dart', 'doc', '--dry-run'],
    rationale: 'dartdoc renders cleanly (no broken references)',
  ),
  Step(
    'pub publish dry-run',
    ['dart', 'pub', 'publish', '--dry-run'],
    rationale: 'pub.dev would accept this build',
  ),
];

const _cyan = '\x1B[36m';
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _bold = '\x1B[1m';
const _reset = '\x1B[0m';

Future<void> main(List<String> args) async {
  final keepGoing = args.contains('--keep-going');
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln('Usage: dart run tool/prerelease.dart [--keep-going]');
    stdout.writeln('');
    stdout.writeln('Steps:');
    for (final s in _steps) {
      stdout.writeln('  - ${s.name.padRight(22)} ${s.command.join(' ')}');
    }
    return;
  }

  final results = <_Result>[];
  for (var i = 0; i < _steps.length; i++) {
    final step = _steps[i];
    _printHeader(i + 1, _steps.length, step);
    final r = await _runStep(step);
    results.add(r);
    if (!r.ok) {
      _printFailure(step, r);
      if (!keepGoing) {
        _printSummary(results);
        exit(1);
      }
    } else {
      stdout.writeln(
          '$_green✅ ${step.name} — ${r.elapsed.inMilliseconds} ms$_reset\n');
    }
  }
  _printSummary(results);
  final failures = results.where((r) => !r.ok).length;
  exit(failures == 0 ? 0 : 1);
}

void _printHeader(int n, int total, Step step) {
  stdout.writeln('$_cyan$_bold━━ [$n/$total] ${step.name} ━━$_reset');
  stdout.writeln('$_cyan   ${step.command.join(' ')}$_reset');
  final why = step.rationale;
  if (why != null) {
    stdout.writeln('$_cyan   why: $why$_reset');
  }
  stdout.writeln('');
}

void _printFailure(Step step, _Result r) {
  stdout.writeln('$_red❌ ${step.name} failed (exit ${r.exitCode})$_reset\n');
}

void _printSummary(List<_Result> results) {
  stdout.writeln('$_bold━━ summary ━━$_reset');
  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    final name = _steps[i].name;
    final color = r.ok ? _green : _red;
    final mark = r.ok ? '✅' : '❌';
    stdout.writeln(
      '$color$mark ${name.padRight(22)} ${r.elapsed.inMilliseconds.toString().padLeft(6)} ms$_reset',
    );
  }
  final failed = results.where((r) => !r.ok).length;
  stdout.writeln('');
  if (failed == 0) {
    stdout.writeln('$_green${_bold}all ${results.length} checks passed.'
        ' ready for: dart pub publish$_reset');
  } else {
    stdout.writeln('$_red$_bold$failed of ${results.length} failed.$_reset');
  }
}

Future<_Result> _runStep(Step step) async {
  final sw = Stopwatch()..start();
  final proc = await Process.start(
    step.command.first,
    step.command.sublist(1),
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await proc.exitCode;
  sw.stop();
  return _Result(ok: code == 0, exitCode: code, elapsed: sw.elapsed);
}

class _Result {
  const _Result({
    required this.ok,
    required this.exitCode,
    required this.elapsed,
  });
  final bool ok;
  final int exitCode;
  final Duration elapsed;
}
