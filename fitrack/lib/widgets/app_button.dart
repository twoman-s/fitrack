import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

enum _Variant { primary, outlined, ghost, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final bool compact;
  final Color? color;
  final _Variant _variant;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.color,
  }) : _variant = _Variant.primary;

  const AppButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.color,
  }) : _variant = _Variant.outlined;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = false,
    this.compact = false,
    this.color,
  }) : _variant = _Variant.ghost;

  const AppButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.color,
  }) : _variant = _Variant.destructive;

  @override
  Widget build(BuildContext context) {
    final btn = _buildButton();
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  double get _height => compact ? 38 : 52;
  double get _radius => compact ? 10 : 14;
  double get _fontSize => compact ? 13 : 15;
  double get _iconSize => compact ? 14 : 16;
  double get _spinnerSize => compact ? 16 : 20;

  Widget _buildContent(Color fgColor) {
    if (isLoading) {
      return SizedBox(
        width: _spinnerSize,
        height: _spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: fgColor,
        ),
      );
    }
    final textWidget = Text(
      label,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: fgColor,
        height: 1,
      ),
    );
    if (icon == null) return textWidget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: _iconSize, color: fgColor),
        SizedBox(width: compact ? 6 : 8),
        textWidget,
      ],
    );
  }

  Widget _buildButton() {
    switch (_variant) {
      case _Variant.primary:
        return _PrimaryButton(
          height: _height,
          radius: _radius,
          enabled: onPressed != null && !isLoading,
          onPressed: onPressed,
          child: _buildContent(Colors.white),
        );

      case _Variant.outlined:
        final fg = color ?? AppTheme.primary;
        return _TappableButton(
          height: _height,
          radius: _radius,
          enabled: onPressed != null && !isLoading,
          onPressed: onPressed,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.5),
          ),
          splashColor: fg.withValues(alpha: 0.12),
          child: _buildContent(fg),
        );

      case _Variant.ghost:
        final fg = color ?? AppTheme.primary;
        return _TappableButton(
          height: compact ? 32 : 40,
          radius: _radius,
          enabled: onPressed != null && !isLoading,
          onPressed: onPressed,
          decoration: const BoxDecoration(color: Colors.transparent),
          splashColor: fg.withValues(alpha: 0.10),
          child: _buildContent(fg),
        );

      case _Variant.destructive:
        const red = Color(0xFFEF4444);
        return _TappableButton(
          height: _height,
          radius: _radius,
          enabled: onPressed != null && !isLoading,
          onPressed: onPressed,
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: red.withValues(alpha: 0.25), width: 1),
          ),
          splashColor: red.withValues(alpha: 0.15),
          child: _buildContent(red),
        );
    }
  }
}

// ── Primary button — gradient + shadow ────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final double height;
  final double radius;
  final bool enabled;
  final VoidCallback? onPressed;
  final Widget child;

  const _PrimaryButton({
    required this.height,
    required this.radius,
    required this.enabled,
    required this.onPressed,
    required this.child,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _onTapDown(_) {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    setState(() => _pressed = true);
  }

  void _onTapUp(_) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.45;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Opacity(
          opacity: opacity,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: widget.enabled
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.40),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Generic tappable button (outlined / ghost / destructive) ──────────────────

class _TappableButton extends StatefulWidget {
  final double height;
  final double radius;
  final bool enabled;
  final VoidCallback? onPressed;
  final BoxDecoration decoration;
  final Color splashColor;
  final Widget child;

  const _TappableButton({
    required this.height,
    required this.radius,
    required this.enabled,
    required this.onPressed,
    required this.decoration,
    required this.splashColor,
    required this.child,
  });

  @override
  State<_TappableButton> createState() => _TappableButtonState();
}

class _TappableButtonState extends State<_TappableButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  void _onTapDown(_) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
  }

  void _onTapUp(_) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.45,
          child: Container(
            height: widget.height,
            decoration: widget.decoration,
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
