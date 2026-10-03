import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/settings_tone.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.photoPath,
    this.photoUrl,
    required this.tone,
    this.size = 96,
    this.onEdit,
    this.editKey = const Key('settings-edit-photo'),
  });

  final String? photoPath;
  final String? photoUrl;
  final SettingsTone tone;
  final double size;
  final VoidCallback? onEdit;
  final Key editKey;

  @override
  Widget build(BuildContext context) {
    final image = _photo(photoPath, photoUrl);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.panel,
              border: Border.all(color: tone.accent, width: 2),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            child: image == null
                ? Icon(
                    Icons.person_rounded,
                    color: tone.accent,
                    size: size * 0.46,
                  )
                : null,
          ),
          if (onEdit != null)
            PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Material(
                color: tone.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: editKey,
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.edit_rounded, color: tone.ink, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

ImageProvider<Object>? _photo(String? path, String? url) {
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
  }
  if (url != null && url.isNotEmpty) return NetworkImage(url);
  return null;
}
