import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

@injectable
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repository;

  SettingsBloc(this._repository) : super(SettingsInitial()) {
    on<SettingsInitialize>(_onInitialize);
    on<SettingsChangeTheme>(_onChangeTheme);
    on<SettingsChangeLanguage>(_onChangeLanguage);
    on<SettingsUpdateDeviceName>(_onUpdateDeviceName);
    on<SettingsUpdateAvatar>(_onUpdateAvatar);
    on<SettingsToggleHttps>(_onToggleHttps);
  }

  Future<void> _onInitialize(
    SettingsInitialize event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsLoading());

    try {
      final settings = await _repository.getSettings();
      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onChangeTheme(
    SettingsChangeTheme event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;

    try {
      await _repository.updateThemeMode(event.themeMode);

      final updatedSettings = currentSettings.copyWith(
        themeMode: event.themeMode,
      );

      emit(SettingsLoaded(updatedSettings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onChangeLanguage(
    SettingsChangeLanguage event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;

    try {
      await _repository.updateLanguage(event.language);

      final updatedSettings = currentSettings.copyWith(
        language: event.language,
      );

      emit(SettingsLoaded(updatedSettings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateDeviceName(
    SettingsUpdateDeviceName event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;

    try {
      await _repository.updateDeviceName(event.name);

      final updatedSettings = currentSettings.copyWith(deviceName: event.name);

      emit(SettingsLoaded(updatedSettings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateAvatar(
    SettingsUpdateAvatar event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;

    try {
      await _repository.updateAvatar(event.avatarPath);

      final updatedSettings = currentSettings.copyWith(
        avatar: event.avatarPath,
      );

      emit(SettingsLoaded(updatedSettings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }

  Future<void> _onToggleHttps(
    SettingsToggleHttps event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) return;

    final currentSettings = (state as SettingsLoaded).settings;

    try {
      await _repository.updateSettings(
        currentSettings.copyWith(useHttps: event.useHttps),
      );

      final updatedSettings = currentSettings.copyWith(
        useHttps: event.useHttps,
      );

      emit(SettingsLoaded(updatedSettings));
    } catch (e) {
      emit(SettingsError(e.toString()));
    }
  }
}
