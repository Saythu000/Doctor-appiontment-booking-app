import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/brand.dart';

/// First screen for a signed-out user: three short slides explaining what the
/// app does, then one way forward (sign in or create an account).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> chips;
  final bool showPulse;

  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.chips,
    this.showPulse = false,
  });
}

const _slides = [
  _Slide(
    icon: Icons.video_camera_front_rounded,
    title: 'See a doctor, without the wait',
    body: 'Book a video or in-person visit with a verified doctor, at a time that suits you.',
    chips: [(Icons.verified_rounded, 'Verified doctors'), (Icons.event_available_rounded, 'Pick your time')],
  ),
  _Slide(
    icon: Icons.record_voice_over_rounded,
    title: 'Tell us how you feel, before you visit',
    body: 'Answer a few questions by chat or voice, so your doctor can see a clear summary.',
    chips: [(Icons.mic_rounded, 'Voice or chat'), (Icons.description_rounded, 'Summary for your doctor')],
  ),
  _Slide(
    icon: Icons.favorite_rounded,
    title: 'Your health, followed every day',
    body: 'Bring in heart rate, steps and sleep from your watch through Health Connect.',
    chips: [(Icons.watch_rounded, 'Health Connect'), (Icons.notifications_active_rounded, 'Alerts you choose')],
    showPulse: true,
  ),
];

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  int _index = 0;

  /// Drives the slow "floating" of the illustration chips.
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  bool get _isLast => _index == _slides.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _float.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      context.push(AppRoutes.login);
      return;
    }
    _pages.nextPage(
      duration: AppMotion.reduced(context) ? const Duration(milliseconds: 1) : AppMotion.slow,
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header: brand on the left, Skip on the right.
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
                child: Row(
                  children: [
                    const Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandHeader(markSize: 32))),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: AppMotion.fast,
                      child: TextButton(
                        onPressed: _isLast ? null : () => context.push(AppRoutes.login),
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(
                    slide: _slides[i],
                    pages: _pages,
                    index: i,
                    float: _float,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
                child: Column(
                  children: [
                    _Dots(count: _slides.length, index: _index),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _isLast ? 'Get started' : 'Next',
                      icon: _isLast ? null : Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedOpacity(
                      opacity: _isLast ? 1 : 0,
                      duration: AppMotion.medium,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: colors.textMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              "You'll sign in or create your account on DrGodly's secure page.",
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final PageController pages;
  final int index;
  final Animation<double> float;

  const _SlideView({required this.slide, required this.pages, required this.index, required this.float});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pages,
      builder: (context, child) {
        // How far this slide is from the centre (0 = fully in view).
        final page = pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0 : 0.0;
        final delta = (index - page).clamp(-1.0, 1.0);
        return Opacity(
          opacity: 1 - delta.abs() * 0.6,
          child: Transform.translate(offset: Offset(delta * 40, 0), child: child),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Scales down on narrow phones instead of overflowing.
                FittedBox(fit: BoxFit.scaleDown, child: _Illustration(slide: slide, float: float)),
                const SizedBox(height: AppSpacing.xxl),
                Semantics(
                  header: true,
                  child: Text(slide.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge!.copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft concentric circles with the slide's icon, and two labels that float
/// slowly around it. Decorative only (hidden from screen readers).
class _Illustration extends StatelessWidget {
  final _Slide slide;
  final Animation<double> float;

  const _Illustration({required this.slide, required this.float});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = 230.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: size + 60,
        height: size,
        child: AnimatedBuilder(
          animation: float,
          builder: (context, _) {
            final t = float.value * 2 * math.pi;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryContainer.withValues(alpha: 0.6)),
                ),
                Container(
                  width: size * 0.68,
                  height: size * 0.68,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primaryContainer),
                ),
                Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    boxShadow: [
                      BoxShadow(color: colors.primary.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Icon(slide.icon, size: 44, color: slide.showPulse ? colors.vitalHeart : colors.primary),
                ),
                if (slide.showPulse)
                  Positioned(
                    bottom: size * 0.16,
                    child: PulseLine(width: size * 0.6, height: 28, color: colors.vitalHeart, strokeWidth: 2),
                  ),
                Positioned(
                  top: size * 0.08 + math.sin(t) * 5,
                  right: 0,
                  child: _Chip(icon: slide.chips[0].$1, label: slide.chips[0].$2),
                ),
                Positioned(
                  bottom: size * 0.04 + math.sin(t + math.pi) * 5,
                  left: 0,
                  child: _Chip(icon: slide.chips[1].$1, label: slide.chips[1].$2),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(label, style: context.text.labelMedium!.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? colors.primary : colors.borderStrong,
                borderRadius: AppRadius.smAll,
              ),
            ),
        ],
      ),
    );
  }
}
