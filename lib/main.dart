import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация DI
  await configureDependencies();

  // Запуск приложения
  runApp(const RapidApp());
}
