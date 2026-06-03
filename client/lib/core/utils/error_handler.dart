import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'dart:ui';

class ErrorHandler {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showError(String message, {Duration duration = const Duration(seconds: 4)}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: _ErrorToast(message: message),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 24),
      ),
    );
  }
}

class _ErrorToast extends StatelessWidget {
  final String message;

  const _ErrorToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1418).withOpacity(0.85), // Dark red tint
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF4D4D).withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D4D).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4D).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFF4D4D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
