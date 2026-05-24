import 'dns_server.dart';

/// Result of a single DNS A-record query against one server.
class DnsResult {
  const DnsResult({
    required this.server,
    required this.ips,
    this.latency,
    this.error,
  });

  final DnsServer server;
  final List<String> ips;
  final Duration? latency;
  final String? error;

  bool get isPending => latency == null && error == null && ips.isEmpty;
  bool get isError => error != null;
  bool get isEmpty => !isError && ips.isEmpty && latency != null;
  bool get isSuccess => !isError && ips.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'server': server.toJson(),
        'ips': ips,
        'latency_ms': latency?.inMilliseconds,
        'error': error,
      };
}
