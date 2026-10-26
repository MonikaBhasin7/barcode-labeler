import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';

class BarcodeLabelerApp extends StatelessWidget {
  const BarcodeLabelerApp({super.key, this.designPathToOpen});

  final String? designPathToOpen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Labeler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: HomeScreen(designPathToOpen: designPathToOpen),
    );
  }
}
