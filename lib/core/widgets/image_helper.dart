import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Dynamically resolves an image provider for doctors or profiles, supporting assets, network URLs, or local files.
ImageProvider getImageProvider(String? urlOrPath, {String fallback = 'assets/doctors/doctor_1.png'}) {
  if (urlOrPath == null || urlOrPath.isEmpty) {
    return AssetImage(fallback);
  }
  if (urlOrPath.startsWith('assets/')) {
    return AssetImage(urlOrPath);
  }
  // Check URLs first: a web address can contain "cache" in its path.
  if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
    return NetworkImage(urlOrPath);
  }
  if (urlOrPath.startsWith('/')) {
    // Local file from the camera/gallery picker
    return FileImage(File(urlOrPath));
  }
  // Default fallback asset
  return AssetImage(urlOrPath);
}

/// Safe Network Image that handles errors gracefully without throwing UI exceptions
class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: context.colors.surfaceMuted,
        child: Icon(fallbackIcon, color: context.colors.textMuted, size: (width != null ? width! * 0.5 : 24)),
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: context.colors.surfaceMuted,
            child: Icon(fallbackIcon, color: context.colors.textMuted, size: (width != null ? width! * 0.5 : 24)),
          );
        },
      );
    }

    if (imageUrl.startsWith('/') || imageUrl.contains('/data/user/') || imageUrl.contains('cache')) {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: context.colors.surfaceMuted,
            child: Icon(fallbackIcon, color: context.colors.textMuted, size: (width != null ? width! * 0.5 : 24)),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: context.colors.surfaceMuted,
          child: Icon(fallbackIcon, color: context.colors.textMuted, size: (width != null ? width! * 0.5 : 24)),
        );
      },
    );
  }
}
