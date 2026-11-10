
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/image_helper.dart';
import 'package:phia_flutter/features/profile/data/profile_photo_store.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:provider/provider.dart';

/// Initials for an avatar: "Asha Rao" -> "AR". Empty when there is no name.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

/// Avatar, name and contact line at the top of the profile tab.
class ProfileHeader extends StatelessWidget {
  final String name;
  final String contact;
  final String? imagePath;

  const ProfileHeader({super.key, required this.name, required this.contact, this.imagePath});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        _Avatar(name: name, imagePath: imagePath),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            name.isEmpty ? 'Your profile' : name,
            style: context.text.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        if (contact.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            contact,
            style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  const _Avatar({required this.name, this.imagePath});

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPhoto = imagePath != null && imagePath!.isNotEmpty;
    final initials = initialsFor(name);

    return Semantics(
      button: true,
      label: hasPhoto ? 'Profile photo. Tap to change.' : 'Add a profile photo',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showProfilePhotoSheet(context, hasPhoto: hasPhoto),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer,
                border: Border.all(color: colors.surface, width: 3),
                image: hasPhoto
                    ? DecorationImage(
                        image: ResizeImage(getImageProvider(imagePath!), width: 288),
                        fit: BoxFit.cover,
                        // A photo file that no longer exists falls back to the tinted circle.
                        onError: (error, stack) {},
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasPhoto
                  ? null
                  : initials.isEmpty
                      ? Icon(Icons.person_rounded, size: 44, color: colors.onPrimaryContainer)
                      : Text(
                          initials,
                          style: context.text.headlineSmall!.copyWith(color: colors.onPrimaryContainer),
                          textScaler: TextScaler.noScaling,
                        ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Icon(Icons.photo_camera_outlined, size: AppSizes.iconSm, color: colors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Take, choose or remove the profile photo.
Future<void> showProfilePhotoSheet(BuildContext context, {required bool hasPhoto}) {
  final vm = context.read<ProfileViewModel>();
  final screenContext = context;

  Future<void> pick(BuildContext sheetContext, ImageSource source) async {
    Navigator.pop(sheetContext);
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return;
      final stored = await ProfilePhotoStore.keep(picked.path);
      final old = vm.profileImagePath;
      await vm.saveProfileImagePath(stored);
      await ProfilePhotoStore.discard(old, keep: stored);
      if (screenContext.mounted) {
        showAppMessage(screenContext, 'Profile photo updated.', type: FeedbackType.success);
      }
    } catch (e) {
      debugPrint('Profile photo error: $e');
      if (screenContext.mounted) {
        showAppMessage(screenContext, "Couldn't update your photo. Please try again.", type: FeedbackType.error);
      }
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => pick(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => pick(sheetContext, ImageSource.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: sheetContext.colors.danger.foreground),
              title: Text('Remove photo', style: TextStyle(color: sheetContext.colors.danger.foreground)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final old = vm.profileImagePath;
                await vm.saveProfileImagePath(null);
                await ProfilePhotoStore.discard(old);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
