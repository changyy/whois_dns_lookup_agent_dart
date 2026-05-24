import 'dns_server.dart';

/// Curated list of public recursive DNS servers we query in parallel.
///
/// Ordering = display order. Local goes first so callers can spot when their
/// network's resolver diverges from public DNS.
class DnsServers {
  static const List<DnsServer> defaults = [
    DnsServer(
      name: 'Local',
      ip: 'system',
      operator: 'this device',
      note: 'OS resolver',
      isLocal: true,
    ),

    DnsServer(name: 'Google', ip: '8.8.8.8', operator: 'Google'),
    DnsServer(name: 'Google (2)', ip: '8.8.4.4', operator: 'Google'),

    DnsServer(name: 'Cloudflare', ip: '1.1.1.1', operator: 'Cloudflare'),
    DnsServer(name: 'Cloudflare (2)', ip: '1.0.0.1', operator: 'Cloudflare'),
    DnsServer(
      name: 'Cloudflare Malware',
      ip: '1.1.1.2',
      operator: 'Cloudflare',
      note: 'blocks malware',
    ),
    DnsServer(
      name: 'Cloudflare Malware (2)',
      ip: '1.0.0.2',
      operator: 'Cloudflare',
      note: 'blocks malware',
    ),
    DnsServer(
      name: 'Cloudflare Family',
      ip: '1.1.1.3',
      operator: 'Cloudflare',
      note: 'blocks malware + adult',
    ),
    DnsServer(
      name: 'Cloudflare Family (2)',
      ip: '1.0.0.3',
      operator: 'Cloudflare',
      note: 'blocks malware + adult',
    ),

    DnsServer(name: 'Quad9', ip: '9.9.9.9', operator: 'Quad9'),
    DnsServer(name: 'OpenDNS', ip: '208.67.222.222', operator: 'Cisco OpenDNS'),
    DnsServer(name: 'AdGuard', ip: '94.140.14.14', operator: 'AdGuard'),

    DnsServer(
      name: 'Alibaba',
      ip: '223.5.5.5',
      operator: 'Alibaba',
      note: 'CN region',
    ),
    DnsServer(
      name: 'Alibaba (2)',
      ip: '223.6.6.6',
      operator: 'Alibaba',
      note: 'CN region',
    ),

    DnsServer(
      name: 'CleanBrowsing',
      ip: '185.228.168.9',
      operator: 'CleanBrowsing',
    ),
    DnsServer(name: 'DNS.SB', ip: '185.222.222.222', operator: 'DNS.SB'),
  ];
}
