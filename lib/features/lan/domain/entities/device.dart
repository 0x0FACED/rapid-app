import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final bool isOnline;
  final DateTime lastSeen;
  final String? avatar; // НОВОЕ

  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.isOnline,
    required this.lastSeen,
    this.avatar, // НОВОЕ
  });

  String get baseUrl => '$protocol://$host:$port';

  @override
  List<Object?> get props => [
    id,
    name,
    host,
    port,
    protocol,
    isOnline,
    lastSeen,
    avatar,
  ];
}
