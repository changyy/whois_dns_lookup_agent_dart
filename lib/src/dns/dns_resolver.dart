import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'dns_result.dart';
import 'dns_server.dart';
import 'dns_servers.dart';

/// Pure-Dart UDP DNS resolver. No package dependencies.
///
/// - Sends a standard recursive A-record query (RFC 1035) on port 53.
/// - Parses the answer section, including pointer-compressed names.
/// - For servers marked [DnsServer.isLocal], delegates to
///   `InternetAddress.lookup`, which uses the OS's configured DNS resolver.
///   This is useful for detecting captive portals, ISP rewrites, and other
///   DNS-level interference by comparing the local answer to public DNS.
class DnsResolver {
  /// Query [hostname] against [server] for IPv4 A records.
  Future<DnsResult> queryA(
    String hostname,
    DnsServer server, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (server.isLocal) {
      return _queryLocal(hostname, server, timeout);
    }
    final stopwatch = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      final query = _buildQuery(hostname);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(query, InternetAddress(server.ip), 53);

      final ips = await _awaitResponse(socket, timeout);
      stopwatch.stop();
      return DnsResult(server: server, ips: ips, latency: stopwatch.elapsed);
    } on TimeoutException {
      stopwatch.stop();
      return DnsResult(
        server: server,
        ips: const [],
        latency: stopwatch.elapsed,
        error: 'timeout',
      );
    } catch (e) {
      stopwatch.stop();
      return DnsResult(
        server: server,
        ips: const [],
        latency: stopwatch.elapsed,
        error: e.toString(),
      );
    } finally {
      socket?.close();
    }
  }

  /// Query [hostname] in parallel against every server in [servers]
  /// (defaults to [DnsServers.defaults]). Returns once every query has
  /// completed (success, timeout, or error).
  Future<List<DnsResult>> queryAll(
    String hostname, {
    List<DnsServer>? servers,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final list = servers ?? DnsServers.defaults;
    return Future.wait(
      list.map((s) => queryA(hostname, s, timeout: timeout)),
    );
  }

  /// Use the OS's configured DNS resolver via `InternetAddress.lookup`.
  Future<DnsResult> _queryLocal(
    String hostname,
    DnsServer server,
    Duration timeout,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final addrs = await InternetAddress.lookup(
        hostname,
        type: InternetAddressType.IPv4,
      ).timeout(timeout);
      stopwatch.stop();
      return DnsResult(
        server: server,
        ips: addrs.map((a) => a.address).toList(),
        latency: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return DnsResult(
        server: server,
        ips: const [],
        latency: stopwatch.elapsed,
        error: 'timeout',
      );
    } catch (e) {
      stopwatch.stop();
      return DnsResult(
        server: server,
        ips: const [],
        latency: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }

  Future<List<String>> _awaitResponse(
    RawDatagramSocket socket,
    Duration timeout,
  ) {
    final completer = Completer<List<String>>();
    late StreamSubscription<RawSocketEvent> sub;
    Timer? timer;

    void finish(List<String> Function() compute) {
      if (completer.isCompleted) return;
      timer?.cancel();
      sub.cancel();
      try {
        completer.complete(compute());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }

    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      finish(() => _parseResponse(datagram.data));
    });

    timer = Timer(timeout, () {
      if (completer.isCompleted) return;
      sub.cancel();
      completer.completeError(TimeoutException('DNS query timed out'));
    });

    return completer.future;
  }

  // ----- query construction -------------------------------------------------

  Uint8List _buildQuery(String hostname) {
    final builder = BytesBuilder();
    final id = Random().nextInt(0x10000);

    _addU16(builder, id);
    _addU16(builder, 0x0100); // RD = recursion desired
    _addU16(builder, 1); // QDCOUNT
    _addU16(builder, 0); // ANCOUNT
    _addU16(builder, 0); // NSCOUNT
    _addU16(builder, 0); // ARCOUNT

    for (final label in hostname.split('.')) {
      final bytes = label.codeUnits;
      if (bytes.isEmpty) continue;
      if (bytes.length > 63) {
        throw FormatException('DNS label too long: $label');
      }
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0);
    _addU16(builder, 1); // QTYPE = A
    _addU16(builder, 1); // QCLASS = IN

    return builder.takeBytes();
  }

  void _addU16(BytesBuilder b, int v) {
    b.addByte((v >> 8) & 0xff);
    b.addByte(v & 0xff);
  }

  // ----- response parsing ---------------------------------------------------

  List<String> _parseResponse(Uint8List data) {
    if (data.length < 12) {
      throw FormatException('DNS response too short (${data.length} bytes)');
    }
    final rcode = data[3] & 0x0f;
    if (rcode != 0) {
      throw FormatException('DNS RCODE=$rcode');
    }

    final ancount = _readU16(data, 6);
    if (ancount == 0) return const [];

    var offset = 12;
    offset = _skipName(data, offset);
    offset += 4; // QTYPE + QCLASS

    final ips = <String>[];
    for (var i = 0; i < ancount; i++) {
      if (offset >= data.length) break;
      offset = _skipName(data, offset);
      if (offset + 10 > data.length) break;

      final type = _readU16(data, offset);
      final rdLength = _readU16(data, offset + 8);
      offset += 10;

      if (offset + rdLength > data.length) break;

      if (type == 1 && rdLength == 4) {
        ips.add(
          '${data[offset]}.${data[offset + 1]}.${data[offset + 2]}.${data[offset + 3]}',
        );
      }
      offset += rdLength;
    }
    return ips;
  }

  int _skipName(Uint8List data, int offset) {
    while (offset < data.length) {
      final len = data[offset];
      if (len == 0) return offset + 1;
      if ((len & 0xc0) == 0xc0) return offset + 2;
      offset += 1 + len;
    }
    return offset;
  }

  int _readU16(Uint8List data, int offset) =>
      (data[offset] << 8) | data[offset + 1];
}
