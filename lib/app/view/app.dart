import 'package:flutter/material.dart';
import '../router/app_router.dart';

class PicoApp extends StatelessWidget {
  const PicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Sau này sẽ bọc MultiProvider ở đây để quản lý State (Score, RoomID)
    return MaterialApp.router(
      title: 'Pico Flutter',
      theme: ThemeData(
        fontFamily: 'PixelifySans', // Nếu có font pixel
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router, // Sử dụng router đã tạo ở trên
      debugShowCheckedModeBanner: false,
    );
  }
}