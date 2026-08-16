import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/debug/agent_log.dart';
import '../../../../core/widgets/gp_brand_logo.dart';
import '../../../../domain/entities/customer.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // #region agent log
    final sw = Stopwatch()..start();
    agentLog('customer_splash', 'bootstrap start', hypothesisId: 'B', data: {
      'delayMs': 400,
    });
    // #endregion
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // #region agent log
    agentLog('customer_splash', 'getSession start', hypothesisId: 'B', data: {
      'ms': sw.elapsedMilliseconds,
    });
    // #endregion
    final sessionResult =
        await ref.read(authRepositoryProvider).getSession();
    if (!mounted) return;

    AuthSession? session;
    var sessionFailed = false;
    sessionResult.when(
      success: (s) => session = s,
      failure: (_) => sessionFailed = true,
    );

    // #region agent log
    agentLog('customer_splash', 'getSession done', hypothesisId: 'B', data: {
      'ms': sw.elapsedMilliseconds,
      'failed': sessionFailed,
      'authed': session?.isAuthenticated == true,
      'hasSession': session != null,
    });
    // #endregion

    if (sessionFailed || session == null || !session!.isAuthenticated) {
      // #region agent log
      agentLog('customer_splash', 'nav login', hypothesisId: 'D', data: {
        'ms': sw.elapsedMilliseconds,
      });
      // #endregion
      context.go(RoutePaths.login);
      return;
    }

    ref.read(sessionGateProvider).markAuthenticated();

    final locResult =
        await ref.read(customerRepositoryProvider).isLocationGranted();
    if (!mounted) return;

    var granted = false;
    locResult.when(
      success: (g) => granted = g,
      failure: (_) => granted = false,
    );
    // #region agent log
    agentLog('customer_splash', 'nav next', hypothesisId: 'D', data: {
      'ms': sw.elapsedMilliseconds,
      'granted': granted,
      'route': granted ? 'home' : 'location',
    });
    // #endregion
    context.go(granted ? RoutePaths.home : RoutePaths.location);
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const GpBrandLogo(
                height: 220,
                variant: GpBrandLogoVariant.full,
              ),
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  final phase = (_dots.value * 3).floor() % 3;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      final active = i == phase;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 10 : 8,
                        height: active ? 10 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
