import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? extraClassName;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.extraClassName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark 
              ? const Color(0xFF2D3748)
              : Colors.white,
            border: isDark 
              ? null
              : Border.all(
                  color: const Color(0xFFD1D5DB),
                  width: 1,
                ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isDark 
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isDark 
                    ? const Color(0xFFA0AEC0)
                    : const Color(0xFF4A5568),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark 
                      ? const Color(0xFFE2E8F0) 
                      : const Color(0xFF2D3748),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 