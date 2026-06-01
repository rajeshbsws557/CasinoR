// ============================================
// Profile Screen — User Profile & Payment Methods
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/auth/models/user_model.dart';
import 'package:crash_game/features/auth/repositories/auth_repository.dart';
import 'package:crash_game/features/game/widgets/animated_space_background.dart';
import 'package:crash_game/features/game/bloc/game_bloc.dart';
import 'package:crash_game/core/widgets/glass_container.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepo = AuthRepository();
  bool _isLoadingProfile = true;
  UserModel? _fullProfile;

  // Payment method editing
  final _bkashController = TextEditingController();
  final _nagadController = TextEditingController();
  bool _isSavingPayment = false;
  String? _paymentMessage;
  bool _paymentIsError = false;

  // Username editing
  final _usernameController = TextEditingController();
  bool _isEditingUsername = false;
  bool _isSavingUsername = false;

  @override
  void initState() {
    super.initState();
    _loadFullProfile();
  }

  @override
  void dispose() {
    _bkashController.dispose();
    _nagadController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadFullProfile() async {
    try {
      final profile = await _authRepo.getProfile();
      if (mounted && profile != null) {
        setState(() {
          _fullProfile = profile;
          _isLoadingProfile = false;
          _usernameController.text = profile.username;

          // Pre-fill payment methods
          for (final pm in profile.paymentMethods) {
            if (pm.type == 'bkash') _bkashController.text = pm.phoneNumber;
            if (pm.type == 'nagad') _nagadController.text = pm.phoneNumber;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty || newUsername.length < 3) return;

    setState(() => _isSavingUsername = true);
    try {
      await _authRepo.updateProfile(username: newUsername);
      if (mounted) {
        setState(() {
          _isEditingUsername = false;
          _isSavingUsername = false;
        });
        // Refresh profile in BLoC
        context.read<AuthBloc>().add(AuthCheckRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username updated!'),
            backgroundColor: AppTheme.winGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingUsername = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update username'),
            backgroundColor: AppTheme.lossRed,
          ),
        );
      }
    }
  }

  Future<void> _savePaymentMethods() async {
    final methods = <PaymentMethod>[];

    final bkash = _bkashController.text.trim();
    final nagad = _nagadController.text.trim();

    if (bkash.isNotEmpty) {
      if (bkash.length < 11 || bkash.length > 14) {
        setState(() {
          _paymentMessage = 'bKash number must be 11-14 digits';
          _paymentIsError = true;
        });
        return;
      }
      methods.add(PaymentMethod(type: 'bkash', phoneNumber: bkash));
    }

    if (nagad.isNotEmpty) {
      if (nagad.length < 11 || nagad.length > 14) {
        setState(() {
          _paymentMessage = 'Nagad number must be 11-14 digits';
          _paymentIsError = true;
        });
        return;
      }
      methods.add(PaymentMethod(type: 'nagad', phoneNumber: nagad));
    }

    setState(() {
      _isSavingPayment = true;
      _paymentMessage = null;
    });

    try {
      await _authRepo.updatePaymentMethods(methods);
      if (mounted) {
        setState(() {
          _isSavingPayment = false;
          _paymentMessage = 'Payment methods saved!';
          _paymentIsError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingPayment = false;
          _paymentMessage = 'Failed to save payment methods';
          _paymentIsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: AnimatedSpaceBackground(
        child: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState is! AuthAuthenticated) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentPurple),
                );
              }

              final user = authState.user;

              return RefreshIndicator(
                onRefresh: _loadFullProfile,
                color: AppTheme.accentPurple,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildAvatarSection(user),
                    const SizedBox(height: 24),
                    _buildInfoCard(user),
                    const SizedBox(height: 20),
                    _buildStatsCard(user),
                    const SizedBox(height: 20),
                    _buildPaymentMethodsCard(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(context),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(UserModel user) {
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPurple.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.username,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(UserModel user) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Account Info',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isEditingUsername = !_isEditingUsername),
                child: Icon(
                  _isEditingUsername ? Icons.close : Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Username',
            child: _isEditingUsername
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isSavingUsername ? null : _saveUsername,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.winGreen.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _isSavingUsername
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.winGreen,
                                  ),
                                )
                              : const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: AppTheme.winGreen,
                                ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    user.username,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            child: Text(
              user.email,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Joined',
            child: Text(
              _formatJoinDate(_fullProfile?.createdAt),
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildStatsCard(UserModel user) {
    final profile = _fullProfile ?? user;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stats',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Balance',
                  value: user.formattedBalance,
                  color: AppTheme.winGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  label: 'Total Wagered',
                  value: profile.formattedWagered,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  label: 'Profit',
                  value: profile.formattedProfit,
                  color: profile.totalProfit >= 0
                      ? AppTheme.winGreen
                      : AppTheme.lossRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Methods',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.payment, size: 18, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add your bKash / Nagad numbers for quick withdrawals',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // bKash
          _buildPaymentInput(
            controller: _bkashController,
            label: 'bKash Number',
            color: const Color(0xFFE2136E),
            hint: '01XXXXXXXXX',
          ),
          const SizedBox(height: 12),

          // Nagad
          _buildPaymentInput(
            controller: _nagadController,
            label: 'Nagad Number',
            color: const Color(0xFFFF6A00),
            hint: '01XXXXXXXXX',
          ),
          const SizedBox(height: 16),

          // Message
          if (_paymentMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_paymentIsError ? AppTheme.lossRed : AppTheme.winGreen)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _paymentIsError ? Icons.error_outline : Icons.check_circle_outline,
                    size: 16,
                    color: _paymentIsError ? AppTheme.lossRed : AppTheme.winGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _paymentMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _paymentIsError ? AppTheme.lossRed : AppTheme.winGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Save button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSavingPayment ? null : _savePaymentMethods,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: _isSavingPayment
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'SAVE PAYMENT METHODS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInput({
    required TextEditingController controller,
    required String label,
    required Color color,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
          ],
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10,
            ),
            prefixIcon: Icon(Icons.phone, size: 16, color: color),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.read<GameBloc>().add(GameDisconnectRequested());
          context.read<AuthBloc>().add(AuthLogoutRequested());
        },
        icon: const Icon(Icons.logout, size: 18),
        label: Text(
          'LOGOUT',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.lossRed,
          side: BorderSide(color: AppTheme.lossRed.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  String _formatJoinDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
