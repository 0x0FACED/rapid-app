import 'package:equatable/equatable.dart';
import 'device_info_model.dart';
import 'file_info_model.dart';

/// Модель запроса на отправку файлов
class SendRequestModel extends Equatable {
  final DeviceInfoModel info;
  final Map<String, FileInfoModel> files;

  const SendRequestModel({required this.info, required this.files});

  Map<String, dynamic> toJson() {
    return {
      'info': info.toJson(),
      'files': files.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory SendRequestModel.fromJson(Map<String, dynamic> json) {
    final filesJson = json['files'] as Map<String, dynamic>;
    final files = filesJson.map(
      (key, value) =>
          MapEntry(key, FileInfoModel.fromJson(value as Map<String, dynamic>)),
    );

    return SendRequestModel(
      info: DeviceInfoModel.fromJson(json['info'] as Map<String, dynamic>),
      files: files,
    );
  }

  @override
  List<Object?> get props => [info, files];
}
