import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Push notifications',
                style: AppTypography.textTheme.titleMedium),
            value: true,
            activeThumbColor: AppColors.primary,
            onChanged: (_) {},
          ),
          SwitchListTile(
            title: Text('SMS updates',
                style: AppTypography.textTheme.titleMedium),
            value: false,
            activeThumbColor: AppColors.primary,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}
