import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user.dart';

class UserAvatar extends StatelessWidget {
  final AppUser? user;
  final double radius;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final avatarPath = user?.avatarPath;
    final hasValidFile = avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();

    if (hasValidFile) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(avatarPath)),
      );
    }

    final initial = (user != null && user!.fullName.trim().isNotEmpty)
        ? user!.fullName.trim()[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
