import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';

class NunaKinTextField extends StatefulWidget {
  final String label;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;

  const NunaKinTextField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.controller,
    this.suffixIcon,
    this.focusNode,
    this.keyboardType,
  });

  @override
  State<NunaKinTextField> createState() => _NunaKinTextFieldState();
}

class _NunaKinTextFieldState extends State<NunaKinTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLabelVisible = _hasText || _isFocused;

    return AnimatedContainer(
      duration: NkDuration.hover,
      padding: const EdgeInsets.symmetric(
        horizontal: NkSpacing.s,
        vertical: NkSpacing.xs2,
      ),
      decoration: BoxDecoration(
        color: NkColors.surfaceCard,
        border: Border.all(
          color: _isFocused ? NkColors.mintSoft(0.4) : NkColors.surfaceBorder,
        ),
        borderRadius: NkRadius.forInput,
      ),
      child: Row(
        children: [
          Icon(
            widget.icon,
            color: _isFocused ? NkColors.mint : NkColors.fgHint,
            size: 20,
          ),
          const SizedBox(width: NkSpacing.xs3),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: NkDuration.hover,
                  curve: NkCurve.standard,
                  child: SizedBox(
                    height: isLabelVisible ? null : 0,
                    child: isLabelVisible
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              widget.label.toUpperCase(),
                              style: const TextStyle(
                                color: NkColors.mint,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NkColors.onDark,
                  ),
                  decoration: InputDecoration(
                    hintText: isLabelVisible ? null : widget.placeholder,
                    hintStyle: const TextStyle(
                      color: NkColors.fgHint,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          if (widget.suffixIcon != null) widget.suffixIcon!,
        ],
      ),
    );
  }
}
