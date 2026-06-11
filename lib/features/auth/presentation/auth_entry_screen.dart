import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/onboarding/onboarding_controller.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/hallaq_mascot.dart';
import '../../../core/widgets/luxury_background.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

class AuthEntryScreen extends ConsumerWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seenValue = ref.watch(onboardingSeenFutureProvider);
    return AsyncValueWidget<bool>(
      value: seenValue,
      data: (seen) => seen ? const WelcomeScreen() : const OnboardingScreen(),
      loading: const Scaffold(
        body: LuxuryBackground(
          child: Center(
            child: HallaqMascot(size: 120),
          ),
        ),
      ),
    );
  }
}
