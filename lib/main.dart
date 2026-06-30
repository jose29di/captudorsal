import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/dependency_container.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = DependencyContainer();
  await container.initialize();

  runApp(MyApp(dependencyContainer: container));
}

class MyApp extends StatelessWidget {
  final DependencyContainer dependencyContainer;

  const MyApp({super.key, required this.dependencyContainer});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => dependencyContainer.cameraProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => dependencyContainer.detectionProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => dependencyContainer.roiProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => dependencyContainer.dorsalProvider,
        ),
      ],
      child: MaterialApp(
        title: 'CaptuDorsal',
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
