import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'language_switcher.dart';
import 'luxury_icon_button.dart';
import 'luxury_background.dart';

class AuthScaffold extends StatelessWidget {
  final String? imageUrl;
  final Widget child;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.child,
    this.imageUrl,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        imageUrl: imageUrl,
        child: SafeArea(
          child: Stack(
            children: [
              PositionedDirectional(
                top: 12,
                end: 16,
                child: const LanguageSwitcher(compact: true),
              ),
              if (showBack)
                PositionedDirectional(
                  top: 6,
                  start: 4,
                  child: LuxuryIconButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => context.pop()),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
