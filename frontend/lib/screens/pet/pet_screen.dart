import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/pet.dart';
import '../../providers/pet_streak_provider.dart';
import '../../widgets/loading_view.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetStreakProvider>();
    final pet = provider.pet;
    final streak = provider.streak;

    return Scaffold(
      appBar: AppBar(title: const Text('Thú cưng của bạn')),
      body: pet == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      _PetAvatar(shape: pet.shape),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showRenameDialog(context, pet.petName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pet.petName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Cấp độ ${pet.level}', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kinh nghiệm', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text('${pet.experiencePoints % pet.xpForNextLevel} / ${pet.xpForNextLevel} XP'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pet.levelProgress,
                            minHeight: 10,
                            backgroundColor: AppColors.divider,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ghi lại giao dịch và tiết kiệm mỗi ngày để nhận kinh nghiệm cho thú cưng!',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chuỗi tiết kiệm: ${streak?.currentStreakDays ?? 0} ngày', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('Kỷ lục: ${streak?.longestStreak ?? 0} ngày', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên thú cưng'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<PetStreakProvider>().renamePet(newName);
    }
  }
}

class _PetAvatar extends StatelessWidget {
  final PetShape shape;
  const _PetAvatar({required this.shape});

  @override
  Widget build(BuildContext context) {
    final size = switch (shape) {
      PetShape.small => 90.0,
      PetShape.medium => 120.0,
      PetShape.large => 150.0,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, size: size * 0.5, color: AppColors.secondary),
    );
  }
}
