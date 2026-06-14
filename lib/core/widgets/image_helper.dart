import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/profile_viewmodel.dart';

/// Dynamically resolves an image provider for doctors or profiles, supporting assets, network URLs, or local files.
ImageProvider getImageProvider(String? urlOrPath, {String fallback = 'assets/doctors/doctor_1.png'}) {
  if (urlOrPath == null || urlOrPath.isEmpty) {
    return AssetImage(fallback);
  }
  if (urlOrPath.startsWith('assets/')) {
    return AssetImage(urlOrPath);
  }
  if (urlOrPath.startsWith('/') || urlOrPath.contains('/data/user/') || urlOrPath.contains('cache')) {
    // It's a local file path from the camera/gallery picker
    return FileImage(File(urlOrPath));
  }
  if (urlOrPath.startsWith('http')) {
    return NetworkImage(urlOrPath);
  }
  // Default fallback asset
  return AssetImage(urlOrPath);
}

/// Reusable desaturated user profile circular avatar for screen headers
class UserHeaderAvatar extends StatelessWidget {
  final double size;
  const UserHeaderAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
        image: DecorationImage(
          image: getImageProvider(
            profileVM.profileImagePath,
            fallback: 'assets/avatars/avatar_1.png',
          ),
          fit: BoxFit.cover,
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, -20,
            0.2126, 0.7152, 0.0722, 0, -20,
            0.2126, 0.7152, 0.0722, 0, -20,
            0,      0,      0,      1, 0,
          ]),
        ),
      ),
    );
  }
}
