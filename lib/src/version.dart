/// Version constant for the whois_dns_lookup_agent package.
///
/// Format: `1.YYYYmmdd.HHMMSS` (zero-padded, Asia/Taipei build clock,
/// no DST). Mirrors the scheme used by sibling tools but with second
/// precision so multiple same-day cuts don't collide.
class WhoisDnsLookupAgentVersion {
  WhoisDnsLookupAgentVersion._();

  /// Semantic-ish version string baked at release time. Format:
  /// `1.YYYYmmdd.HHMMSS` (Asia/Taipei, no DST).
  static const String version = '1.20260524.125658';

  /// Canonical pub.dev package name.
  static const String packageName = 'whois_dns_lookup_agent';

  /// `{package, version}` map, handy for `--version` JSON output.
  static Map<String, String> get info => {
        'package': packageName,
        'version': version,
      };
}
