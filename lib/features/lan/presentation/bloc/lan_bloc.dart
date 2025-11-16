import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:rapid/core/services/chat_service.dart';
import 'package:rapid/core/services/notification_service.dart';
import 'package:rapid/core/storage/shared_prefs_service.dart';
import 'package:rapid/features/lan/domain/entities/device.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../../../../core/mdns/device_discovery.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/shared_file.dart';
import '../../../../core/network/transfer_manager.dart';
import '../../../../core/network/http_server.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/usecases/send_files.dart';
import '../../domain/usecases/receive_files.dart';
import 'lan_event.dart';
import 'lan_state.dart';

final _log = Logger('LAN Bloc');

@injectable
class LanBloc extends Bloc<LanEvent, LanState> {
  final SettingsRepository _settingsRepository;
  final DeviceDiscovery _deviceDiscovery;
  final TransferManager _transferManager; // НОВОЕ
  final SendFilesUseCase _sendFilesUseCase; // НОВОЕ
  final ReceiveFilesUseCase _receiveFilesUseCase; // НОВОЕ
  final HttpServerService _httpServer;
  final ApiClient _apiClient;
  final NotificationService _notificationService;
  final ChatService _chatService;
  final SharedPrefsService _prefs;

  final Map<String, Device> _favoriteDevices = {};
  static const _favoritesKey = 'favorite_devices';

  StreamSubscription? _devicesSubscription;
  StreamSubscription? _incomingTextsSubscription;
  Timer? _fileRefreshTimer;
  StreamSubscription? _outgoingDownloadsSubscription;

  LanBloc(
    this._settingsRepository,
    this._deviceDiscovery,
    this._transferManager, // НОВОЕ
    this._sendFilesUseCase, // НОВОЕ
    this._receiveFilesUseCase, // НОВОЕ
    this._httpServer,
    this._apiClient,
    this._notificationService,
    this._chatService,
    this._prefs,
  ) : super(LanInitial()) {
    on<LanInitialize>(_onInitialize);
    on<LanToggleMode>(_onToggleMode);
    on<LanPickFiles>(_onPickFiles);
    on<LanRemoveSharedFile>(_onRemoveSharedFile);
    on<LanDevicesUpdated>(_onDevicesUpdated);
    on<LanSelectDevice>(_onSelectDevice);
    on<LanSendText>(_onSendText);
    on<LanSendFiles>(_onSendFiles); // НОВОЕ
    on<LanReceiveFiles>(_onReceiveFiles); // НОВОЕ
    on<LanCancelTransfer>(_onCancelTransfer); // НОВОЕ
    on<LanRefreshSettings>(_onRefreshSettings);
    on<LanRefreshDeviceFiles>(_onRefreshDeviceFiles);
    on<LanToggleFavorite>(_onToggleFavorite);
  }

  Future<void> _onInitialize(
    LanInitialize event,
    Emitter<LanState> emit,
  ) async {
    emit(LanLoading());

    try {
      // Загружаем настройки пользователя
      final settings = await _settingsRepository.getSettings();

      // Подписываемся на обновления устройств
      _devicesSubscription = _deviceDiscovery.devicesStream.listen((devices) {
        add(LanDevicesUpdated(devices));
      });

      _incomingTextsSubscription = _httpServer.incomingTexts.listen((
        textMessage,
      ) {
        _log.fine(
          '[LanBloc] Received text from ${textMessage.fromDeviceName}: ${textMessage.text}',
        );

        _notificationService.addTextNotification(
          deviceName: textMessage.fromDeviceName,
          deviceId: textMessage.fromDevice,
          text: textMessage.text,
        );

        _chatService.addMessage(
          deviceId: textMessage.fromDevice,
          text: textMessage.text,
          fromDeviceId: textMessage.fromDevice,
          fromDeviceName: textMessage.fromDeviceName,
          isSentByMe: false,
        );
      });

      _outgoingDownloadsSubscription = _httpServer.outgoingDownloads.listen((
        download,
      ) {
        _log.fine(
          'Outgoing download: ${download.fileName} (${download.fileSize} bytes) to ${download.remoteAddress}',
        );

        _notificationService.addFileSharedNotification(
          fileName: download.fileName,
          remoteAddress: download.remoteAddress,
        );
      });

      await _loadFavorites();

      emit(
        LanLoaded(
          userSettings: settings,
          isShareMode: true,
          sharedFiles: [],
          availableDevices: _deviceDiscovery.devices,
          activeTransfers: _transferManager.activeTransfers.toList(),
          favoriteDevices: _favoriteDevices.values.toList(),
        ),
      );
    } catch (e) {
      emit(LanError('Failed to initialize: $e'));
    }
  }

  void _onToggleMode(LanToggleMode event, Emitter<LanState> emit) {
    if (state is LanLoaded) {
      final currentState = state as LanLoaded;
      emit(
        currentState.copyWith(
          isShareMode: event.isShareMode,
          selectedDevice: null,
          receivedFiles: null,
        ),
      );
    }
  }

  Future<void> _onPickFiles(LanPickFiles event, Emitter<LanState> emit) async {
    if (state is! LanLoaded) return;

    try {
      // Открываем file picker
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null) return; // Пользователь отменил выбор

      final currentState = state as LanLoaded;
      final newFiles = <SharedFile>[];

      // Конвертируем выбранные файлы в SharedFile
      for (final platformFile in result.files) {
        if (platformFile.path == null) continue;

        final file = File(platformFile.path!);
        final mimeType =
            lookupMimeType(platformFile.path!) ?? 'application/octet-stream';

        final sharedFile = SharedFile(
          id: const Uuid().v4(),
          name: platformFile.name,
          path: platformFile.path!,
          size: platformFile.size,
          mimeType: mimeType,
          addedAt: DateTime.now(),
        );

        newFiles.add(sharedFile);
        _httpServer.registerFile(sharedFile.id, sharedFile.path);
        _log.fine(
          '[LanBloc] Registered file ${sharedFile.id} -> ${sharedFile.path}',
        );
      }

      emit(
        currentState.copyWith(
          sharedFiles: [...currentState.sharedFiles, ...newFiles],
        ),
      );

      _log.fine('[LanBloc] Added ${newFiles.length} files to share');
    } catch (e) {
      _log.warning('[LanBloc] Pick files error: $e');
    }
  }

  void _onRemoveSharedFile(LanRemoveSharedFile event, Emitter<LanState> emit) {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;
    final updatedFiles = currentState.sharedFiles
        .where((file) => file.id != event.fileId)
        .toList();

    _httpServer.unregisterFile(event.fileId);

    emit(currentState.copyWith(sharedFiles: updatedFiles));
  }

  void _onDevicesUpdated(LanDevicesUpdated event, Emitter<LanState> emit) {
    if (state is! LanLoaded) {
      _log.warning('[LanBloc] ⚠️ State is ${state.runtimeType}, not LanLoaded');
      return;
    }

    final currentState = state as LanLoaded;
    final oldDevices = currentState.availableDevices;
    final devices = event.devices;

    // Fast-path: если размеры списков разные
    bool hasChanges = false;
    if (oldDevices.length != devices.length) {
      hasChanges = true;
    }

    // Детальное сравнение
    for (final newDevice in devices) {
      final oldDevice = currentState.availableDevices
          .cast<Device?>()
          .firstWhere((d) => d?.id == newDevice.id, orElse: () => null);

      if (oldDevice == null) {
        _log.fine('[LanBloc]   + NEW: ${newDevice.name}');
        hasChanges = true;
        break;
      } else if (oldDevice.name != newDevice.name) {
        _log.fine('[LanBloc]   ~ NAME: ${oldDevice.name} → ${newDevice.name}');
        hasChanges = true;
        break;
      } else if (oldDevice.avatar != newDevice.avatar) {
        _log.fine('[LanBloc]   ~ AVATAR: ${newDevice.name}');
        hasChanges = true;
        break;
      }
    }

    // Если нет вообще устройств -- это тоже изменение
    if (devices.isEmpty) {
      hasChanges = true;
    }

    if (hasChanges == true) {
      _syncFavoritesWithDevices(devices);

      final newState = currentState.copyWith(
        availableDevices: List.from(event.devices), // Создаём НОВЫЙ список
        favoriteDevices: _favoriteDevices.values.toList(),
      );

      _log.fine('[LanBloc] Emitting new state...');
      emit(newState);
    }
  }

  Future<void> _onSelectDevice(
    LanSelectDevice event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    if (event.deviceId == null) {
      _stopFileRefresh();
      _log.fine('[LanBloc] Deselecting device');
      emit(
        currentState.copyWith(
          clearSelectedDevice: true,
          clearReceivedFiles: true,
        ),
      );
      _log.fine(
        '[LanBloc] Device deselected, selectedDevice=${(state as LanLoaded).selectedDevice}',
      );
      return;
    }

    // 1) СНАЧАЛА выбираем устройство, чтобы UI сразу переключился с анимацией
    final device = currentState.availableDevices.firstWhere(
      (d) => d.id == event.deviceId,
    );

    emit(
      currentState.copyWith(
        selectedDevice: device,
        receivedFiles: [], // пока файлов нет, просто пустой список
      ),
    );

    // 2) Потом уже асинхронно грузим файлы
    try {
      _log.fine('[LanBloc] Selecting device: ${device.name}');
      _log.fine('[LanBloc] Requesting files from ${device.name}...');

      final filesData = await _apiClient.getAvailableFiles(device.baseUrl);

      final receivedFiles = filesData.map((fileData) {
        return SharedFile(
          id: fileData['id'] as String,
          name: fileData['fileName'] as String,
          path: '',
          size: fileData['size'] as int,
          mimeType: fileData['fileType'] as String,
          addedAt: DateTime.now(),
        );
      }).toList();

      // Важно: берём актуальное состояние, чтобы не перезатереть изменения
      final latestState = state;
      if (latestState is! LanLoaded) return;

      // Убедимся, что всё ещё выбрано именно это устройство
      if (latestState.selectedDevice?.id != device.id) {
        _log.warning(
          '[LanBloc] Device changed while loading, skipping files update',
        );
        return;
      }

      emit(latestState.copyWith(receivedFiles: receivedFiles));

      _startFileRefresh(device.id);

      _log.fine(
        '[LanBloc] Device selected: ${device.name}, files: ${receivedFiles.length}',
      );
    } catch (e) {
      _log.severe('[LanBloc] Failed to load files: $e');

      final latestState = state;
      if (latestState is! LanLoaded) return;

      // Если устройство всё ещё выбрано — оставим его, но с пустым списком файлов
      if (latestState.selectedDevice?.id == device.id) {
        emit(latestState.copyWith(receivedFiles: []));
      }
    }
  }

  void _syncFavoritesWithDevices(List<Device> devices) {
    // если устройство в избранных и есть в availableDevices — обновляем его snapshot
    final byId = {for (final d in devices) d.id: d};

    for (final id in _favoriteDevices.keys.toList()) {
      final online = byId[id];
      if (online != null) {
        // обновляем name/host/port/protocol/isOnline/avatar
        _favoriteDevices[id] = _favoriteDevices[id]!.copyWith(
          name: online.name,
          host: online.host,
          port: online.port,
          protocol: online.protocol,
          isOnline: online.isOnline,
          avatar: online.avatar,
          lastSeen: online.lastSeen,
        );
      } else {
        // устройства сейчас нет в availableDevices -> помечаем offline,
        // но сохраняем последний host/port
        final current = _favoriteDevices[id]!;
        _favoriteDevices[id] = current.copyWith(isOnline: false);
      }
    }
  }

  void _startFileRefresh(String deviceId) {
    _stopFileRefresh(); // Останавливаем предыдущий таймер

    _fileRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _log.fine('[LanBloc] Auto-refreshing files for device $deviceId');
      add(LanRefreshDeviceFiles(deviceId));
    });
  }

  // НОВОЕ: Остановка auto-refresh
  void _stopFileRefresh() {
    _fileRefreshTimer?.cancel();
    _fileRefreshTimer = null;
  }

  // НОВОЕ: Обработка refresh файлов
  Future<void> _onRefreshDeviceFiles(
    LanRefreshDeviceFiles event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    // Проверяем что устройство всё ещё выбрано
    if (currentState.selectedDevice?.id != event.deviceId) {
      _log.warning('[LanBloc] Device not selected anymore, skipping refresh');
      return;
    }

    final device = currentState.selectedDevice!;

    try {
      final filesData = await _apiClient.getAvailableFiles(device.baseUrl);

      final receivedFiles = filesData.map((fileData) {
        return SharedFile(
          id: fileData['id'] as String,
          name: fileData['fileName'] as String,
          path: '',
          size: fileData['size'] as int,
          mimeType: fileData['fileType'] as String,
          addedAt: DateTime.now(),
        );
      }).toList();

      // ИСПРАВЛЕНО: Проверяем не только количество, но и ID файлов
      final oldFiles = currentState.receivedFiles ?? [];
      final oldCount = oldFiles.length;
      final newCount = receivedFiles.length;

      // Сравниваем ID файлов
      final oldIds = oldFiles.map((f) => f.id).toSet();
      final newIds = receivedFiles.map((f) => f.id).toSet();

      // Проверяем что списки различаются
      final hasChanges =
          oldCount != newCount ||
          !oldIds.containsAll(newIds) ||
          !newIds.containsAll(oldIds);

      if (hasChanges) {
        // Детальное логирование изменений
        final added = newIds.difference(oldIds);
        final removed = oldIds.difference(newIds);

        if (added.isNotEmpty) {
          _log.fine('[LanBloc] Files added: ${added.length}');
          for (final id in added) {
            final file = receivedFiles.firstWhere((f) => f.id == id);
            _log.fine('[LanBloc]   + ${file.name}');
          }
        }

        if (removed.isNotEmpty) {
          _log.fine('[LanBloc] Files removed: ${removed.length}');
          for (final id in removed) {
            final file = oldFiles.firstWhere((f) => f.id == id);
            _log.fine('[LanBloc]   - ${file.name}');
          }
        }

        if (added.isEmpty && removed.isEmpty && oldCount != newCount) {
          _log.fine('[LanBloc] Files updated: $oldCount → $newCount');
        }

        emit(currentState.copyWith(receivedFiles: receivedFiles));
      } else {
        // Без изменений - не логируем каждый раз
        // print('[LanBloc] Files unchanged: $oldCount files');
      }
    } catch (e) {
      _log.severe('[LanBloc] ✗ Failed to refresh files: $e');
      // Не показываем ошибку пользователю при auto-refresh
    }
  }

  Future<void> _onSendText(LanSendText event, Emitter<LanState> emit) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    try {
      // ИСПРАВЛЕНО: Используем firstWhereOrNull вместо firstWhere
      final device = currentState.availableDevices.cast<Device?>().firstWhere(
        (d) => d?.id == event.targetDeviceId,
        orElse: () => null,
      );

      if (device == null) {
        _log.warning('[LanBloc] ⚠️ Device not found: ${event.targetDeviceId}');
        // Устройство недоступно - не выполняем отправку
        return;
      }

      // Получаем наши данные
      final ourDeviceName = currentState.userSettings.deviceName;
      final ourDeviceId = currentState.userSettings.deviceId;

      // Отправляем текст
      await _apiClient.sendText(
        baseUrl: device.baseUrl,
        text: event.text,
        fromDevice: ourDeviceId,
        fromDeviceName: ourDeviceName,
      );

      _chatService.addMessage(
        deviceId: event.targetDeviceId, // id собеседника
        text: event.text,
        fromDeviceId: ourDeviceId, // наш реальный ID
        fromDeviceName: ourDeviceName, // наше реальное имя
        isSentByMe: true,
      );

      _log.fine('[LanBloc] ✓ Text sent to ${device.name}: ${event.text}');
    } catch (e) {
      _log.fine('[LanBloc] Failed to send text: $e');
      // Не пробрасываем исключение дальше
    }
  }

  Future<void> _onSendFiles(LanSendFiles event, Emitter<LanState> emit) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    // Находим устройство
    final device = currentState.availableDevices.firstWhere(
      (d) => d.id == event.targetDeviceId,
    );

    // Находим файлы
    final filesToSend = currentState.sharedFiles
        .where((f) => event.fileIds.contains(f.id))
        .toList();

    if (filesToSend.isEmpty) {
      _log.warning('[LanBloc] No files to send');
      return;
    }

    try {
      // Запускаем отправку асинхронно
      _sendFilesUseCase
          .execute(targetDevice: device, files: filesToSend)
          .catchError((e) {
            _log.severe('[LanBloc] Send files error: $e');
          });

      _log.fine(
        '[LanBloc] Started sending ${filesToSend.length} files to ${device.name}',
      );
    } catch (e) {
      _log.severe('[LanBloc] Error starting file send: $e');
    }
  }

  Future<void> _onReceiveFiles(
    LanReceiveFiles event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    final device = currentState.availableDevices.cast<Device?>().firstWhere(
      (d) => d?.id == event.sourceDeviceId,
      orElse: () => null,
    );

    if (device == null) {
      _log.warning('[LanBloc] Device not found: ${event.sourceDeviceId}');
      return;
    }

    try {
      // Проверяем доступность файлов
      _log.fine('[LanBloc] Checking if files still available...');
      final filesData = await _apiClient.getAvailableFiles(device.baseUrl);

      final availableFileIds = filesData.map((f) => f['id'] as String).toSet();

      // Проверяем что все запрошенные файлы ещё доступны
      final unavailableFiles = event.fileIds
          .where((id) => !availableFileIds.contains(id))
          .toList();

      if (unavailableFiles.isNotEmpty) {
        _log.warning(
          '[LanBloc] ⚠️ Some files are no longer available: $unavailableFiles',
        );

        _notificationService.addFileDownloadFailedNotification(
          deviceName: device.name,
          fileName: '${unavailableFiles.length} file(s)',
          error: 'File(s) no longer shared',
        );

        // Обновляем список файлов
        final receivedFiles = filesData.map((fileData) {
          return SharedFile(
            id: fileData['id'] as String,
            name: fileData['fileName'] as String,
            path: '',
            size: fileData['size'] as int,
            mimeType: fileData['fileType'] as String,
            addedAt: DateTime.now(),
          );
        }).toList();

        emit(currentState.copyWith(receivedFiles: receivedFiles));
        return;
      }

      // Все файлы доступны - скачиваем
      final filesToReceive =
          currentState.receivedFiles
              ?.where((f) => event.fileIds.contains(f.id))
              .toList() ??
          [];

      if (filesToReceive.isEmpty) {
        _log.warning('[LanBloc] No files to receive');
        return;
      }

      // ИСПРАВЛЕНО: Получаем реальные пути
      _receiveFilesUseCase
          .execute(sourceDevice: device, files: filesToReceive)
          .then((downloadedPaths) {
            // Успешно скачано
            for (int i = 0; i < filesToReceive.length; i++) {
              final file = filesToReceive[i];
              final path = i < downloadedPaths.length
                  ? downloadedPaths[i]
                  : 'unknown';

              _notificationService.addFileDownloadedNotification(
                deviceName: device.name,
                fileName: file.name,
                filePath: path, // ИСПРАВЛЕНО: Реальный путь
              );

              _log.fine('[LanBloc] ✓ Downloaded: $path');
            }
          })
          .catchError((e) {
            _log.severe('[LanBloc] Receive files error: $e');

            _notificationService.addFileDownloadFailedNotification(
              deviceName: device.name,
              fileName: filesToReceive.first.name,
              error: e.toString(),
            );
          });

      _log.fine('[LanBloc] Started receiving ${filesToReceive.length} files');
    } catch (e) {
      _log.severe('[LanBloc] Error checking files: $e');

      _notificationService.addFileDownloadFailedNotification(
        deviceName: device.name,
        fileName: 'files',
        error: 'Cannot connect to device',
      );
    }
  }

  Future<void> _onRefreshSettings(
    LanRefreshSettings event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    try {
      _log.fine('[LanBloc] Refreshing settings...');

      // Загружаем новые настройки
      final newSettings = await _settingsRepository.getSettings();

      _log.fine(
        '[LanBloc] New settings: ${newSettings.deviceName}, avatar: ${newSettings.avatar}',
      );

      // ВАЖНО: Сначала эмитим новое состояние
      emit(currentState.copyWith(userSettings: newSettings));

      _log.fine('[LanBloc] State emitted with new settings');

      // Потом перезапускаем сервисы
      await _httpServer.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      await _httpServer.start(
        deviceId: newSettings.deviceId,
        deviceName: newSettings.deviceName,
        port: newSettings.serverPort,
        useHttps: newSettings.useHttps,
        avatar: newSettings.avatar, // НОВОЕ
      );

      // Перезапускаем discovery
      await _deviceDiscovery.stop();
      await _deviceDiscovery.start();

      _log.fine('[LanBloc] ✓ Services restarted with new settings');
    } catch (e) {
      _log.severe('[LanBloc] ✗ Failed to refresh settings: $e');
    }
  }

  Future<void> _onToggleFavorite(
    LanToggleFavorite event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;
    final currentState = state as LanLoaded;

    final id = event.device.id;
    if (_favoriteDevices.containsKey(id)) {
      _favoriteDevices.remove(id); // <- unfavorite
    } else {
      _favoriteDevices[id] = event.device; // <- add favorite
    }

    await _saveFavorites();

    emit(
      currentState.copyWith(favoriteDevices: _favoriteDevices.values.toList()),
    );
  }

  Future<void> _loadFavorites() async {
    final json = _prefs.getString(_favoritesKey);
    if (json == null || json.isEmpty) {
      _favoriteDevices.clear();
      return;
    }

    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _favoriteDevices
        ..clear()
        ..addAll(
          decoded.map((id, value) {
            return MapEntry(id, Device.fromJson(value as Map<String, dynamic>));
          }),
        );
    } catch (e) {
      _log.severe('[LanBloc] Failed to parse favorites: $e');
      _favoriteDevices.clear();
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final map = _favoriteDevices.map(
        (id, device) => MapEntry(id, device.toJson()),
      );
      await _prefs.setString(_favoritesKey, jsonEncode(map));
    } catch (e) {
      _log.severe('[LanBloc] Failed to save favorites: $e');
    }
  }

  void _onCancelTransfer(LanCancelTransfer event, Emitter<LanState> emit) {
    _transferManager.cancelTransfer(event.transferId);
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _incomingTextsSubscription?.cancel();
    _stopFileRefresh();
    _outgoingDownloadsSubscription?.cancel();
    return super.close();
  }
}
