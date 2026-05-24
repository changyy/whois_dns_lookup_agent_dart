# whois_dns_lookup_agent

[![pub package](https://img.shields.io/pub/v/whois_dns_lookup_agent.svg)](https://pub.dev/packages/whois_dns_lookup_agent)
[![pub points](https://img.shields.io/pub/points/whois_dns_lookup_agent)](https://pub.dev/packages/whois_dns_lookup_agent/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0-blue.svg)](https://dart.dev/get-dart)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)](https://pub.dev/packages/whois_dns_lookup_agent)

Pure-Dart multi-server DNS lookup + Whois client.  Zero runtime
dependencies (only `args` for the CLI). Ships a `whois_dns_lookup_agent`
CLI that emits JSON, suitable for shell pipelines.

## Why

- **DNS divergence at a glance.** Queries the OS resolver and 15+ public
  recursive DNS servers (Google, Cloudflare, Quad9, Alibaba, AdGuard,
  CleanBrowsing, …) in parallel. The CLI groups responses so you can
  spot when your local network's DNS disagrees with the public Internet
  (captive portals, ISP rewrites, content filtering).
- **Whois without the brittle text.** RFC 3912 client that handles the
  IANA → registry handoff, normalises `www.foo.com` → `foo.com` by
  default (with a switch to disable), and parses the headline fields
  (registrar, creation/expiry dates, status, name servers) across .com,
  .net, .org, common ccTLDs, etc.
- **No native code.** Pure `dart:io` UDP for DNS and TCP/43 for Whois.
  Works on every platform Dart supports.

## CLI

Four ways to run, depending on where you are in the dev lifecycle:

```bash
# (a) From the package source tree — fastest iteration loop
dart bin/whois_dns_lookup_agent.dart www.google.com | jq .
dart run bin/whois_dns_lookup_agent.dart www.google.com    # equivalent

# (b) From the package source tree, using the executable name registered in pubspec
dart run :whois_dns_lookup_agent www.google.com

# (c) Install globally (then runs anywhere)
dart pub global activate whois_dns_lookup_agent            # from pub.dev
dart pub global activate --source path .                   # from local checkout
whois_dns_lookup_agent www.google.com

# (d) Compile to a single binary (no Dart runtime needed at runtime)
dart compile exe bin/whois_dns_lookup_agent.dart -o whois_dns_lookup_agent
./whois_dns_lookup_agent www.google.com
```

### Common recipes

#### Pretty-print

```bash
$ dart bin/whois_dns_lookup_agent.dart google.com --indent 2
{
  "status": true,
  "error": [],
  "input": "google.com",
  "dns_lookup": { ... },
  "whois": { ... }
}
```

#### Pull just the headline whois fields

```bash
$ dart bin/whois_dns_lookup_agent.dart www.google.com \
    | jq '.whois | {domain, registrar, created_at, expires_at, days_until_expiry, name_servers}'

{
  "domain": "google.com",
  "registrar": "MarkMonitor Inc.",
  "created_at": "1997-09-15T04:00:00.000Z",
  "expires_at": "2028-09-14T04:00:00.000Z",
  "days_until_expiry": 844,
  "name_servers": [
    "ns1.google.com",
    "ns2.google.com",
    "ns3.google.com",
    "ns4.google.com"
  ]
}
```

#### See which DNS servers agree (most common answer first)

```bash
$ dart bin/whois_dns_lookup_agent.dart cloudflare.com --no-whois \
    | jq '.dns_lookup.groups[] | {server_count, ips, sample_servers: .server_names[0:3]}'

{
  "server_count": 16,
  "ips": ["104.16.132.229", "104.16.133.229"],
  "sample_servers": ["Local", "Google", "Google (2)"]
}
```

#### One field as a scalar (e.g. for monitoring scripts)

```bash
$ dart bin/whois_dns_lookup_agent.dart example.com | jq -r '.whois.days_until_expiry'
81

# Alert when a domain expires in less than 30 days
$ days=$(dart bin/whois_dns_lookup_agent.dart example.com | jq -r '.whois.days_until_expiry')
$ [ "$days" -lt 30 ] && echo "EXPIRING SOON: $days days"
```

#### Stdin (handy in pipes)

```bash
$ echo 'github.com' | dart bin/whois_dns_lookup_agent.dart --no-dns \
    | jq '.whois | {registrar, expires_at}'

{
  "registrar": "MarkMonitor Inc.",
  "expires_at": "2026-10-09T18:20:50.000Z"
}
```

#### Force the exact input (skip the eTLD+1 reduction)

```bash
# Default: www.google.com gets normalised to google.com before whois
$ dart bin/whois_dns_lookup_agent.dart www.google.com --no-dns | jq -r '.whois.domain'
google.com

# Explicit: query the raw input (registry will probably return no match)
$ dart bin/whois_dns_lookup_agent.dart www.google.com --no-dns --no-strip-subdomain \
    | jq -r '.whois.domain'
www.google.com
```

#### Run DNS or Whois alone

```bash
dart bin/whois_dns_lookup_agent.dart google.com --no-whois     # DNS only
dart bin/whois_dns_lookup_agent.dart google.com --no-dns       # Whois only
```

#### Include the raw whois text (when the parser missed a field you care about)

```bash
$ dart bin/whois_dns_lookup_agent.dart google.com --include-raw \
    | jq -r '.whois.raw_text' | head -5
   Domain Name: GOOGLE.COM
   Registry Domain ID: 2138514_DOMAIN_COM-VRSN
   Registrar WHOIS Server: whois.markmonitor.com
   ...
```

#### Tighter timeout (default 5s)

```bash
dart bin/whois_dns_lookup_agent.dart slow-tld.example --timeout 2
```

#### Full output reference (`www.google.com | jq .`)

The canonical end-to-end demo. Click to expand the full JSON — 16 DNS
servers (Local + 15 public), grouped by IP set, plus the Verisign whois
record.

<details>
<summary><code>dart bin/whois_dns_lookup_agent.dart www.google.com | jq .</code></summary>

```json
{
  "status": true,
  "error": [],
  "agent": {
    "package": "whois_dns_lookup_agent",
    "version": "1.20260524.110000",
    "query_at": "2026-05-24T03:25:23.202817Z"
  },
  "input": "www.google.com",
  "dns_lookup": {
    "queried": "www.google.com",
    "server_count": 16,
    "results": [
      {
        "server": {
          "name": "Local",
          "ip": "system",
          "operator": "this device",
          "note": "OS resolver",
          "is_local": true
        },
        "ips": [
          "142.251.151.119",
          "142.251.150.119",
          "142.251.152.119",
          "142.251.157.119",
          "142.251.155.119",
          "142.251.156.119",
          "142.251.154.119",
          "142.251.153.119"
        ],
        "latency_ms": 27,
        "error": null
      },
      {
        "server": { "name": "Google", "ip": "8.8.8.8", "operator": "Google" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 21,
        "error": null
      },
      {
        "server": { "name": "Google (2)", "ip": "8.8.4.4", "operator": "Google" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 22,
        "error": null
      },
      {
        "server": { "name": "Cloudflare", "ip": "1.1.1.1", "operator": "Cloudflare" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 22,
        "error": null
      },
      {
        "server": { "name": "Cloudflare (2)", "ip": "1.0.0.1", "operator": "Cloudflare" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 22,
        "error": null
      },
      {
        "server": { "name": "Cloudflare Malware", "ip": "1.1.1.2", "operator": "Cloudflare", "note": "blocks malware" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 23,
        "error": null
      },
      {
        "server": { "name": "Cloudflare Malware (2)", "ip": "1.0.0.2", "operator": "Cloudflare", "note": "blocks malware" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 23,
        "error": null
      },
      {
        "server": { "name": "Cloudflare Family", "ip": "1.1.1.3", "operator": "Cloudflare", "note": "blocks malware + adult" },
        "ips": ["216.239.38.120"],
        "latency_ms": 26,
        "error": null
      },
      {
        "server": { "name": "Cloudflare Family (2)", "ip": "1.0.0.3", "operator": "Cloudflare", "note": "blocks malware + adult" },
        "ips": ["216.239.38.120"],
        "latency_ms": 26,
        "error": null
      },
      {
        "server": { "name": "Quad9", "ip": "9.9.9.9", "operator": "Quad9" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 140,
        "error": null
      },
      {
        "server": { "name": "OpenDNS", "ip": "208.67.222.222", "operator": "Cisco OpenDNS" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 122,
        "error": null
      },
      {
        "server": { "name": "AdGuard", "ip": "94.140.14.14", "operator": "AdGuard" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 100,
        "error": null
      },
      {
        "server": { "name": "Alibaba", "ip": "223.5.5.5", "operator": "Alibaba", "note": "CN region" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 66,
        "error": null
      },
      {
        "server": { "name": "Alibaba (2)", "ip": "223.6.6.6", "operator": "Alibaba", "note": "CN region" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 100,
        "error": null
      },
      {
        "server": { "name": "CleanBrowsing", "ip": "185.228.168.9", "operator": "CleanBrowsing" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 134,
        "error": null
      },
      {
        "server": { "name": "DNS.SB", "ip": "185.222.222.222", "operator": "DNS.SB" },
        "ips": ["142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119", "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"],
        "latency_ms": 105,
        "error": null
      }
    ],
    "groups": [
      {
        "ips": [
          "142.251.150.119", "142.251.151.119", "142.251.152.119", "142.251.153.119",
          "142.251.154.119", "142.251.155.119", "142.251.156.119", "142.251.157.119"
        ],
        "server_count": 14,
        "server_names": [
          "Local", "Google", "Google (2)",
          "Cloudflare", "Cloudflare (2)",
          "Cloudflare Malware", "Cloudflare Malware (2)",
          "Quad9", "OpenDNS", "AdGuard",
          "Alibaba", "Alibaba (2)",
          "CleanBrowsing", "DNS.SB"
        ]
      },
      {
        "ips": ["216.239.38.120"],
        "server_count": 2,
        "server_names": ["Cloudflare Family", "Cloudflare Family (2)"]
      }
    ]
  },
  "whois": {
    "domain": "google.com",
    "authoritative_server": "whois.verisign-grs.com",
    "registrar": "MarkMonitor Inc.",
    "created_at": "1997-09-15T04:00:00.000Z",
    "expires_at": "2028-09-14T04:00:00.000Z",
    "updated_at": "2019-09-09T15:39:04.000Z",
    "days_until_expiry": 844,
    "statuses": [
      "clientDeleteProhibited",
      "clientTransferProhibited",
      "clientUpdateProhibited",
      "serverDeleteProhibited",
      "serverTransferProhibited",
      "serverUpdateProhibited"
    ],
    "name_servers": [
      "ns1.google.com", "ns2.google.com",
      "ns3.google.com", "ns4.google.com"
    ],
    "latency_ms": 642
  }
}
```

</details>

**What to notice in this output:**

- **`agent` block** — package + version + UTC timestamp, so downstream
  consumers (monitors, caches) can record which version produced the
  payload.
- **`dns_lookup.groups`** — 14 servers (including your `Local` OS
  resolver) agree on the standard 8-IP geo-routed answer.  Two
  Cloudflare Family resolvers diverge — they return `216.239.38.120`,
  which is Google's "this content is blocked" landing page. That single
  data point tells you Google deems this content acceptable for family
  filters (vs. e.g. a porn site, where you'd see Family resolvers point
  somewhere else).
- **`dns_lookup.results[].ips` ordering** — within each row IPs come
  back in the order the server delivered them (DNS uses this for round
  robin). The `groups` view sorts canonically so cross-server
  comparison is deterministic.
- **`whois`** — `google.com` was normalised from `www.google.com`
  (eTLD+1), Verisign is the authoritative server, MarkMonitor is the
  registrar, expires 2028-09-14, all six ICANN status locks engaged.

### JSON shape

```jsonc
{
  "status": true,                  // false when any feature errored
  "error": [],                     // [{ "feature": "dns|whois|input", "message": "..." }]
  "agent": {
    "package": "whois_dns_lookup_agent",
    "version": "1.20260524.110000",
    "query_at": "2026-05-24T03:00:00.000Z"
  },
  "input": "www.google.com",
  "dns_lookup": {
    "queried": "www.google.com",
    "server_count": 16,
    "results": [
      {
        "server": { "name": "Local", "ip": "system", "operator": "this device", "is_local": true },
        "ips": ["142.250.x.x"],
        "latency_ms": 12,
        "error": null
      },
      // …
    ],
    "groups": [                    // grouped by sorted IP set, largest first
      { "ips": ["142.250.x.x"], "server_count": 14, "server_names": ["Local", "Google", …] },
      { "ips": ["0.0.0.0"],     "server_count": 2,  "server_names": ["Cloudflare Family", …] }
    ]
  },
  "whois": {
    "domain": "google.com",
    "authoritative_server": "whois.verisign-grs.com",
    "registrar": "MarkMonitor Inc.",
    "created_at": "1997-09-15T04:00:00.000Z",
    "expires_at": "2028-09-14T04:00:00.000Z",
    "updated_at": "2019-09-09T15:39:04.000Z",
    "days_until_expiry": 858,
    "statuses": ["clientDeleteProhibited", …],
    "name_servers": ["ns1.google.com", …],
    "latency_ms": 612
  }
}
```

Exit codes:

| code | meaning |
|------|---------|
| 0    | `status: true` (no errors) |
| 1    | at least one feature errored |
| 2    | bad arguments / no input |

## Library usage

```dart
import 'package:whois_dns_lookup_agent/whois_dns_lookup_agent.dart';

Future<void> main() async {
  final resolver = DnsResolver();
  final results = await resolver.queryAll('google.com');
  for (final r in results) {
    print('${r.server.name.padRight(24)} ${r.ips}');
  }

  final whois = WhoisClient();
  final resp = await whois.lookup('google.com');
  print('Registrar:  ${resp.registrar}');
  print('Expires in: ${resp.daysUntilExpiry} days');
}
```

### What's in the DNS server list

The 16 defaults are picked for operator diversity (catches geo-DNS, CDN
edges, content filters):

- **Local** — your OS's configured resolver
- **Google** — 8.8.8.8 / 8.8.4.4
- **Cloudflare** — 1.1.1.1 / 1.0.0.1, plus Malware-blocking (1.1.1.2 /
  1.0.0.2) and Family (1.1.1.3 / 1.0.0.3) variants
- **Quad9** — 9.9.9.9
- **OpenDNS** — 208.67.222.222
- **AdGuard** — 94.140.14.14
- **Alibaba** — 223.5.5.5 / 223.6.6.6 (Mainland China region)
- **CleanBrowsing** — 185.228.168.9
- **DNS.SB** — 185.222.222.222

Want a different set? Pass your own to `DnsResolver.queryAll(...,
servers: [...])`.

### What Whois extracts

Best-effort across TLDs:
- registrar / sponsoring registrar
- creation date (multiple aliases)
- expiry date (multiple aliases)
- updated date
- name servers
- status codes

For `.com` / `.net` the Verisign registry already returns these inline;
for some ccTLDs (`.co.uk`, `.jp`, etc.) you may need to follow up at the
registrar level. The raw response is always available in `rawText` /
`--include-raw` for further parsing.

## Development

```bash
dart pub get
dart analyze
dart test
dart run example/basic_usage.dart google.com

# Version is stored in two places — pubspec.yaml and lib/src/version.dart —
# keep them in sync with the helper script:
dart run tool/update_version.dart --check                  # verify both agree
dart run tool/update_version.dart                          # auto-bump to Taipei time
dart run tool/update_version.dart 1.20260601.090000        # set explicit

# Run the CLI without installing
dart bin/whois_dns_lookup_agent.dart www.google.com | jq .
```

After bumping the version, **also add a section to CHANGELOG.md** before
committing.

## Limitations

- **DNS** is A-record only. AAAA, MX, TXT, CNAME chasing are not in
  scope (yet).
- **Whois** parsing is line-based and best-effort. No PSL — there's a
  small built-in list of common 2-segment ccTLDs (`.co.uk`, `.com.tw`,
  …); other multi-level public suffixes will fall back to the last two
  labels.
- **RDAP** (the modern HTTPS/JSON alternative to Whois) is not yet
  implemented — happy to take a PR.

## License

MIT. See [LICENSE](./LICENSE).
