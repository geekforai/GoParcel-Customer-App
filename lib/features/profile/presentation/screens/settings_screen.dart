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
    final s = ref.watch(l10nProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(s.language),
            subtitle: Text(locale == 'hi' ? s.hindiLabel : s.english),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final next = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(s.chooseLanguage),
                      ),
                      ListTile(
                        title: Text(s.english),
                        trailing: locale == 'en' ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.pop(ctx, 'en'),
                      ),
                      ListTile(
                        title: Text(s.hindiLabel),
                        trailing: locale == 'hi' ? const Icon(Icons.check) : null,
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
            title: Text(s.privacy),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                s.privacy,
                s.t(
                  'GoParcel collects only what is needed to complete deliveries. Names and phone numbers of the other party are masked in-app.',
                  'गोपरसल केवल डिलीवरी के लिए ज़रूरी जानकारी लेता है। दूसरे पक्ष का नाम और फ़ोन ऐप में छिपा रहता है।',
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(s.terms),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                s.terms,
                s.t(
                  'By using GoParcel you agree to city-limited deliveries and fare estimates based on distance.',
                  'गोपरसल इस्तेमाल करके आप शहर-सीमित डिलीवरी और दूरी के अनुसार किराए से सहमत हैं।',
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(s.faqs),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                s.faqs,
                s.t(
                  'Login uses phone OTP 1234 while SMS is not configured. Search runs for 2 minutes.',
                  'SMS बंद होने तक लॉगिन OTP 1234 है। ड्राइवर सर्च 2 मिनट चलती है।',
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(s.refund),
            onTap: () => context.push(
              RoutePaths.legal,
              extra: (
                s.refund,
                s.t(
                  'Cancelled trips before pickup are not charged.',
                  'पिकअप से पहले रद्द ट्रिप पर चार्ज नहीं लगता।',
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(s.help),
            onTap: () => context.push(RoutePaths.support),
          ),
          ListTile(
            title: Text(s.about),
            onTap: () => context.push(RoutePaths.about),
          ),
        ],
      ),
    );
  }
}
