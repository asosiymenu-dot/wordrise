import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.name,
    this.avatarUrl,
    this.size = 46,
    this.backgroundColor,
    this.online,
    this.border,
    this.onTap,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final Color? backgroundColor;
  final bool? online;
  final BoxBorder? border;
  final VoidCallback? onTap;

  static String resolveUrl(String? raw) {
    if (raw == null) return '';
    final url = raw.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Relative path handling
    const apiBase = ApiConfig.baseUrl; // e.g. https://domain/wordrise-api/api
    final rootBase = apiBase.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$rootBase/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = resolveUrl(avatarUrl);
    final fallback = _AvatarFallback(
      name: name,
      size: size,
      color: backgroundColor,
    );

    Widget avatarContent = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: fullUrl.isEmpty
            ? fallback
            : Image.network(
                fullUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return fallback;
                },
              ),
      ),
    );

    if (border != null) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
        ),
        child: avatarContent,
      );
    }

    Widget result = avatarContent;
    if (online != null) {
      result = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatarContent,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * .28,
                height: size * .28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online! ? AppColors.green : AppColors.textMuted(context),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: result,
      );
    }

    return result;
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.name,
    required this.size,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientForName(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: color != null
            ? null
            : LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: color,
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * .38,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  static List<Color> _getGradientForName(String name) {
    final gradients = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // Indigo to Purple
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // Blue to Cyan
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)], // Pink to Rose
      [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald to Teal
      [const Color(0xFFF59E0B), const Color(0xFFEA580C)], // Amber to Orange
      [const Color(0xFF8B5CF6), const Color(0xFFD946EF)], // Purple to Fuchsia
    ];
    final hash = name.codeUnits.fold<int>(0, (sum, val) => sum + val);
    return gradients[hash % gradients.length];
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'W';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
