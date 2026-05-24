import 'dns_server.dart';

/// Result of a single DNS A-record query against one server.
///
/// One [DnsResult] is produced per [DnsServer] queried, regardless of whether
/// the query succeeded, timed out, errored, or returned an empty answer. Use
/// [isSuccess], [isError], [isEmpty], and [isPending] to discriminate.
class DnsResult {
  /// Creates a [DnsResult] describing the outcome of one query.
  ///
  /// [server] is required and identifies the resolver the answer came from.
  /// [ips] is the list of A-record addresses (empty on timeout/error/empty
  /// answer). [latency] is the wall-clock round trip; null only for a query
  /// that has not run yet. [error] is non-null when the query failed.
  const DnsResult({
    required this.server,
    required this.ips,
    this.latency,
    this.error,
  });

  /// The DNS server this result came from.
  final DnsServer server;

  /// IPv4 addresses returned by the server, in the order they appeared in the
  /// answer section. Empty when the query timed out, errored, or returned no
  /// A records.
  final List<String> ips;

  /// Wall-clock round-trip duration of the query. Null when the query has not
  /// been executed yet (see [isPending]).
  final Duration? latency;

  /// Non-null error string when the query failed. Common values include
  /// `'timeout'` and the stringified underlying exception. Null on success or
  /// on a successfully-completed empty answer.
  final String? error;

  /// True when this result is a placeholder for a query that has not been
  /// executed yet — no latency recorded and no error set.
  bool get isPending => latency == null && error == null && ips.isEmpty;

  /// True when the query completed with an [error] (timeout, socket failure,
  /// malformed response, …).
  bool get isError => error != null;

  /// True when the query completed successfully but the server returned no
  /// A records for the hostname.
  bool get isEmpty => !isError && ips.isEmpty && latency != null;

  /// True when the query returned at least one IP address.
  bool get isSuccess => !isError && ips.isNotEmpty;

  /// JSON-serialisable map suitable for shell pipelines or structured logging.
  ///
  /// `latency` is reported in milliseconds under the `latency_ms` key.
  Map<String, dynamic> toJson() => {
        'server': server.toJson(),
        'ips': ips,
        'latency_ms': latency?.inMilliseconds,
        'error': error,
      };
}
