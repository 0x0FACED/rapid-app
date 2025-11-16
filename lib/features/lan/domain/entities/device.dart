import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final bool isOnline;
  final DateTime lastSeen;
  final String? avatar;

  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.isOnline,
    required this.lastSeen,
    this.avatar,
  });

  String get baseUrl => '$protocol://$host:$port';

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      protocol: json['protocol'] as String,
      isOnline: json['isOnline'] as bool,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'protocol': protocol,
    'isOnline': isOnline,
    'lastSeen': lastSeen.toIso8601String(),
    'avatar': avatar,
  };

  Device copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? protocol,
    bool? isOnline,
    DateTime? lastSeen,
    String? avatar,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      avatar: avatar ?? this.avatar,
    );
  }

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
