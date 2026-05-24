/// Version constant for the whois_dns_lookup_agent package.
///
/// Format: `1.YYYYmmdd.HHMMSS` (zero-padded UTC build clock). Mirrors the
/// scheme used by sibling tools but with second precision so multiple
/// same-day cuts don't collide.
class WhoisDnsLookupAgentVersion {
  WhoisDnsLookupAgentVersion._();

  static const String version = '1.20260524.110000';
  static const String packageName = 'whois_dns_lookup_agent';

  static Map<String, String> get info => {
        'package': packageName,
        'version': version,
      };
}
