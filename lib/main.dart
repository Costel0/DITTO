import 'package:flutter/material.dart';

void main() {
  runApp(const DittoApp());
}

class DittoApp extends StatelessWidget {
  const DittoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DITTO',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text('Hello World'),
        ),
      ),
    );
  }
}
