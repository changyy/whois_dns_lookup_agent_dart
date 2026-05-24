/// A DNS server we query. [ip] is the resolver IP, except when [isLocal] is
/// true — in that case [ip] is a sentinel and the OS's configured resolver is
/// used via `InternetAddress.lookup`.
class DnsServer {
  const DnsServer({
    required this.name,
    required this.ip,
    required this.operator,
    this.note,
    this.isLocal = false,
  });

  final String name;
  final String ip;
  final String operator;
  final String? note;
  final bool isLocal;

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
