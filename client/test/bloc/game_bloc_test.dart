import 'package:flutter_test/flutter_test.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

void main() {
  group('GameBloc', () {
    late GameBloc gameBloc;

    setUp(() {
      gameBloc = GameBloc();
    });

    tearDown(() {
      gameBloc.close();
    });

    test('initial state is correct', () {
      expect(gameBloc.state.phase, equals(GamePhase.connecting));
    });
  });
}
