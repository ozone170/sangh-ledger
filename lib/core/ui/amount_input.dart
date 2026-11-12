import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class AmountInput extends StatefulWidget {
  final String label;
  final String? hint;
  final int? initialPaise;
  final ValueChanged<int?> onChanged;
  final String? Function(int? paise)? validator;
  final bool enabled;

  const AmountInput({
    super.key,
    required this.label,
    this.hint = '0.00',
    this.initialPaise,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialText = widget.initialPaise != null
        ? (widget.initialPaise! / 100).toStringAsFixed(2)
        : '';
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final paise = CurrencyFormatter.parseToPaise(value);
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(paise);
      });
    }
    widget.onChanged(paise);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixText: '₹ ',
        prefixStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryNavy,
        ),
        errorText: _errorText,
      ),
      onChanged: _handleChanged,
    );
  }
}
