import 'package:convomail/ui/theme/app_theme.dart';
import 'package:convomail/ui/theme/tokens.dart';
import 'package:convomail/ui/widgets/grouped_list.dart';
import 'package:convomail/ui/widgets/tonal_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('color schemes', () {
    test('light and dark schemes carry the mockup token values', () {
      expect(AppColors.light.primary, const Color(0xFF4653D0));
      expect(AppColors.light.surfaceContainerLowest, const Color(0xFFFFFFFF));
      expect(AppColors.dark.primary, const Color(0xFFBDC2FF));
      expect(AppColors.dark.surface, const Color(0xFF131318));
    });

    test('themes are Material 3 and use Segoe UI Variable', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(light.useMaterial3, isTrue);
      expect(dark.brightness, Brightness.dark);
      expect(light.textTheme.bodyLarge!.fontFamily, AppTheme.fontFamily);
      expect(light.textTheme.headlineMedium!.fontWeight, FontWeight.w700);
    });

    test('FAB uses the 16dp large shape', () {
      final shape = AppTheme.light().floatingActionButtonTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppShapes.lg));
    });
  });

  group('avatar tones', () {
    test('are deterministic and case-insensitive', () {
      expect(AvatarTones.indexFor('sarah.chen@example.com'), AvatarTones.indexFor('Sarah.Chen@Example.com'));
      expect(AvatarTones.indexFor('a@example.com'), AvatarTones.indexFor('a@example.com'));
    });

    test('spread across the palette', () {
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seen.add(AvatarTones.indexFor('user$i@example.com'));
      }
      expect(seen.length, AvatarTones.light.length);
    });

    test('initials follow first-two-words rule', () {
      expect(initialsFor('Sarah Chen'), 'SC');
      expect(initialsFor('Anna Bergström'), 'AB');
      expect(initialsFor('Madonna'), 'M');
      expect(initialsFor('  '), '?');
      expect(initialsFor('Design Weekly Digest'), 'DW');
    });
  });

  group('grouped list radii', () {
    const outer = Radius.circular(AppShapes.lgIncreased);
    const inner = Radius.circular(AppShapes.xs);

    test('single item is fully rounded', () {
      expect(GroupedList.radiusFor(0, 1), const BorderRadius.all(outer));
    });

    test('first, middle, last', () {
      expect(GroupedList.radiusFor(0, 3), const BorderRadius.vertical(top: outer, bottom: inner));
      expect(GroupedList.radiusFor(1, 3), const BorderRadius.all(inner));
      expect(GroupedList.radiusFor(2, 3), const BorderRadius.vertical(top: inner, bottom: outer));
    });
  });
}
