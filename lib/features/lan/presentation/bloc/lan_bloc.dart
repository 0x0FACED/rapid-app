import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../../../../core/mdns/device_discovery.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/shared_file.dart';
import '../../../../core/network/transfer_manager.dart';
import '../../data/models/transfer_progress_model.dart';
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

  StreamSubscription? _devicesSubscription;
  StreamSubscription? _transfersSubscription; // НОВОЕ
  StreamSubscription? _incomingTextsSubscription;

  LanBloc(
    this._settingsRepository,
    this._deviceDiscovery,
    this._transferManager, // НОВОЕ
    this._sendFilesUseCase, // НОВОЕ
    this._receiveFilesUseCase, // НОВОЕ
    this._httpServer,
    this._apiClient,
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
          // Добавить чет по типу уведомлений
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
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;
    emit(currentState.copyWith(availableDevices: event.devices));
  }

  Future<void> _onSelectDevice(
    LanSelectDevice event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    if (event.deviceId == null) {
      // Deselect
      emit(currentState.copyWith(selectedDevice: null, receivedFiles: null));
      return;
    }

    try {
      // Находим устройство по ID
      final device = currentState.availableDevices.firstWhere(
        (d) => d.id == event.deviceId,
      );

      // НОВОЕ: Запрашиваем список файлов с устройства
      print('[LanBloc] Requesting files from ${device.name}...');

      final filesData = await _apiClient.getAvailableFiles(device.baseUrl);

      // Конвертируем в SharedFile
      final receivedFiles = filesData.map((fileData) {
        return SharedFile(
          id: fileData['id'] as String,
          name: fileData['fileName'] as String,
          path: '', // Путь не нужен для удалённых файлов
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

      print(
        '[LanBloc] Loaded ${receivedFiles.length} files from ${device.name}',
      );
    } catch (e) {
      print('[LanBloc] Failed to load files: $e');

      // Всё равно выбираем устройство, но без файлов
      final device = currentState.availableDevices.firstWhere(
        (d) => d.id == event.deviceId,
      );

      emit(currentState.copyWith(selectedDevice: device, receivedFiles: []));
    }
  }

  Future<void> _onSendText(LanSendText event, Emitter<LanState> emit) async {
    if (state is! LanLoaded) return;

    final currentState = state as LanLoaded;

    try {
      // Находим устройство
      final device = currentState.availableDevices.firstWhere(
        (d) => d.id == event.targetDeviceId,
      );

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

      print('[LanBloc] Text sent to ${device.name}: ${event.text}');
    } catch (e) {
      print('[LanBloc] Failed to send text: $e');
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

    // Находим устройство
    final device = currentState.availableDevices.firstWhere(
      (d) => d.id == event.sourceDeviceId,
    );

    // Находим файлы (TODO: получить реальный список с устройства)
    final filesToReceive = currentState.receivedFiles ?? [];

    if (filesToReceive.isEmpty) {
      print('[LanBloc] No files to receive');
      return;
    }

    try {
      // Запускаем получение асинхронно
      _receiveFilesUseCase
          .execute(sourceDevice: device, files: filesToReceive)
          .catchError((e) {
            print('[LanBloc] Receive files error: $e');
          });

      print(
        '[LanBloc] Started receiving ${filesToReceive.length} files from ${device.name}',
      );
    } catch (e) {
      print('[LanBloc] Error starting file receive: $e');
    }
  }

  Future<void> _onRefreshSettings(
    LanRefreshSettings event,
    Emitter<LanState> emit,
  ) async {
    if (state is! LanLoaded) return;

    try {
      final currentState = state as LanLoaded;
      final updatedSettings = await _settingsRepository.getSettings();

      // Проверяем, изменились ли настройки
      if (updatedSettings != currentState.userSettings) {
        emit(currentState.copyWith(userSettings: updatedSettings));
        print('[LanBloc] Settings refreshed: ${updatedSettings.deviceName}');
      }
    } catch (e) {
      print('[LanBloc] Failed to refresh settings: $e');
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
    return super.close();
  }
}
