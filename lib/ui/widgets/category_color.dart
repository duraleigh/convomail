import 'package:flutter/material.dart';

/// The colour of a Feeds category: shown as a dot on each Feeds row and on
/// the category pills along the top, so a row needs no written tag. The
/// built-in categories have fixed colours; ones the user adds get one from
/// the spare colours, chosen by name so it stays the same.
Color feedsCategoryColor(String category, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final pair = _builtin[category] ?? _spare[_hash(category) % _spare.length];
  return dark ? pair.$1 : pair.$2;
}

/// (on a dark background, on a light one)
const _builtin = <String, (Color, Color)>{
  'Newsletter': (Color(0xFF64B5F6), Color(0xFF1565C0)),
  'Receipt': (Color(0xFF81C784), Color(0xFF2E7D32)),
  'Delivery': (Color(0xFFFFB74D), Color(0xFFE65100)),
  'Travel': (Color(0xFF4DD0E1), Color(0xFF00838F)),
  'OTP': (Color(0xFFE57373), Color(0xFFC62828)),
  'Notification': (Color(0xFFFFD54F), Color(0xFFB28704)),
  'Updates': (Color(0xFF9FA8DA), Color(0xFF3949AB)),
  'Social': (Color(0xFFF48FB1), Color(0xFFAD1457)),
  'Promotion': (Color(0xFFCE93D8), Color(0xFF7B1FA2)),
};

const _spare = <(Color, Color)>[
  (Color(0xFFAED581), Color(0xFF558B2F)),
  (Color(0xFFBCAAA4), Color(0xFF6D4C41)),
  (Color(0xFFFF8A65), Color(0xFFD84315)),
  (Color(0xFF80CBC4), Color(0xFF00695C)),
  (Color(0xFFB0BEC5), Color(0xFF455A64)),
  (Color(0xFFFFF176), Color(0xFF9E9D24)),
];

int _hash(String s) => s.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);

/// A small round dot in a category's colour.
class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.category, this.size = 10});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: feedsCategoryColor(category, Theme.of(context).brightness), shape: BoxShape.circle),
      );
}
