import 'package:flutter/material.dart';

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    required this.avatarKey,
    this.radius = 20,
  });

  final String name;
  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final normalizedKey = _normalizedAvatarKey;
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: Image.asset(
          'assets/avatars/$normalizedKey.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              CircleAvatar(radius: radius, child: Text(_initial)),
        ),
      ),
    );
  }

  String get _normalizedAvatarKey {
    final key = avatarKey.trim();
    if (RegExp(r'^[a-z0-9_-]{3,64}$').hasMatch(key)) {
      return key;
    }
    return 'elementary_unspecified_01';
  }

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first;
  }
}
