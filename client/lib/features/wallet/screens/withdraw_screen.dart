import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/auth/bloc/auth_bloc.dart';
import 'package:crash_game/features/wallet/repositories/wallet_repository.dart';
import 'package:crash_game/features/game/widgets/animated_space_background.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedMethod = 'bkash';
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // Withdrawal history
  List<Map<String, dynamic>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _loadWithdrawalHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadWithdrawalHistory() async {
    try {
      final data = await _walletRepo.getWithdrawals(limit: 10);
      if (mounted) {
        setState(() {
          _withdrawals = (data['withdrawals'] as List<dynamic>)
              .map((w) => w as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (_) {}
  }

  int get _currentBalance {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.balance;
    }
    return 0;
  }

  Future<void> _submitWithdrawal() async {
    final amountText = _amountController.text.trim();
    final phone = _phoneController.text.trim();

    // Validate phone number (Bangladesh: 11 digits starting with 01)
    final phoneRegex = RegExp(r'^01[3-9]\d{8}$');
    if (!phoneRegex.hasMatch(phone)) {
      setState(() => _errorMessage = 'Enter a valid Bangladesh phone number (e.g., 01712345678)');
      return;
    }

    // Validate amount
    final amountBdt = double.tryParse(amountText);
    if (amountBdt == null || amountBdt <= 0) {
      setState(() => _errorMessage = 'Enter a valid amount');
      return;
    }

    final amountPaisa = (amountBdt * 100).round();

    if (amountPaisa < 50000) { // ৳500 min
      setState(() => _errorMessage = 'Minimum withdrawal is ৳500');
      return;
    }

    if (amountPaisa > 2500000) { // ৳25,000 max
      setState(() => _errorMessage = 'Maximum withdrawal is ৳25,000');
      return;
    }

    if (amountPaisa > _currentBalance) {
      setState(() => _errorMessage = 'Insufficient balance');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _walletRepo.submitWithdrawal(
        method: _selectedMethod,
        phoneNumber: phone,
        amount: amountPaisa,
      );

      if (mounted) {
        // Update balance in AuthBloc
        final newBalance = result['balance'] as int?;
        if (newBalance != null) {
          context.read<AuthBloc>().add(AuthBalanceUpdated(newBalance));
        }

        setState(() {
          _isSubmitting = false;
          _successMessage = 'Withdrawal submitted! You will receive ৳${amountBdt.toStringAsFixed(0)} in your ${_selectedMethod == 'bkash' ? 'bKash' : 'Nagad'} account shortly.';
          _amountController.clear();
          _phoneController.clear();
        });
        _loadWithdrawalHistory();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to submit withdrawal';
        try {
          final dioError = e as dynamic;
          errorMsg = dioError.response?.data?['error'] ?? errorMsg;
        } catch (_) {}
        setState(() {
          _isSubmitting = false;
          _errorMessage = errorMsg;
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
          'Withdraw',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: AnimatedSpaceBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Current Balance ──
              _buildBalanceInfo(),
              const SizedBox(height: 20),

              // ── Method Selector ──
              _buildMethodSelector(),
              const SizedBox(height: 20),

              // ── Phone Number Input ──
              _buildInputField(
                controller: _phoneController,
                label: '${_selectedMethod == 'bkash' ? 'bKash' : 'Nagad'} Phone Number',
                hint: '01XXXXXXXXX',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              const SizedBox(height: 16),

              // ── Amount Input ──
              _buildInputField(
                controller: _amountController,
                label: 'Amount (BDT)',
                hint: 'e.g. 1000',
                prefix: '৳',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                suffix: _buildMaxButton(),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Min: ৳500 • Max: ৳25,000',
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),

              // ── Remaining Balance Preview ──
              _buildRemainingPreview(),
              const SizedBox(height: 20),

              // ── Error / Success Messages ──
              if (_errorMessage != null)
                _buildMessage(_errorMessage!, isError: true),
              if (_successMessage != null)
                _buildMessage(_successMessage!, isError: false),
              if (_errorMessage != null || _successMessage != null)
                const SizedBox(height: 16),

              // ── Submit Button ──
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFFF6D00).withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'SUBMIT WITHDRAWAL',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Withdrawal History ──
              if (_withdrawals.isNotEmpty) ...[
                Text(
                  'Recent Withdrawals',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._withdrawals.map(_buildWithdrawalHistoryItem),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceInfo() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final balance = state is AuthAuthenticated
            ? state.user.formattedBalance
            : '৳0.00';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                balance,
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF00E676),
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMethodSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildMethodTab('bkash', 'bKash', const Color(0xFFE2136E)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMethodTab('nagad', 'Nagad', const Color(0xFFFF6A00)),
        ),
      ],
    );
  }

  Widget _buildMethodTab(String method, String label, Color color) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMethod = method);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.white.withAlpha(15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? color : AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaxButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Set max amount (min of balance and ৳25,000)
        final maxPaisa = _currentBalance.clamp(0, 2500000);
        final maxBdt = maxPaisa / 100;
        _amountController.text = maxBdt.toStringAsFixed(0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentPurple.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'MAX',
          style: GoogleFonts.inter(
            color: AppTheme.accentPurple,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingPreview() {
    final amountText = _amountController.text.trim();
    final amountBdt = double.tryParse(amountText) ?? 0;
    final amountPaisa = (amountBdt * 100).round();
    final remaining = (_currentBalance - amountPaisa).clamp(0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withAlpha(150),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Remaining after withdrawal:',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
          Text(
            '৳${(remaining / 100).toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
              color: remaining > 0 ? AppTheme.textSecondary : const Color(0xFFFF1744),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}), // Trigger remaining preview update
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            prefixText: prefix,
            prefixStyle: GoogleFonts.jetBrainsMono(
              color: AppTheme.accentPurple,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffix,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(maxHeight: 36),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? const Color(0xFFFF1744) : const Color(0xFF00C853)).withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isError ? const Color(0xFFFF1744) : const Color(0xFF00C853)).withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color(0xFFFF1744) : const Color(0xFF00C853),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: isError ? const Color(0xFFFF1744) : const Color(0xFF00C853),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(Map<String, dynamic> withdrawal) {
    final status = withdrawal['status'] as String? ?? 'pending';
    final amount = withdrawal['formattedAmount'] as String? ?? '৳0';
    final method = withdrawal['method'] as String? ?? '';
    final phone = withdrawal['phoneNumber'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF00C853);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF1744);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFFFA000);
        statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$amount via ${method == 'bkash' ? 'bKash' : 'Nagad'}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'To: $phone',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
