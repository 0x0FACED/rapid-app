import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../features/lan/domain/entities/chat_message.dart';
import '../storage/shared_prefs_service.dart';

@lazySingleton
class ChatService {
  final SharedPrefsService _prefs;

  // История чатов: deviceId -> List<ChatMessage>
  final Map<String, List<ChatMessage>> _chats = {};

  final _messagesController =
      StreamController<Map<String, List<ChatMessage>>>.broadcast();
  Stream<Map<String, List<ChatMessage>>> get messagesStream =>
      _messagesController.stream;

  ChatService(this._prefs);

  List<ChatMessage> getMessages(String deviceId) {
    return _chats[deviceId] ?? [];
  }

  void addMessage({
    required String deviceId,
    required String text,
    required String fromDeviceId,
    required String fromDeviceName,
    required bool isSentByMe,
  }) {
    final message = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      fromDeviceId: fromDeviceId,
      fromDeviceName: fromDeviceName,
      timestamp: DateTime.now(),
      isSentByMe: isSentByMe,
    );

    if (!_chats.containsKey(deviceId)) {
      _chats[deviceId] = [];
    }

    _chats[deviceId]!.add(message);
    _messagesController.add(_chats);

    print('[Chat] Message added: ${message.text}');
  }

  void clearChat(String deviceId) {
    _chats.remove(deviceId);
    _messagesController.add(_chats);
  }

  void dispose() {
    _messagesController.close();
  }
}
