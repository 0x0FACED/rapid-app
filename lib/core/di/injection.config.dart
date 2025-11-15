// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/lan/domain/usecases/receive_files.dart' as _i408;
import '../../features/lan/domain/usecases/send_files.dart' as _i855;
import '../../features/lan/presentation/bloc/lan_bloc.dart' as _i368;
import '../../features/settings/data/repositories/settings_repository_impl.dart'
    as _i955;
import '../../features/settings/domain/repositories/settings_repository.dart'
    as _i674;
import '../../features/settings/presentation/bloc/settings_bloc.dart' as _i585;
import '../mdns/device_discovery.dart' as _i450;
import '../mdns/mdns_service.dart' as _i398;
import '../mdns/service_announcer.dart' as _i100;
import '../network/api_client.dart' as _i557;
import '../network/certificate_manager.dart' as _i531;
import '../network/http_server.dart' as _i756;
import '../network/transfer_manager.dart' as _i810;
import '../storage/shared_prefs_service.dart' as _i573;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    gh.lazySingleton<_i531.CertificateManager>(
        () => _i531.CertificateManager());
    gh.lazySingleton<_i810.TransferManager>(() => _i810.TransferManager());
    gh.lazySingleton<_i557.ApiClient>(() => _i557.ApiClient());
    gh.lazySingleton<_i573.SharedPrefsService>(
        () => _i573.SharedPrefsService());
    gh.lazySingleton<_i100.ServiceAnnouncer>(() => _i100.ServiceAnnouncer());
    gh.lazySingleton<_i398.MDnsService>(
        () => _i398.MDnsService(gh<_i573.SharedPrefsService>()));
    gh.factory<_i408.ReceiveFilesUseCase>(() => _i408.ReceiveFilesUseCase(
          gh<_i557.ApiClient>(),
          gh<_i810.TransferManager>(),
        ));
    gh.lazySingleton<_i674.SettingsRepository>(
        () => _i955.SettingsRepositoryImpl(gh<_i573.SharedPrefsService>()));
    gh.factory<_i585.SettingsBloc>(
        () => _i585.SettingsBloc(gh<_i674.SettingsRepository>()));
    gh.lazySingleton<_i756.HttpServerService>(
        () => _i756.HttpServerService(gh<_i531.CertificateManager>()));
    gh.factory<_i855.SendFilesUseCase>(() => _i855.SendFilesUseCase(
          gh<_i557.ApiClient>(),
          gh<_i810.TransferManager>(),
          gh<_i573.SharedPrefsService>(),
        ));
    gh.lazySingleton<_i450.DeviceDiscovery>(
        () => _i450.DeviceDiscovery(gh<_i398.MDnsService>()));
    gh.factory<_i368.LanBloc>(() => _i368.LanBloc(
          gh<_i674.SettingsRepository>(),
          gh<_i450.DeviceDiscovery>(),
          gh<_i810.TransferManager>(),
          gh<_i855.SendFilesUseCase>(),
          gh<_i408.ReceiveFilesUseCase>(),
          gh<_i756.HttpServerService>(),
          gh<_i557.ApiClient>(),
        ));
    return this;
  }
}
