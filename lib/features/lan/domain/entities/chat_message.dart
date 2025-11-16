import 'package:equatable/equatable.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final String fromDeviceId;
  final String fromDeviceName;
  final DateTime timestamp;
  final bool isSentByMe;
  final String formattedTime;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromDeviceId,
    required this.fromDeviceName,
    required this.timestamp,
    required this.isSentByMe,
    required this.formattedTime,
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
      'formattedTime': formattedTime,
    };
  }

  // НОВОЕ: JSON десериализация
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final ts = DateTime.parse(json['timestamp'] as String);

    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      fromDeviceId: json['fromDeviceId'] as String,
      fromDeviceName: json['fromDeviceName'] as String,
      timestamp: ts,
      isSentByMe: json['isSentByMe'] as bool,
      formattedTime: json['formattedTime'] as String? ?? timeago.format(ts),
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
    formattedTime,
  ];
}
