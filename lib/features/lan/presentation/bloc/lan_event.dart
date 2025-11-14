import 'package:equatable/equatable.dart';
import 'package:rapid/features/lan/data/models/transfer_progress_model.dart';
import 'package:rapid/features/lan/domain/entities/device.dart';

abstract class LanEvent extends Equatable {
  const LanEvent();

  @override
  List<Object?> get props => [];
}

/// Инициализация LAN экрана
class LanInitialize extends LanEvent {}

/// Переключение между Share и Receive
class LanToggleMode extends LanEvent {
  final bool isShareMode; // true = Share, false = Receive

  const LanToggleMode(this.isShareMode);

  @override
  List<Object?> get props => [isShareMode];
}

/// Выбор файлов для шаринга
class LanPickFiles extends LanEvent {}

/// Удаление файла из списка шаринга
class LanRemoveSharedFile extends LanEvent {
  final String fileId;

  const LanRemoveSharedFile(this.fileId);

  @override
  List<Object?> get props => [fileId];
}

/// Отправка текста
class LanSendText extends LanEvent {
  final String text;
  final String targetDeviceId;

  const LanSendText(this.text, this.targetDeviceId);

  @override
  List<Object?> get props => [text, targetDeviceId];
}

/// Обновление списка устройств (из DeviceDiscovery stream)
class LanDevicesUpdated extends LanEvent {
  final List<Device>? devices;

  const LanDevicesUpdated(this.devices);

  @override
  List<Object?> get props => [devices];
}

/// Выбор устройства для просмотра его файлов
class LanSelectDevice extends LanEvent {
  final String? deviceId; // null = deselect

  const LanSelectDevice(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

/// Отправить файлы на устройство
class LanSendFiles extends LanEvent {
  final String targetDeviceId;
  final List<String> fileIds; // ID файлов из sharedFiles

  const LanSendFiles(this.targetDeviceId, this.fileIds);

  @override
  List<Object?> get props => [targetDeviceId, fileIds];
}

/// Скачать файлы с устройства
class LanReceiveFiles extends LanEvent {
  final String sourceDeviceId;
  final List<String> fileIds;

  const LanReceiveFiles(this.sourceDeviceId, this.fileIds);

  @override
  List<Object?> get props => [sourceDeviceId, fileIds];
}

/// Обновление активных передач
class LanTransfersUpdated extends LanEvent {
  final List<TransferProgressModel> transfers;

  const LanTransfersUpdated(this.transfers);

  @override
  List<Object?> get props => [transfers];
}

/// Отменить передачу
class LanCancelTransfer extends LanEvent {
  final String transferId;

  const LanCancelTransfer(this.transferId);

  @override
  List<Object?> get props => [transferId];
}

class LanRefreshSettings extends LanEvent {}
