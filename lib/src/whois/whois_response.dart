/// Parsed Whois response. Fields are best-effort — different TLDs and
/// registrars use different formats, so any field may be null.
class WhoisResponse {
  const WhoisResponse({
    required this.domain,
    this.authoritativeServer,
    this.registrar,
    this.createdAt,
    this.expiresAt,
    this.updatedAt,
    this.statuses = const [],
    this.nameServers = const [],
    this.rawText = '',
    this.latency,
  });

  final String domain;

  /// The whois server we ultimately queried (after IANA referral).
  final String? authoritativeServer;

  final String? registrar;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final List<String> statuses;
  final List<String> nameServers;
  final String rawText;

  /// Round-trip duration covering both IANA referral and authoritative query.
  final Duration? latency;

  /// Days remaining until expiry. Negative if already expired.
  int? get daysUntilExpiry {
    final exp = expiresAt;
    if (exp == null) return null;
    return exp.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson({bool includeRaw = true}) => {
        'domain': domain,
        'authoritative_server': authoritativeServer,
        'registrar': registrar,
        'created_at': createdAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'days_until_expiry': daysUntilExpiry,
        'statuses': statuses,
        'name_servers': nameServers,
        'latency_ms': latency?.inMilliseconds,
        if (includeRaw) 'raw_text': rawText,
      };
}
