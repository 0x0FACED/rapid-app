import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:rapid/core/services/chat_service.dart';
import 'package:rapid/core/services/notification_service.dart';
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

  StreamSubscription? _devicesSubscription;
  StreamSubscription? _transfersSubscription; // НОВОЕ
  StreamSubscription? _incomingTextsSubscription;
  Timer? _fileRefreshTimer;

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
    on<LanTransfersUpdated>(_onTransfersUpdated); // НОВОЕ
    on<LanCancelTransfer>(_onCancelTransfer); // НОВОЕ
    on<LanRefreshSettings>(_onRefreshSettings);
    on<LanRefreshDeviceFiles>(_onRefreshDeviceFiles);
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

      // Подписываемся на обновления передач (НОВОЕ)
      _transfersSubscription = _transferManager.transfersStream.listen((
        transfers,
      ) {
        add(LanTransfersUpdated(transfers));
      });

      _incomingTextsSubscription = _httpServer.incomingTexts.listen((
        textMessage,
      ) {
        print(
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

      emit(
        LanLoaded(
          userSettings: settings,
          isShareMode: true,
          sharedFiles: [],
          availableDevices: _deviceDiscovery.devices,
          activeTransfers: _transferManager.activeTransfers.toList(),
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
        print(
          '[LanBloc] Registered file ${sharedFile.id} -> ${sharedFile.path}',
        );
      }

      emit(
        currentState.copyWith(
          sharedFiles: [...currentState.sharedFiles, ...newFiles],
        ),
      );

      print('[LanBloc] Added ${newFiles.length} files to share');
    } catch (e) {
      print('[LanBloc] Pick files error: $e');
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
      print('[LanBloc] ⚠️ State is ${state.runtimeType}, not LanLoaded');
      return;
    }

    final currentState = state as LanLoaded;

    // Детальное сравнение
    bool hasChanges = false;
    for (final newDevice in event.devices) {
      final oldDevice = currentState.availableDevices
          .cast<Device?>()
          .firstWhere((d) => d?.id == newDevice.id, orElse: () => null);

      if (oldDevice == null) {
        print('[LanBloc]   + NEW: ${newDevice.name}');
        hasChanges = true;
        break;
      } else if (oldDevice.name != newDevice.name) {
        print('[LanBloc]   ~ NAME: ${oldDevice.name} → ${newDevice.name}');
        hasChanges = true;
        break;
      } else if (oldDevice.avatar != newDevice.avatar) {
        print('[LanBloc]   ~ AVATAR: ${newDevice.name}');
        hasChanges = true;
        break;
      }
    }

    if (hasChanges == true) {
      final newState = currentState.copyWith(
        availableDevices: List.from(event.devices), // Создаём НОВЫЙ список
      );

      print('[LanBloc] Emitting new state...');
      emit(newState);
    }

    print('[LanBloc] ========================================');
  }

  Future<void> _onSelectDevice(
    LanSelectDevice event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    if (event.deviceId == null) {
      _stopFileRefresh();
      // ИСПРАВЛЕНО: Используем explicit flag
      print('[LanBloc] Deselecting device');
      emit(
        currentState.copyWith(
          clearSelectedDevice: true,
          clearReceivedFiles: true,
        ),
      );
      print(
        '[LanBloc] Device deselected, selectedDevice=${(state as LanLoaded).selectedDevice}',
      );
      return;
    }

    try {
      final device = currentState.availableDevices.firstWhere(
        (d) => d.id == event.deviceId,
      );

      print('[LanBloc] Selecting device: ${device.name}');
      print('[LanBloc] Requesting files from ${device.name}...');

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

      emit(
        currentState.copyWith(
          selectedDevice: device,
          receivedFiles: receivedFiles,
        ),
      );

      _startFileRefresh(device.id);

      print(
        '[LanBloc] Device selected: ${device.name}, files: ${receivedFiles.length}',
      );
    } catch (e) {
      print('[LanBloc] Failed to load files: $e');

      final device = currentState.availableDevices.firstWhere(
        (d) => d.id == event.deviceId,
      );

      emit(currentState.copyWith(selectedDevice: device, receivedFiles: []));
    }
  }

  void _startFileRefresh(String deviceId) {
    _stopFileRefresh(); // Останавливаем предыдущий таймер

    _fileRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      print('[LanBloc] Auto-refreshing files for device $deviceId');
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
      print('[LanBloc] Device not selected anymore, skipping refresh');
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
          print('[LanBloc] Files added: ${added.length}');
          for (final id in added) {
            final file = receivedFiles.firstWhere((f) => f.id == id);
            print('[LanBloc]   + ${file.name}');
          }
        }

        if (removed.isNotEmpty) {
          print('[LanBloc] Files removed: ${removed.length}');
          for (final id in removed) {
            final file = oldFiles.firstWhere((f) => f.id == id);
            print('[LanBloc]   - ${file.name}');
          }
        }

        if (added.isEmpty && removed.isEmpty && oldCount != newCount) {
          print('[LanBloc] Files updated: $oldCount → $newCount');
        }

        emit(currentState.copyWith(receivedFiles: receivedFiles));
      } else {
        // Без изменений - не логируем каждый раз
        // print('[LanBloc] Files unchanged: $oldCount files');
      }
    } catch (e) {
      print('[LanBloc] ✗ Failed to refresh files: $e');
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
        print('[LanBloc] ⚠️ Device not found: ${event.targetDeviceId}');
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

      print('[LanBloc] ✓ Text sent to ${device.name}: ${event.text}');
    } catch (e) {
      print('[LanBloc] Failed to send text: $e');
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
      print('[LanBloc] No files to send');
      return;
    }

    try {
      // Запускаем отправку асинхронно
      _sendFilesUseCase
          .execute(targetDevice: device, files: filesToSend)
          .catchError((e) {
            print('[LanBloc] Send files error: $e');
          });

      print(
        '[LanBloc] Started sending ${filesToSend.length} files to ${device.name}',
      );
    } catch (e) {
      print('[LanBloc] Error starting file send: $e');
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
      print('[LanBloc] Device not found: ${event.sourceDeviceId}');
      return;
    }

    try {
      // Проверяем доступность файлов
      print('[LanBloc] Checking if files still available...');
      final filesData = await _apiClient.getAvailableFiles(device.baseUrl);

      final availableFileIds = filesData.map((f) => f['id'] as String).toSet();

      // Проверяем что все запрошенные файлы ещё доступны
      final unavailableFiles = event.fileIds
          .where((id) => !availableFileIds.contains(id))
          .toList();

      if (unavailableFiles.isNotEmpty) {
        print(
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
        print('[LanBloc] No files to receive');
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

              print('[LanBloc] ✓ Downloaded: $path');
            }
          })
          .catchError((e) {
            print('[LanBloc] Receive files error: $e');

            _notificationService.addFileDownloadFailedNotification(
              deviceName: device.name,
              fileName: filesToReceive.first.name,
              error: e.toString(),
            );
          });

      print('[LanBloc] Started receiving ${filesToReceive.length} files');
    } catch (e) {
      print('[LanBloc] Error checking files: $e');

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
      print('[LanBloc] Refreshing settings...');

      // Загружаем новые настройки
      final newSettings = await _settingsRepository.getSettings();

      print(
        '[LanBloc] New settings: ${newSettings.deviceName}, avatar: ${newSettings.avatar}',
      );

      // ВАЖНО: Сначала эмитим новое состояние
      emit(currentState.copyWith(userSettings: newSettings));

      print('[LanBloc] State emitted with new settings');

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

      print('[LanBloc] ✓ Services restarted with new settings');
    } catch (e) {
      print('[LanBloc] ✗ Failed to refresh settings: $e');
    }
  }

  void _onTransfersUpdated(LanTransfersUpdated event, Emitter<LanState> emit) {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;
    emit(currentState.copyWith(activeTransfers: event.transfers));
  }

  void _onCancelTransfer(LanCancelTransfer event, Emitter<LanState> emit) {
    _transferManager.cancelTransfer(event.transferId);
  }

  @override
  Future<void> close() {
    _devicesSubscription?.cancel();
    _transfersSubscription?.cancel(); // НОВОЕ
    _incomingTextsSubscription?.cancel();
    _stopFileRefresh();
    return super.close();
  }
}
