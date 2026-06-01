import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crash_game/config/theme.dart';
import 'package:crash_game/features/wallet/repositories/wallet_repository.dart';
import 'package:crash_game/features/game/widgets/animated_space_background.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  final _amountController = TextEditingController();
  final _txIdController = TextEditingController();

  String _selectedMethod = 'bkash';
  String _paymentNumber = '01637858197';
  List<String> _instructions = [];
  int _minDeposit = 10000;
  int _maxDeposit = 5000000;
  bool _isLoadingInfo = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // Deposit history
  List<Map<String, dynamic>> _deposits = [];

  @override
  void initState() {
    super.initState();
    _loadDepositInfo();
    _loadDepositHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _txIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDepositInfo() async {
    try {
      final data = await _walletRepo.getDepositInfo();
      if (mounted) {
        setState(() {
          _paymentNumber = data['payment_number'] as String? ?? '01637858197';
          _minDeposit = data['min_amount'] as int? ?? 10000;
          _maxDeposit = data['max_amount'] as int? ?? 5000000;
          _instructions = (data['instructions'] as List<dynamic>?)
              ?.map((i) => i.toString())
              .toList() ?? [];
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
      }
    }
  }

  Future<void> _loadDepositHistory() async {
    try {
      final data = await _walletRepo.getDeposits(limit: 10);
      if (mounted) {
        setState(() {
          _deposits = (data['deposits'] as List<dynamic>)
              .map((d) => d as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _submitDeposit() async {
    final amountText = _amountController.text.trim();
    final txId = _txIdController.text.trim();

    // Validate amount
    final amountBdt = double.tryParse(amountText);
    if (amountBdt == null || amountBdt <= 0) {
      setState(() => _errorMessage = 'Enter a valid amount');
      return;
    }

    final amountPaisa = (amountBdt * 100).round();
    if (amountPaisa < _minDeposit) {
      setState(() => _errorMessage = 'Minimum deposit is ৳${(_minDeposit / 100).toStringAsFixed(0)}');
      return;
    }
    if (amountPaisa > _maxDeposit) {
      setState(() => _errorMessage = 'Maximum deposit is ৳${(_maxDeposit / 100).toStringAsFixed(0)}');
      return;
    }

    // Validate transaction ID
    if (txId.isEmpty) {
      setState(() => _errorMessage = 'Enter the transaction ID from your ${_selectedMethod == 'bkash' ? 'bKash' : 'Nagad'} receipt');
      return;
    }
    if (txId.length < 4 || txId.length > 30) {
      setState(() => _errorMessage = 'Transaction ID must be 4-30 characters');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _walletRepo.submitDeposit(
        method: _selectedMethod,
        transactionId: txId,
        amount: amountPaisa,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successMessage = 'Deposit submitted! Your balance will be credited after verification.';
          _amountController.clear();
          _txIdController.clear();
        });
        _loadDepositHistory();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to submit deposit';
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
          'Deposit',
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
              // ── Method Selector ──
              _buildMethodSelector(),
              const SizedBox(height: 20),

              // ── Payment Number Card ──
              _buildPaymentNumberCard(),
              const SizedBox(height: 20),

              // ── Instructions ──
              if (_instructions.isNotEmpty) ...[
                _buildInstructions(),
                const SizedBox(height: 20),
              ],

              // ── Amount Input ──
              _buildInputField(
                controller: _amountController,
                label: 'Amount (BDT)',
                hint: 'e.g. 500',
                prefix: '৳',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Min: ৳${(_minDeposit / 100).toStringAsFixed(0)} • Max: ৳${(_maxDeposit / 100).toStringAsFixed(0)}',
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              // ── Transaction ID Input ──
              _buildInputField(
                controller: _txIdController,
                label: 'Transaction ID',
                hint: 'Enter your ${_selectedMethod == 'bkash' ? 'bKash' : 'Nagad'} Transaction ID',
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(30),
                ],
              ),
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
                  onPressed: _isSubmitting ? null : _submitDeposit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF00C853).withAlpha(80),
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
                          'SUBMIT DEPOSIT',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Deposit History ──
              if (_deposits.isNotEmpty) ...[
                Text(
                  'Recent Deposits',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._deposits.map(_buildDepositHistoryItem),
              ],
            ],
          ),
        ),
      ),
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

  Widget _buildPaymentNumberCard() {
    final Color methodColor =
        _selectedMethod == 'bkash' ? const Color(0xFFE2136E) : const Color(0xFFFF6A00);
    final String methodName = _selectedMethod == 'bkash' ? 'bKash' : 'Nagad';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: methodColor.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: methodColor.withAlpha(40)),
      ),
      child: Column(
        children: [
          Text(
            'Send money via $methodName Cash Out to:',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _paymentNumber,
                style: GoogleFonts.jetBrainsMono(
                  color: methodColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _paymentNumber));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Number copied: $_paymentNumber'),
                      backgroundColor: methodColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.copy, color: methodColor, size: 20),
                tooltip: 'Copy number',
                style: IconButton.styleFrom(
                  backgroundColor: methodColor.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Deposit',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_instructions.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                        color: AppTheme.accentPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _instructions[i],
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
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

  Widget _buildDepositHistoryItem(Map<String, dynamic> deposit) {
    final status = deposit['status'] as String? ?? 'pending';
    final amount = deposit['formattedAmount'] as String? ?? '৳0';
    final method = deposit['method'] as String? ?? '';
    final txId = deposit['transactionId'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
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
                  'TxID: $txId',
                  style: GoogleFonts.jetBrainsMono(
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
