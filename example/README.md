# whois_dns_lookup_agent — example

A minimal end-to-end demo: fan out DNS A-record queries against every server in
`DnsServers.defaults` (Google, Cloudflare, Quad9, Alibaba, the OS resolver, …)
and run a Whois lookup through the IANA → registry referral chain, all in
parallel.

## Run

From the package root:

```sh
dart run example/example.dart google.com
```

Omit the argument and it defaults to `google.com`.

## What you get

```text
== Looking up google.com ==

--- DNS (16 servers) ---
Local                    [142.250.x.x]  (8 ms)
Google                   [142.250.x.x]  (12 ms)
Cloudflare               [142.250.x.x]  (10 ms)
...

--- Whois ---
Authoritative: whois.markmonitor.com
Registrar:     MarkMonitor Inc.
Created:       1997-09-15 04:00:00.000
Expires:       2028-09-14 04:00:00.000
Days left:     900
Name servers:  [ns1.google.com, ns2.google.com, ...]
```

## Programmatic use

```dart
import 'package:whois_dns_lookup_agent/whois_dns_lookup_agent.dart';

Future<void> main() async {
  // Query one specific resolver.
  final one = await DnsResolver().queryA(
    'example.com',
    const DnsServer(name: 'Google', ip: '8.8.8.8', operator: 'Google'),
  );
  print(one.ips);

  // Or fan out against every default server.
  final all = await DnsResolver().queryAll('example.com');
  for (final r in all) {
    print('${r.server.name}: ${r.ips} (${r.latency?.inMilliseconds} ms)');
  }

  // Whois with IANA referral; subdomains are stripped by default.
  final w = await WhoisClient().lookup('www.example.com');
  print('Registrar: ${w.registrar}, expires ${w.expiresAt}');
}
```

See [`example.dart`](example.dart) and [`basic_usage.dart`](basic_usage.dart) for
runnable scripts.
