import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:network_info_plus/network_info_plus.dart';

class IPWatcher extends ChangeNotifier {
  String? _currentIp;
  StreamSubscription? _connectivitySub;

  String? get currentIp => _currentIp;

  IPWatcher() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _updateIp();
    });
    _updateIp();
  }

  Future<void> _updateIp() async {
    String? newIp;
    final info = NetworkInfo();
    newIp = await info.getWifiIP();

    // Если не нашли — ищем среди интерфейсов (поддержка VPN, eth, etc)
    if (!_isValidIp(newIp)) {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isValidIp(addr.address)) {
            newIp = addr.address;
            break;
          }
        }
        if (_isValidIp(newIp)) break;
      }
    }

    if (_currentIp != newIp) {
      _currentIp = newIp;
      notifyListeners();
    }
  }

  bool _isValidIp(String? ip) {
    if (ip == null) return false;
    return !ip.startsWith('127.') && !ip.startsWith('169.254.');
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
