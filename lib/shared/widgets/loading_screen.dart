import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/recipy_colors.dart';

/// Branded loading screen shown at app start.
///
/// Timeline (total ~3 s):
///   0 ms   — logo fades in over 600 ms
///   2500 ms — logo fades out over 500 ms
///   3000 ms — navigate to /recipes (GoRouter applies its own fade transition)
///
/// The database warms up in the background while the logo is on screen so
/// the recipe list is ready the moment the transition completes.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Drives both the fade-in (0→1 over first 600 ms) and the fade-out
  /// (1→0 over final 500 ms) using a single TweenSequence so the logo
  /// breathes naturally rather than snapping.
  late final Animation<double> _opacity;

  // Total duration of the loading screen stay.
  static const _totalDuration = Duration(milliseconds: 4100);
  // How long the fade-in takes.
  static const _fadeInMs = 600;
  // How long the fade-out takes (must be < _totalDuration).
  static const _fadeOutMs = 500;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    // The logo is fully opaque between the end of fade-in and the start of
    // fade-out.  Express each phase as a weight proportional to its duration.
    final total = _totalDuration.inMilliseconds;
    final holdMs = total - _fadeInMs - _fadeOutMs;

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: _fadeInMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: holdMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: _fadeOutMs.toDouble(),
      ),
    ]).animate(_controller);

    // Run the whole sequence once, then navigate.
    _controller.forward().whenComplete(() {
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
          opacity: _opacity,
          child: Image.asset(
            'assets/images/splash_logo.png',
            width: 330,
          ),
        ),
      ),
    );
  }
}
