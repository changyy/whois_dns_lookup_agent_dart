#!/usr/bin/env dart
// CLI entry: whois_dns_lookup_agent <hostname-or-domain> [options]
//
// Emits a single-line JSON object to stdout:
//   {"status": true,  "error": [], "input": "...", "dns_lookup": {...}, "whois": {...}}
//   {"status": false, "error": [{"feature":"dns|whois|input","message":"..."}], ...}
//
// Designed for shell pipelines:
//   whois_dns_lookup_agent google.com | jq '.whois.expires_at'

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:whois_dns_lookup_agent/whois_dns_lookup_agent.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addFlag('dns',
        defaultsTo: true,
        help: 'Run the multi-server DNS lookup.')
    ..addFlag('whois',
        defaultsTo: true,
        help: 'Run the Whois lookup.')
    ..addFlag('strip-subdomain',
        defaultsTo: true,
        help: 'Reduce hostname to its registrable domain (eTLD+1) before '
            'Whois query (www.foo.com → foo.com).')
    ..addOption('timeout',
        defaultsTo: '5',
        help: 'Per-query timeout in seconds.')
    ..addOption('indent',
        help: 'Indent JSON output by N spaces (default: compact one-line).')
    ..addFlag('include-raw',
        defaultsTo: false,
        help: 'Include the raw whois response in the JSON output.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show this help.')
    ..addFlag('version',
        negatable: false, help: 'Print version and exit.');

  ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('argument error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(2);
  }

  if (args['help'] as bool) {
    stdout.writeln('Usage: whois_dns_lookup_agent <hostname-or-domain> [options]');
    stdout.writeln(parser.usage);
    exit(0);
  }
  if (args['version'] as bool) {
    stdout.writeln(WhoisDnsLookupAgentVersion.version);
    exit(0);
  }

  // Input: positional arg, or stdin if piped.
  String? input = args.rest.isNotEmpty ? args.rest.first : null;
  if (input == null && !stdin.hasTerminal) {
    final s = await stdin
        .transform(const SystemEncoding().decoder)
        .join();
    final trimmed = s.trim();
    if (trimmed.isNotEmpty) input = trimmed.split(RegExp(r'\s+')).first;
  }
  if (input == null || input.isEmpty) {
    final errOut = jsonEncode({
      'status': false,
      'error': [
        {'feature': 'input', 'message': 'no hostname provided'},
      ],
      'input': null,
      'dns_lookup': null,
      'whois': null,
    });
    stdout.writeln(errOut);
    exit(2);
  }

  final timeoutSec = int.tryParse(args['timeout'] as String);
  if (timeoutSec == null || timeoutSec <= 0) {
    stderr.writeln('--timeout must be a positive integer (seconds)');
    exit(2);
  }
  final timeout = Duration(seconds: timeoutSec);

  final wantDns = args['dns'] as bool;
  final wantWhois = args['whois'] as bool;
  final stripSubdomain = args['strip-subdomain'] as bool;
  final includeRaw = args['include-raw'] as bool;
  final indentArg = args['indent'] as String?;
  final indent = indentArg == null ? null : int.tryParse(indentArg);
  if (indentArg != null && indent == null) {
    stderr.writeln('--indent must be an integer');
    exit(2);
  }

  final errors = <Map<String, String>>[];
  Map<String, dynamic>? dnsJson;
  Map<String, dynamic>? whoisJson;

  final futures = <Future<void>>[];
  if (wantDns) {
    futures.add(() async {
      try {
        dnsJson = await _runDns(input!, timeout: timeout);
      } catch (e) {
        errors.add({'feature': 'dns', 'message': e.toString()});
      }
    }());
  }
  if (wantWhois) {
    futures.add(() async {
      try {
        whoisJson = await _runWhois(
          input!,
          timeout: timeout,
          stripSubdomain: stripSubdomain,
          includeRaw: includeRaw,
        );
      } catch (e) {
        errors.add({'feature': 'whois', 'message': e.toString()});
      }
    }());
  }
  await Future.wait(futures);

  final ok = errors.isEmpty &&
      (!wantDns || dnsJson != null) &&
      (!wantWhois || whoisJson != null);

  final out = <String, dynamic>{
    'status': ok,
    'error': errors,
    'agent': {
      'package': WhoisDnsLookupAgentVersion.packageName,
      'version': WhoisDnsLookupAgentVersion.version,
      'query_at': DateTime.now().toUtc().toIso8601String(),
    },
    'input': input,
    'dns_lookup': dnsJson,
    'whois': whoisJson,
  };

  final encoder = indent == null
      ? const JsonEncoder()
      : JsonEncoder.withIndent(' ' * indent);
  stdout.writeln(encoder.convert(out));
  exit(ok ? 0 : 1);
}

Future<Map<String, dynamic>> _runDns(String hostname, {required Duration timeout}) async {
  final resolver = DnsResolver();
  final results = await resolver.queryAll(hostname, timeout: timeout);

  final groups = _groupByIps(results);

  return {
    'queried': hostname,
    'server_count': results.length,
    'results': results.map((r) => r.toJson()).toList(),
    'groups': groups,
  };
}

Future<Map<String, dynamic>> _runWhois(
  String input, {
  required Duration timeout,
  required bool stripSubdomain,
  required bool includeRaw,
}) async {
  final client = WhoisClient();
  final resp = await client.lookup(
    input,
    timeout: timeout,
    stripSubdomain: stripSubdomain,
  );
  return resp.toJson(includeRaw: includeRaw);
}

/// Bucket DNS results by their sorted IP set. Useful for shell consumers
/// who want a one-line "do all servers agree?" answer.
List<Map<String, dynamic>> _groupByIps(List<DnsResult> results) {
  final buckets = <String, _Bucket>{};
  for (final r in results) {
    if (!r.isSuccess) continue;
    final sorted = [...r.ips]..sort(_ipCompare);
    final key = sorted.join(',');
    buckets.putIfAbsent(key, () => _Bucket(sorted)).servers.add(r.server.name);
  }
  final list = buckets.values.toList()
    ..sort((a, b) => b.servers.length.compareTo(a.servers.length));
  return list
      .map((b) => {
            'ips': b.ips,
            'server_count': b.servers.length,
            'server_names': b.servers,
          })
      .toList();
}

class _Bucket {
  _Bucket(this.ips);
  final List<String> ips;
  final List<String> servers = [];
}

int _ipCompare(String a, String b) {
  final pa = a.split('.').map(int.tryParse).toList();
  final pb = b.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 4; i++) {
    final ai = (i < pa.length ? pa[i] : null) ?? -1;
    final bi = (i < pb.length ? pb[i] : null) ?? -1;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}
