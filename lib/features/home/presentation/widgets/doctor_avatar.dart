import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// The doctor's photo, or their initials when there is no real photo URL.
/// Never a stock photo of somebody else.
class DoctorAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const DoctorAvatar({super.key, required this.name, this.imageUrl, this.size = 52});

  static bool isRealUrl(String? url) {
    final u = Uri.tryParse(url?.trim() ?? '');
    return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
  }

  static String initialsOf(String name) {
    final words = name
        .replaceAll(RegExp(r'^(dr\.?|doctor)\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return 'Dr';
    final first = words.first[0];
    final last = words.length > 1 ? words.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: colors.primaryContainer,
      child: Text(
        initialsOf(name),
        style: context.text.titleMedium!.copyWith(color: colors.onPrimaryContainer, fontSize: size * 0.36),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
      ),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: isRealUrl(imageUrl)
            ? Image.network(
                imageUrl!.trim(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * dpr).round(),
                errorBuilder: (context, error, stack) => fallback,
                loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
              )
            : fallback,
      ),
    );
  }
}
