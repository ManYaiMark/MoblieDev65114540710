import 'package:flutter/material.dart';
import 'package:myapp/page/myapp.dart';
// import 'package:get/get.dart';                
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();                   
  runApp(const MyApp());
}