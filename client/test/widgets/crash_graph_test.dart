import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crash_game/features/game/widgets/crash_graph.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

void main() {
  testWidgets('CrashGraph renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CrashGraph(
            multiplierHistory: [1.0],
            currentMultiplier: 1.0,
            phase: GamePhase.betting,
            cashoutMultiplier: null,
          ),
        ),
      ),
    );

    // Verify widget rendered successfully by finding it
    expect(find.byType(CrashGraph), findsOneWidget);
  });
}
