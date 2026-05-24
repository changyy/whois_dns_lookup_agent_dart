/// A DNS server we query. [ip] is the resolver IP, except when [isLocal] is
/// true — in that case [ip] is a sentinel and the OS's configured resolver is
/// used via `InternetAddress.lookup`.
class DnsServer {
  /// Creates a [DnsServer] descriptor.
  ///
  /// [name] is a short human-readable label (e.g. `'Google'`). [ip] is the
  /// resolver's IPv4 address, or any sentinel string when [isLocal] is true.
  /// [operator] names the organisation that runs the resolver. [note] is an
  /// optional one-liner shown alongside the name (e.g. `'CN region'`).
  const DnsServer({
    required this.name,
    required this.ip,
    required this.operator,
    this.note,
    this.isLocal = false,
  });

  /// Short human-readable label, e.g. `'Google'` or `'Cloudflare Malware'`.
  final String name;

  /// Resolver IPv4 address. Ignored (treated as a sentinel) when [isLocal]
  /// is true.
  final String ip;

  /// Organisation operating the resolver, e.g. `'Cloudflare'`.
  final String operator;

  /// Optional descriptive note shown next to [name], e.g. `'blocks malware'`
  /// or `'CN region'`. Null when no note applies.
  final String? note;

  /// When true, this entry represents the OS's configured local resolver and
  /// is queried via `InternetAddress.lookup` rather than a raw UDP packet.
  final bool isLocal;

  /// JSON-serialisable map. Omits [note] when null and `is_local` when false.
  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'operator': operator,
        if (note != null) 'note': note,
        if (isLocal) 'is_local': true,
      };

  @override
  String toString() => 'DnsServer($name @ $ip)';
}
