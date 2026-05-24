/// Parsed Whois response. Fields are best-effort — different TLDs and
/// registrars use different formats, so any field may be null.
class WhoisResponse {
  /// Creates a [WhoisResponse]. Only [domain] is required; every other field
  /// is optional because different TLDs expose different metadata.
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

  /// The (normalised) domain that was queried, e.g. `'google.com'`.
  final String domain;

  /// The whois server we ultimately queried (after IANA referral).
  final String? authoritativeServer;

  /// Registrar name as reported by the authoritative server. Null if the
  /// registry didn't expose one (typical for many ccTLDs).
  final String? registrar;

  /// Domain creation / registration timestamp, parsed from the response. Null
  /// when the registry didn't include a creation field or used an unrecognised
  /// date format.
  final DateTime? createdAt;

  /// Domain expiry timestamp. Null when not present in the response.
  final DateTime? expiresAt;

  /// Last-updated timestamp from the registry. Null when not present.
  final DateTime? updatedAt;

  /// EPP / registry status codes (e.g. `clientTransferProhibited`). Empty when
  /// the registry didn't expose status lines.
  final List<String> statuses;

  /// Lower-cased name servers returned by the registry, deduplicated and in
  /// the order they appeared.
  final List<String> nameServers;

  /// Raw text from the authoritative server. Useful for debugging when a
  /// structured field came back null.
  final String rawText;

  /// Round-trip duration covering both IANA referral and authoritative query.
  final Duration? latency;

  /// Days remaining until expiry. Negative if already expired.
  int? get daysUntilExpiry {
    final exp = expiresAt;
    if (exp == null) return null;
    return exp.difference(DateTime.now()).inDays;
  }

  /// JSON-serialisable view of this response.
  ///
  /// Dates are emitted as ISO 8601 strings, [latency] as `latency_ms`. Set
  /// [includeRaw] to false to drop the (potentially large) raw text payload.
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
