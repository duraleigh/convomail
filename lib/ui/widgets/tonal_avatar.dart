import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Initials for a display name: first letters of the first two words,
/// or the first letter of a single word, upper-cased.
String initialsFor(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words.first[0] + words[1][0]).toUpperCase();
}

/// Circular tonal avatar with deterministic color per contact (spec 5.1).
///
/// `key` is the identity used for the color (normally the primary email
/// address). Non-human Feeds senders pass `squircle: true` for a 12dp
/// rounded square so the two lists read differently at a glance.
class TonalAvatar extends StatelessWidget {
  const TonalAvatar({
    super.key,
    required this.identityKey,
    required this.name,
    this.size = 40,
    this.squircle = false,
    this.image,
    this.badge,
  });

  final String identityKey;
  final String name;
  final double size;
  final bool squircle;
  final ImageProvider? image;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tone = AvatarTones.forKey(identityKey, brightness);
    final radius = squircle ? BorderRadius.circular(AppShapes.md) : BorderRadius.circular(size);
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: radius,
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              initialsFor(name),
              style: TextStyle(
                color: tone.foreground,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.36,
                height: 1,
              ),
            )
          : null,
    );
    if (badge == null) return Semantics(label: name, child: avatar);
    return Semantics(
      label: name,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [avatar, Positioned(top: -5, right: -5, child: badge!)]),
      ),
    );
  }
}

/// Two overlapping small avatars for a user-defined group row (spec 4.19).
class StackedAvatars extends StatelessWidget {
  const StackedAvatars({super.key, required this.members, this.size = 36});

  /// (identityKey, name) for the first two members.
  final List<(String, String)> members;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = size * 0.67;
    final ring = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: scheme.surfaceContainerLowest, width: 2),
    );
    final a = members.isNotEmpty ? members[0] : ('', '?');
    final b = members.length > 1 ? members[1] : a;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(decoration: ring, child: TonalAvatar(identityKey: b.$1, name: b.$2, size: small)),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: DecoratedBox(decoration: ring, child: TonalAvatar(identityKey: a.$1, name: a.$2, size: small)),
          ),
        ],
      ),
    );
  }
}

/// Small numeric badge in primary (unread counts).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(AppShapes.full)),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w600, height: 1),
      ),
    );
  }
}
