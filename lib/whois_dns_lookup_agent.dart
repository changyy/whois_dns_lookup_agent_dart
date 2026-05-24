/// Pure-Dart multi-server DNS lookup + Whois client.
///
/// - [DnsResolver] / [DnsServers] / [DnsServer] / [DnsResult]: parallel
///   queries against curated public resolvers (Google, Cloudflare, Quad9,
///   Alibaba, etc.) plus the OS's configured local resolver. Useful for
///   detecting captive portals, ISP DNS rewrites, and CDN edge differences.
/// - [WhoisClient] / [WhoisResponse]: RFC 3912 client with IANA referral
///   for TLD → registry handoff, plus a `stripSubdomain` switch that
///   normalises `www.foo.com` → `foo.com` before querying.
library;

export 'src/dns/dns_resolver.dart';
export 'src/dns/dns_result.dart';
export 'src/dns/dns_server.dart';
export 'src/dns/dns_servers.dart';
export 'src/whois/whois_client.dart';
export 'src/whois/whois_response.dart';
export 'src/version.dart';
