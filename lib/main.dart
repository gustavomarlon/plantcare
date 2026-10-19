
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const PlantCareApp());
  } catch (erro) {
    runApp(
      MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erro ao iniciar o Firebase:\n\n$erro',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantCare',
      debugShowCheckedModeBanner: false,

      // Mantém os dois temas disponíveis.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      // Ativa o modo escuro independentemente do sistema.
      themeMode: ThemeMode.dark,

      home: const LoginScreen(),
    );
  }
}
