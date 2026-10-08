import 'package:flutter/material.dart';
import 'app.dart';
import 'core/database/db_helper.dart';
import 'core/network/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await DbHelper.instance.database;
  await ApiClient.instance.loadToken();
  runApp(App(database: database));
}
