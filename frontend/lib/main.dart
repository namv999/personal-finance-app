import 'package:flutter/material.dart';
import 'app.dart';
import 'core/database/db_helper.dart';
import 'core/network/api_client.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await DbHelper.instance.database;
  await ApiClient.instance.loadToken();
  await NotificationService.instance.init();
  runApp(App(database: database));
}
