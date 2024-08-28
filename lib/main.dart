import 'package:aut_all_research/best_frame_extraction.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PathService.initPath();
  runApp(const AppLauncher());
}

class AppLauncher extends StatelessWidget {
  const AppLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BestFrameExtraction(),
      themeMode: ThemeMode.dark,
    );
  }
}
