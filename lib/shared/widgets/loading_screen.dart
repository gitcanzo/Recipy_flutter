import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/recipy_colors.dart';

/// A 2-second branded loading screen shown at app start.
///
/// The OS splash screen disappears quickly (and the logo is constrained to a
/// small circle on Android 12+).  This screen fills that gap by showing the
/// full splash logo at a comfortable size before handing off to the recipe
/// list.  It does not perform any async work — the database warms up in the
/// background while the logo is on screen.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fade-in animation for the logo so the transition from the OS splash
  /// feels smooth rather than abrupt.
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Start the fade-in immediately.
    _controller.forward();

    // Navigate to the recipe list after 2 seconds.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go(AppRoutes.recipes);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RecipyColors.paper,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Image.asset(
            'assets/images/splash_logo.png',
            width: 330,
          ),
        ),
      ),
    );
  }
}
