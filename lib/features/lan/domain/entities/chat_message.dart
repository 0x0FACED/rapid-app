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
