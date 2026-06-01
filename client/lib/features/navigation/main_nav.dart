import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/game/screens/game_screen.dart';
import 'package:crash_game/features/wallet/screens/wallet_screen.dart';
import 'package:crash_game/features/profile/screens/profile_screen.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GameScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Wire up GameBloc → AuthBloc balance updates
    // This ensures real-time balance sync from WebSocket messages
    _wireBalanceUpdates();
  }

  void _wireBalanceUpdates() {
    final gameBloc = context.read<GameBloc>();
    final authBloc = context.read<AuthBloc>();
    gameBloc.onBalanceUpdate = (newBalance) {
      authBloc.add(AuthBalanceUpdated(newBalance));
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.accentPurple,
        unselectedItemColor: AppTheme.textMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.rocket_launch_outlined),
            activeIcon: Icon(Icons.rocket_launch),
            label: 'Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
