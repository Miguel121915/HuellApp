import 'package:flutter/material.dart';

import 'screens/kiro_home_screen.dart';
import 'screens/foro_screen.dart';

class AppNavigation extends StatelessWidget {
  const AppNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HuellApp',
      initialRoute: '/',
      routes: {
        '/': (context) => const KiroHomeScreen(),
        '/foro': (context) => const ForoScreen(),
      },
    );
  }
}
