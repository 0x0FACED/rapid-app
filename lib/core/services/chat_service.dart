import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../../features/lan/domain/entities/chat_message.dart';
import '../storage/shared_prefs_service.dart';

@lazySingleton
class ChatService {
  final SharedPrefsService _prefs;

  static const _chatHistoryKey = 'chat_history';

  // История чатов: deviceId -> List<ChatMessage>
  final Map<String, List<ChatMessage>> _chats = {};

  final _messagesController =
      StreamController<Map<String, List<ChatMessage>>>.broadcast();
  Stream<Map<String, List<ChatMessage>>> get messagesStream =>
      _messagesController.stream;

  ChatService(this._prefs) {
    _loadHistory();
  }

  // НОВОЕ: Загрузка истории из SharedPrefs
  void _loadHistory() {
    try {
      final json = _prefs.getString(_chatHistoryKey);
      if (json == null || json.isEmpty) {
        print('[ChatService] No saved history');
        _messagesController.add(Map.from(_chats));

        return;
      }

      final Map<String, dynamic> decoded = jsonDecode(json);

      decoded.forEach((deviceId, messagesList) {
        final messages = (messagesList as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();

        _chats[deviceId] = messages;
      });

      _messagesController.add(Map.from(_chats));

      print('[ChatService] Loaded history for ${_chats.length} devices');
    } catch (e) {
      print('[ChatService] Failed to load history: $e');
    }
  }

  // НОВОЕ: Сохранение истории в SharedPrefs
  void _saveHistory() {
    try {
      final Map<String, dynamic> toSave = {};

      _chats.forEach((deviceId, messages) {
        toSave[deviceId] = messages.map((m) => m.toJson()).toList();
      });

      final json = jsonEncode(toSave);
      _prefs.setString(_chatHistoryKey, json);

      print('[ChatService] History saved');
    } catch (e) {
      print('[ChatService] Failed to save history: $e');
    }
  }

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
    final now = DateTime.now();

    final message = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      fromDeviceId: fromDeviceId,
      fromDeviceName: fromDeviceName,
      timestamp: now,
      isSentByMe: isSentByMe,
      formattedTime: timeago.format(now),
    );

    if (!_chats.containsKey(deviceId)) {
      _chats[deviceId] = [];
    }

    _chats[deviceId]!.add(message);
    _messagesController.add(_chats);

    // НОВОЕ: Сохраняем после каждого сообщения
    _saveHistory();

    print('[ChatService] Message added and saved: ${message.text}');
  }

  void clearChat(String deviceId) {
    _chats.remove(deviceId);
    _messagesController.add(_chats);

    // НОВОЕ: Сохраняем после очистки
    _saveHistory();
  }

  void dispose() {
    _messagesController.close();
  }
}
