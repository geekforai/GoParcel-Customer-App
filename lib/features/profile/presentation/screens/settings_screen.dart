import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/locale/app_locale.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr(ref, 'Settings', 'सेटिंग्स')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(tr(ref, 'Language', 'भाषा')),
            subtitle: Text(locale == 'hi' ? 'हिन्दी' : 'English'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final next = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('English'),
                        onTap: () => Navigator.pop(ctx, 'en'),
                      ),
                      ListTile(
                        title: const Text('हिन्दी'),
                        onTap: () => Navigator.pop(ctx, 'hi'),
                      ),
                    ],
                  ),
                ),
              );
              if (next != null) {
                await ref.read(appLocaleProvider.notifier).setLocale(next);
              }
            },
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                'Privacy Policy',
                'GoParcel collects only what is needed to complete deliveries. Names and phone numbers of the other party are masked in-app. Maps, SMS, and payments stay mocked until production keys are configured.',
              ),
            ),
          ),
          ListTile(
            title: const Text('Terms & Conditions'),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                'Terms & Conditions',
                'By using GoParcel you agree to city-limited deliveries, fare estimates based on distance, and cancellation with a reason before pickup.',
              ),
            ),
          ),
          ListTile(
            title: const Text('FAQs'),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                'FAQs',
                'Login uses phone OTP 1234 while SMS is not configured. Search runs for 2 minutes. Pickup/drop OTPs appear after a driver is assigned.',
              ),
            ),
          ),
          ListTile(
            title: const Text('Refund Policy'),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                'Refund Policy',
                'Cancelled trips before pickup are not charged. Payment gateway remains in sandbox until credentials are provided.',
              ),
            ),
          ),
          ListTile(
            title: const Text('Help / Contact'),
            onTap: () => context.push(RoutePaths.support),
          ),
          ListTile(
            title: const Text('About'),
            onTap: () => context.push(RoutePaths.about),
          ),
        ],
      ),
    );
  }
}
