import 'dart:io';
import 'package:flutter/foundation.dart'; // Thêm thư viện này để dùng kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

// Class này giúp bỏ qua lỗi chứng chỉ SSL khi dùng conveyor.cloud hoặc localhost
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kích hoạt HttpOverrides CHỈ KHI KHÔNG PHẢI LÀ WEB
  // (Vì HttpOverrides không hoạt động trên trình duyệt)
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Lỗi tải .env: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotFlex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFE50914),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
