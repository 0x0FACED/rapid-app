import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final String fromDeviceId;
  final String fromDeviceName;
  final DateTime timestamp;
  final bool isSentByMe;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromDeviceId,
    required this.fromDeviceName,
    required this.timestamp,
    required this.isSentByMe,
  });

  // НОВОЕ: JSON сериализация
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'fromDeviceId': fromDeviceId,
      'fromDeviceName': fromDeviceName,
      'timestamp': timestamp.toIso8601String(),
      'isSentByMe': isSentByMe,
    };
  }

  // НОВОЕ: JSON десериализация
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      fromDeviceId: json['fromDeviceId'] as String,
      fromDeviceName: json['fromDeviceName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSentByMe: json['isSentByMe'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    id,
    text,
    fromDeviceId,
    fromDeviceName,
    timestamp,
    isSentByMe,
  ];
}
