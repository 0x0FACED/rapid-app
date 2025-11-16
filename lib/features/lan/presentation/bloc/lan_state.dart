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
  final bool isShareMode;
  final List<SharedFile> sharedFiles;
  final List<Device> availableDevices;
  final Device? selectedDevice;
  final List<SharedFile>? receivedFiles;
  final List<TransferProgressModel> activeTransfers;
  final List<Device> favoriteDevices;

  const LanLoaded({
    required this.userSettings,
    this.isShareMode = true,
    this.sharedFiles = const [],
    this.availableDevices = const [],
    this.selectedDevice,
    this.receivedFiles,
    this.activeTransfers = const [],
    this.favoriteDevices = const [],
  });

  // ИСПРАВЛЕНО: Правильный copyWith с nullable
  LanLoaded copyWith({
    UserSettings? userSettings,
    bool? isShareMode,
    List<SharedFile>? sharedFiles,
    List<Device>? availableDevices,
    Device? selectedDevice, // НЕПРАВИЛЬНО - не сбросит в null
    List<SharedFile>? receivedFiles,
    List<TransferProgressModel>? activeTransfers,
    List<Device>? favoriteDevices,
    bool clearSelectedDevice = false, // НОВОЕ: explicit flag
    bool clearReceivedFiles = false, // НОВОЕ: explicit flag
  }) {
    return LanLoaded(
      userSettings: userSettings ?? this.userSettings,
      isShareMode: isShareMode ?? this.isShareMode,
      sharedFiles: sharedFiles ?? this.sharedFiles,
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDevice: clearSelectedDevice
          ? null
          : (selectedDevice ?? this.selectedDevice),
      receivedFiles: clearReceivedFiles
          ? null
          : (receivedFiles ?? this.receivedFiles),
      activeTransfers: activeTransfers ?? this.activeTransfers,
      favoriteDevices: favoriteDevices ?? this.favoriteDevices,
    );
  }
}

class LanError extends LanState {
  final String message;

  const LanError(this.message);

  @override
  List<Object?> get props => [message];
}
