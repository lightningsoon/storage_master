import 'package:flutter/material.dart';
import 'screens/item_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '收纳大师',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const ItemListScreen(),
    );
  }
} 