import 'package:rapid/features/lan/data/models/transfer_progress_model.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/shared_file.dart';

abstract class LanState {
  const LanState();
}

class LanInitial extends LanState {}

class LanLoading extends LanState {}

class LanLoaded extends LanState {
  final UserSettings userSettings;
  final bool isShareMode; // true = Share, false = Receive
  final List<SharedFile> sharedFiles; // Файлы, которые мы расшарили
  final List<Device> availableDevices; // Доступные устройства в сети
  final Device? selectedDevice; // Выбранное устройство для просмотра
  final List<SharedFile>? receivedFiles; // Файлы от выбранного устройства
  final List<TransferProgressModel> activeTransfers; // НОВОЕ
  final int _updateCounter;

  const LanLoaded({
    required this.userSettings,
    this.isShareMode = true,
    this.sharedFiles = const [],
    this.availableDevices = const [],
    this.selectedDevice,
    this.receivedFiles,
    this.activeTransfers = const [], // НОВОЕ
    int updateCounter = 0,
  }) : _updateCounter = updateCounter;

  LanLoaded copyWith({
    UserSettings? userSettings,
    bool? isShareMode,
    List<SharedFile>? sharedFiles,
    List<Device>? availableDevices,
    Device? selectedDevice,
    List<SharedFile>? receivedFiles,
    List<TransferProgressModel>? activeTransfers,
    bool forceUpdate = false,
  }) {
    return LanLoaded(
      userSettings: userSettings ?? this.userSettings,
      isShareMode: isShareMode ?? this.isShareMode,
      sharedFiles: sharedFiles ?? this.sharedFiles,
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      receivedFiles: receivedFiles ?? this.receivedFiles,
      activeTransfers: activeTransfers ?? this.activeTransfers,
      updateCounter: forceUpdate ? _updateCounter + 1 : _updateCounter,
    );
  }

  @override
  List<Object?> get props => [
    userSettings,
    isShareMode,
    sharedFiles,
    availableDevices,
    selectedDevice,
    receivedFiles,
    activeTransfers,
  ];
}

class LanError extends LanState {
  final String message;

  const LanError(this.message);

  @override
  List<Object?> get props => [message];
}
