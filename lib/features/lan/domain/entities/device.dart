import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String id;              // Уникальный идентификатор (UUID)
  final String name;            // Псевдоним устройства
  final String host;            // IP адрес или hostname
  final int port;               // Порт HTTP/HTTPS сервера
  final String? avatar;         // URL или base64 аватарки
  final DateTime lastSeen;      // Последний раз когда видели устройство
  final bool isOnline;          // Онлайн ли устройство
  final String protocol;        // 'http' или 'https'
  
  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.avatar,
    required this.lastSeen,
    this.isOnline = true,
    this.protocol = 'https',
  });
  
  String get baseUrl => '$protocol://$host:$port';
  
  Device copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? avatar,
    DateTime? lastSeen,
    bool? isOnline,
    String? protocol,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      avatar: avatar ?? this.avatar,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      protocol: protocol ?? this.protocol,
    );
  }
  
  @override
  List<Object?> get props => [id, name, host, port, avatar, lastSeen, isOnline, protocol];
}
