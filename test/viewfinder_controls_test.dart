import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/camera_options.dart';
import 'package:swift_photo/screens/viewfinder_controls.dart';

void main() {
  testWidgets('Ratio menu selects a different output ratio', (tester) async {
    var selected = PhotoRatio.portrait;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RatioControl(
              ratio: selected,
              enabled: true,
              facing: 'BELAKANG',
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('photo-ratio-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-ratio-square')));
    await tester.pumpAndSettle();

    expect(selected, PhotoRatio.square);
    expect(find.text('1:1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
