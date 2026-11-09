import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives the test window room for a few scaled devices.
void useLargeWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A shared list of items, like an app-level store living above MaterialApp.
final List<String> items = List.generate(60, (i) => 'Item $i');

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details $title')),
      body: const Center(child: Text('details body')),
    );
  }
}
