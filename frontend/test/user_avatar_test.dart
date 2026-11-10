import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/models/user.dart';
import 'package:personal_finance_app/widgets/user_avatar.dart';

void main() {
  group('UserAvatar tests', () {
    testWidgets('shows question mark when user is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(user: null),
          ),
        ),
      );
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows uppercase first initial when user has name', (tester) async {
      final user = AppUser(
        id: 'u1',
        fullName: 'nguyen van a',
        passwordHash: 'hash',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatar(user: user),
          ),
        ),
      );
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('falls back to initial when avatarPath does not exist on disk', (tester) async {
      final user = AppUser(
        id: 'u1',
        fullName: 'Bình',
        avatarPath: '/path/to/nonexistent/file.jpg',
        passwordHash: 'hash',
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatar(user: user),
          ),
        ),
      );
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('AppUser avatar model tests', () {
    test('copyWith updates avatarPath and clearAvatar removes it', () {
      final user = AppUser(
        id: 'u1',
        fullName: 'Nam',
        passwordHash: 'hash',
        createdAt: DateTime(2026, 1, 1),
      );

      final withAvatar = user.copyWith(avatarPath: '/local/avatar.jpg');
      expect(withAvatar.avatarPath, '/local/avatar.jpg');

      final cleared = withAvatar.copyWith(clearAvatar: true);
      expect(cleared.avatarPath, isNull);

      final untouched = withAvatar.copyWith(fullName: 'Nam 2');
      expect(untouched.avatarPath, '/local/avatar.jpg');
      expect(untouched.fullName, 'Nam 2');
    });

    test('toMap and fromMap preserve avatar_path', () {
      final user = AppUser(
        id: 'u1',
        fullName: 'Nam',
        passwordHash: 'hash',
        avatarPath: '/local/avatar.jpg',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toMap();
      expect(map['avatar_path'], '/local/avatar.jpg');

      final restored = AppUser.fromMap(map);
      expect(restored.avatarPath, '/local/avatar.jpg');
    });
  });
}
