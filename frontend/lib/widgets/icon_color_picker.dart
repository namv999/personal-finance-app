import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Small curated icon set for wallets/categories (kept short and legible
/// rather than exposing all of Material Icons).
const List<IconData> kPickableIcons = [
  Icons.account_balance_wallet,
  Icons.savings,
  Icons.credit_card,
  Icons.payments,
  Icons.restaurant,
  Icons.directions_car,
  Icons.shopping_bag,
  Icons.receipt_long,
  Icons.movie,
  Icons.favorite,
  Icons.home,
  Icons.school,
  Icons.flight,
  Icons.pets,
  Icons.card_giftcard,
  Icons.fitness_center,
];

IconData iconFromName(String? name) {
  switch (name) {
    case 'account_balance_wallet':
      return Icons.account_balance_wallet;
    case 'savings':
      return Icons.savings;
    case 'credit_card':
      return Icons.credit_card;
    case 'payments':
      return Icons.payments;
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_car':
      return Icons.directions_car;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'movie':
      return Icons.movie;
    case 'favorite':
      return Icons.favorite;
    case 'home':
      return Icons.home;
    case 'school':
      return Icons.school;
    case 'flight':
      return Icons.flight;
    case 'pets':
      return Icons.pets;
    case 'card_giftcard':
      return Icons.card_giftcard;
    case 'fitness_center':
      return Icons.fitness_center;
    default:
      return Icons.category;
  }
}

String iconToName(IconData icon) {
  for (final entry in {
    'account_balance_wallet': Icons.account_balance_wallet,
    'savings': Icons.savings,
    'credit_card': Icons.credit_card,
    'payments': Icons.payments,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'home': Icons.home,
    'school': Icons.school,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'card_giftcard': Icons.card_giftcard,
    'fitness_center': Icons.fitness_center,
  }.entries) {
    if (entry.value == icon) return entry.key;
  }
  return 'category';
}

Color colorFromHex(String? hex) {
  if (hex == null) return AppColors.primary;
  final buffer = StringBuffer();
  if (hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

String colorToHex(Color color) =>
    '#${color.value.toRadixString(16).substring(2)}';

/// Inline icon + color picker used by wallet/category forms.
class IconColorPicker extends StatelessWidget {
  final String? selectedIcon;
  final String? selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;

  const IconColorPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Biểu tượng', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kPickableIcons.map((icon) {
            final name = iconToName(icon);
            final isSelected = selectedIcon == name;
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onIconSelected(name),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: isSelected
                    ? colorFromHex(selectedColor).withOpacity(0.2)
                    : AppColors.background,
                child: Icon(icon,
                    color: isSelected ? colorFromHex(selectedColor) : AppColors.textSecondary),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppColors.pickerPalette.map((color) {
            final hex = colorToHex(color);
            final isSelected = selectedColor == hex;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onColorSelected(hex),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
