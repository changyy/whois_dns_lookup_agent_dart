import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'whois_response.dart';

/// Pure-Dart Whois client (RFC 3912). No package dependencies.
///
/// Flow:
///   1. Query whois.iana.org for the TLD → response contains the authoritative
///      `whois:` line for that TLD's registry.
///   2. Open a fresh TCP socket to that authoritative server on port 43.
///   3. Send the domain followed by CRLF.
///   4. Read raw response.
///   5. Parse common fields (registrar, dates, status, name servers).
class WhoisClient {
  static const _ianaServer = 'whois.iana.org';
  static const _whoisPort = 43;

  /// Look up [domain] via the IANA → registry chain.
  ///
  /// [stripSubdomain] (default true) reduces the input to its registrable
  /// domain (eTLD+1) before querying, so `www.google.com` becomes
  /// `google.com`. Set false to query the raw input verbatim.
  Future<WhoisResponse> lookup(
    String domain, {
    Duration timeout = const Duration(seconds: 5),
    bool stripSubdomain = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalized = stripSubdomain
        ? _normalizeDomain(domain)
        : _basicCleanup(domain);
    final tld = _extractTld(normalized);

    String? authServer;
    try {
      final ianaRaw = await _whoisQuery(_ianaServer, tld, timeout: timeout);
      authServer = _extractWhoisServerFromIana(ianaRaw);
    } catch (e) {
      stopwatch.stop();
      return WhoisResponse(
        domain: normalized,
        rawText: 'IANA referral failed: $e',
        latency: stopwatch.elapsed,
      );
    }

    if (authServer == null || authServer.isEmpty) {
      stopwatch.stop();
      return WhoisResponse(
        domain: normalized,
        rawText: 'No authoritative whois server found for TLD .$tld',
        latency: stopwatch.elapsed,
      );
    }

    String raw;
    try {
      raw = await _whoisQuery(authServer, normalized, timeout: timeout);
    } catch (e) {
      stopwatch.stop();
      return WhoisResponse(
        domain: normalized,
        authoritativeServer: authServer,
        rawText: 'Authoritative query to $authServer failed: $e',
        latency: stopwatch.elapsed,
      );
    }

    stopwatch.stop();
    return _parse(
      domain: normalized,
      authoritativeServer: authServer,
      raw: raw,
      latency: stopwatch.elapsed,
    );
  }

  // ----- network ------------------------------------------------------------

  Future<String> _whoisQuery(
    String server,
    String query, {
    required Duration timeout,
  }) async {
    final socket = await Socket.connect(server, _whoisPort, timeout: timeout);
    try {
      socket.add(utf8.encode('$query\r\n'));
      await socket.flush();
      final builder = BytesBuilder();
      await for (final chunk in socket.timeout(timeout)) {
        builder.add(chunk);
      }
      return utf8.decode(builder.takeBytes(), allowMalformed: true);
    } finally {
      socket.destroy();
    }
  }

  // ----- parsing ------------------------------------------------------------

  /// Common 2-segment public suffixes we recognise without pulling in a full
  /// PSL. Covers the ccTLDs most apps actually hit.
  static const _twoSegmentSuffixes = {
    'co.uk', 'org.uk', 'ac.uk', 'gov.uk',
    'com.tw', 'org.tw', 'net.tw', 'edu.tw', 'gov.tw',
    'com.au', 'org.au', 'net.au', 'edu.au', 'gov.au',
    'co.jp', 'or.jp', 'ne.jp', 'ac.jp', 'go.jp',
    'co.nz', 'org.nz', 'net.nz',
    'com.br', 'com.cn', 'org.cn', 'net.cn',
    'co.kr', 'or.kr',
  };

  /// Strip protocol/path/port but leave the hostname intact (subdomains kept).
  String _basicCleanup(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.split('/').first;
    s = s.split(':').first;
    return s;
  }

  String _normalizeDomain(String input) {
    var s = _basicCleanup(input);
    if (s.isEmpty) return s;

    final parts = s.split('.');
    if (parts.length <= 2) return s;
    final last2 = parts.sublist(parts.length - 2).join('.');
    if (_twoSegmentSuffixes.contains(last2) && parts.length >= 3) {
      return parts.sublist(parts.length - 3).join('.');
    }
    return last2;
  }

  String _extractTld(String domain) {
    final dot = domain.lastIndexOf('.');
    if (dot < 0 || dot == domain.length - 1) return domain;
    return domain.substring(dot + 1);
  }

  String? _extractWhoisServerFromIana(String iana) {
    for (final line in iana.split('\n')) {
      final m = RegExp(
        r'^whois:\s*(\S+)',
        caseSensitive: false,
      ).firstMatch(line.trim());
      if (m != null) return m.group(1);
    }
    return null;
  }

  WhoisResponse _parse({
    required String domain,
    required String authoritativeServer,
    required String raw,
    required Duration latency,
  }) {
    String? registrar;
    DateTime? createdAt;
    DateTime? expiresAt;
    DateTime? updatedAt;
    final statuses = <String>[];
    final nameServers = <String>[];

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('%') || line.startsWith('#')) {
        continue;
      }
      final m = RegExp(r'^([^:]+):\s*(.+)$').firstMatch(line);
      if (m == null) continue;
      final key = m.group(1)!.trim().toLowerCase();
      final value = m.group(2)!.trim();
      if (value.isEmpty) continue;

      if (registrar == null &&
          (key == 'registrar' || key == 'sponsoring registrar')) {
        registrar = value;
      }

      createdAt ??= _matchDate(key, value, const {
        'creation date', 'created', 'created on', 'registered',
        'registered on', 'registration time', 'domain registration date',
      });
      expiresAt ??= _matchDate(key, value, const {
        'registry expiry date', 'registrar registration expiration date',
        'expiry date', 'expiration date', 'expires', 'expire',
        'paid-till', 'expiration time',
      });
      updatedAt ??= _matchDate(key, value, const {
        'updated date', 'last updated', 'last modified',
        'last update of whois database',
      });

      if (key == 'domain status' || key == 'status') {
        final cleaned = value
            .replaceAll(RegExp(r'\s*\(?https?://\S+\)?'), '')
            .trim();
        if (cleaned.isNotEmpty && !statuses.contains(cleaned)) {
          statuses.add(cleaned);
        }
      }

      if (key == 'name server' || key == 'nserver' || key == 'nameserver') {
        final ns = value.split(RegExp(r'\s+')).first.toLowerCase();
        if (ns.isNotEmpty && !nameServers.contains(ns)) {
          nameServers.add(ns);
        }
      }
    }

    return WhoisResponse(
      domain: domain,
      authoritativeServer: authoritativeServer,
      registrar: registrar,
      createdAt: createdAt,
      expiresAt: expiresAt,
      updatedAt: updatedAt,
      statuses: statuses,
      nameServers: nameServers,
      rawText: raw,
      latency: latency,
    );
  }

  DateTime? _matchDate(String key, String value, Set<String> aliases) {
    if (!aliases.contains(key)) return null;
    return _parseDate(value);
  }

  DateTime? _parseDate(String s) {
    s = s.trim();
    try {
      return DateTime.parse(s);
    } catch (_) {/* fall through */}

    final m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(s);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      const monNames = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final mon = monNames[m.group(2)!.toLowerCase()];
      final year = int.tryParse(m.group(3)!);
      if (day != null && mon != null && year != null) {
        return DateTime.utc(year, mon, day);
      }
    }
    return null;
  }
}
