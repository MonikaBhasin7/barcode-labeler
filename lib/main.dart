import 'package:flutter/material.dart';

void main() {
  runApp(const BarcodeLabelerApp());
}

class BarcodeLabelerApp extends StatelessWidget {
  const BarcodeLabelerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Labeler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Labeler')),
      body: const Center(child: Text('No label designs yet')),
    );
  }
}
