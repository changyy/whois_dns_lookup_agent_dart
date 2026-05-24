// Minimal example for pub.dev: query DNS across multiple resolvers and run a
// Whois lookup for one hostname. Run from the package root:
//
//   dart run example/example.dart google.com
//
// See `example/basic_usage.dart` for an identical, more talkative variant.

import 'dart:async';

import 'package:whois_dns_lookup_agent/whois_dns_lookup_agent.dart';

Future<void> main(List<String> argv) async {
  final hostname = argv.isNotEmpty ? argv.first : 'google.com';
  print('== Looking up $hostname ==\n');

  final resolver = DnsResolver();
  final whois = WhoisClient();

  // Fan out DNS queries against every server in DnsServers.defaults and run
  // the Whois lookup in parallel.
  final results = await Future.wait<Object>([
    resolver.queryAll(hostname),
    whois.lookup(hostname),
  ]);

  final dns = results[0] as List<DnsResult>;
  final w = results[1] as WhoisResponse;

  print('--- DNS (${dns.length} servers) ---');
  for (final r in dns) {
    final label = r.server.name.padRight(24);
    if (r.isSuccess) {
      print('$label ${r.ips}  (${r.latency!.inMilliseconds} ms)');
    } else if (r.isError) {
      print('$label ERROR ${r.error}');
    } else if (r.isEmpty) {
      print('$label (no record)');
    } else {
      print('$label (pending)');
    }
  }

  print('\n--- Whois ---');
  print('Authoritative: ${w.authoritativeServer}');
  print('Registrar:     ${w.registrar}');
  print('Created:       ${w.createdAt}');
  print('Expires:       ${w.expiresAt}');
  print('Updated:       ${w.updatedAt}');
  print('Days left:     ${w.daysUntilExpiry}');
  print('Name servers:  ${w.nameServers}');
  print('Statuses:      ${w.statuses}');
}
