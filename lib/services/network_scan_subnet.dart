import 'dart:io';

class Ipv4Subnet {
  final int network;
  final int prefix;

  const Ipv4Subnet({required this.network, required this.prefix});

  factory Ipv4Subnet.fromAddress(String address, int prefix) {
    final ip = _parseIpv4(address);
    final normalizedPrefix = prefix.clamp(16, 30).toInt();
    final mask = _maskForPrefix(normalizedPrefix);
    return Ipv4Subnet(network: ip & mask, prefix: normalizedPrefix);
  }

  static Ipv4Subnet? tryParse(String cidr) {
    final parts = cidr.trim().split('/');
    if (parts.length != 2) return null;
    final prefix = int.tryParse(parts[1]);
    if (prefix == null) return null;
    try {
      return Ipv4Subnet.fromAddress(parts[0], prefix);
    } catch (_) {
      return null;
    }
  }

  List<String> hosts() {
    final hostBits = 32 - prefix;
    final count = 1 << hostBits;
    if (count <= 2) return const [];
    return [
      for (var offset = 1; offset < count - 1; offset++)
        _formatIpv4(network + offset),
    ];
  }

  String get cidr => '${_formatIpv4(network)}/$prefix';
}

bool isPrivateIpv4(String address) {
  final ip = _parseIpv4(address);
  final a = (ip >> 24) & 0xff;
  final b = (ip >> 16) & 0xff;
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

bool isUsableIpv4(InternetAddress address) =>
    address.type == InternetAddressType.IPv4 && !address.isLoopback;

int _parseIpv4(String address) {
  final parsed = InternetAddress.tryParse(address);
  if (parsed == null || parsed.type != InternetAddressType.IPv4) {
    throw FormatException('Invalid IPv4 address', address);
  }
  return parsed.rawAddress.fold<int>(0, (value, byte) => (value << 8) | byte);
}

String _formatIpv4(int value) {
  return [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ].join('.');
}

int _maskForPrefix(int prefix) => (0xffffffff << (32 - prefix)) & 0xffffffff;
