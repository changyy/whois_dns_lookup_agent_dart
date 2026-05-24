# Changelog

Version format: `1.YYYYmmdd.HHMMSS` (zero-padded, Asia/Taipei build clock, no DST).

## 1.20260524.125658

- Docs: added dartdoc comments to every public constructor, field, getter, and
  method across `DnsResolver`, `DnsResult`, `DnsServer`, `DnsServers`,
  `WhoisClient`, `WhoisResponse`, and `WhoisDnsLookupAgentVersion`. Lifts
  documented API coverage from 29.2% to ~100% for pana scoring.
- Example: added `example/example.dart` (pub.dev-recognised filename) and an
  `example/README.md` with run instructions and a programmatic-use snippet.
  Existing `example/basic_usage.dart` is left in place. Fixes the
  "Package has an example" pana check (was 0/10).

## 1.20260524.114512

- CLI: output now includes a top-level `agent` block with `package`, `version`,
  and `query_at` (UTC ISO 8601). Lets downstream consumers (monitoring
  scripts, caches) record which version produced a payload without needing
  to invoke `--version` separately.

## 1.20260524.095000

Initial release. Extracted from `app.ainfo.dns.checker` for reuse.

- `DnsResolver`: pure-Dart UDP resolver with parallel `queryAll` across
  16 curated public DNS servers (Local OS resolver + Google + Cloudflare
  × 3 variants + Quad9 + OpenDNS + AdGuard + Alibaba × 2 + CleanBrowsing +
  DNS.SB). Per-server timeout, error capture, latency measurement.
- `DnsServer` / `DnsServers` / `DnsResult` models with `toJson()`.
- `WhoisClient`: RFC 3912 client with IANA referral chain. `stripSubdomain`
  switch (defaults to `true`) reduces input to eTLD+1 before querying.
  Built-in 2-segment ccTLD list (`co.uk`, `com.tw`, etc.).
- `WhoisResponse` parses registrar / creation / expiry / updated dates +
  status codes + name servers from common TLD formats.
- `whois_dns_lookup_agent` CLI emits JSON `{status, error, input,
  dns_lookup, whois}` for shell pipelines. Supports `--dns / --no-dns`,
  `--whois / --no-whois`, `--strip-subdomain / --no-strip-subdomain`,
  `--timeout`, `--indent`, `--include-raw`, stdin input.
