// ignore_for_file: control_flow_in_finally, slash_for_doc_comments

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:una_social_app/painters/star_painter.dart';

const Color primaryBlue = Color(0xFF0028FF);
const Color primaryGold = Color(0xFFFFD700);
const Color tertiaryColor = Colors.white;

class SplashScreen extends StatefulWidget {
  final int durationInSeconds;
  const SplashScreen({super.key, this.durationInSeconds = 7});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final GlobalKey _starPaintKey = GlobalKey();
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late Animation<double> _starRotationAnimation;
  late Animation<double> _starSizeAnimation;
  late Animation<Color?> _starColorAnimation;
  late Animation<Color?> _backgroundColorAnimation;
  late List<Animation<double>> _tipTextOpacityAnimations;
  late List<Animation<double>> _tipTextScaleAnimations;
  late Animation<double> _centerTextOpacityAnimation;
  late Animation<double> _centerTextScaleAnimation;
  late Animation<double> _centerTextRotationAnimation;
  late Animation<double> _pulseAnimation;
  double _finalStarRadius = 20.0;
  bool _isLayoutCalculated = false;
  bool _isTapEnabled = false;
  Color _currentStarColor = primaryGold;
  Color _currentBackgroundColor = primaryBlue;
  final List<String> _tipTexts = ["Play", "Call", "Watch", "Chat", "Browse"];
  final List<double> _tipAngles = List.generate(5, (i) => -pi / 2 + i * (2 * pi / 5));
  final List<Offset> _tipTextAdjustments = const [
    Offset(0, 8),
    Offset(-16, 0),
    Offset(-24, -24),
    Offset(18, -24),
    Offset(24, 0),
  ];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: Duration(seconds: widget.durationInSeconds - 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Animations setup...
    _starRotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeInOut)),
    );
    _starSizeAnimation = Tween<double>(begin: 20.0, end: 20.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeInOut)),
    );
    _tipTextOpacityAnimations = List.generate(
      5,
      (i) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.6, curve: Curves.easeIn)),
      ),
    );
    _tipTextScaleAnimations = List.generate(
      5,
      (i) => Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.6, curve: Curves.elasticOut)),
      ),
    );
    _centerTextOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.6, 0.75, curve: Curves.easeIn)),
    );
    _centerTextScaleAnimation = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.6, 0.75, curve: Curves.elasticOut)),
    );
    _centerTextRotationAnimation = Tween<double>(begin: -pi / 4, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.6, 0.75, curve: Curves.easeInOut)),
    );
    _starColorAnimation = ColorTween(begin: primaryGold, end: primaryBlue).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.75, 0.85)),
    );
    _backgroundColorAnimation = ColorTween(begin: primaryBlue, end: primaryGold).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.75, 0.85)),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.addListener(() {
      if (_mainController.value >= 0.75 && _mainController.value <= 0.85 && mounted) {
        setState(() {
          _currentStarColor = _starColorAnimation.value ?? primaryBlue;
          _currentBackgroundColor = _backgroundColorAnimation.value ?? primaryGold;
        });
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startPulsing();
      }
    });
  }

  Future<void> _startPulsing() async {
    if (!mounted) return;
    try {
      await _pulseController.repeat(reverse: true).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      if (mounted) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    } finally {
      if (!mounted) return;
      setState(() => _isTapEnabled = true);
      // Usa GoRouter per la navigazione evitando errori con Navigator
      GoRouter.of(context).go('/login');
    }
  }

  void _handleTap() {
    if (!_isTapEnabled || !mounted) return;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

/**
  Path _createStarPath(Size size, double radius, double rotation) {
    final path = Path();
    const points = 5;
    final outer = radius;
    final inner = radius * 0.4;
    final offset = -pi / 2 + rotation;
    const step = 2 * pi / points;
    const half = step / 2;
    final center = Offset(size.width / 2, size.height / 2);
    path.moveTo(center.dx + outer * cos(offset), center.dy + outer * sin(offset));
    for (var i = 0; i < points; i++) {
      final a1 = offset + half + i * step;
      path.lineTo(center.dx + inner * cos(a1), center.dy + inner * sin(a1));
      final a2 = offset + (i + 1) * step;
      path.lineTo(center.dx + outer * cos(a2), center.dy + outer * sin(a2));
    }
    path.close();
    return path;
  }
 */

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = min(constraints.maxWidth, constraints.maxHeight) * 0.7;
        final radius = maxSize / 2;
        if (!_isLayoutCalculated && radius > 20 && mounted) {
          _finalStarRadius = radius;
          _starSizeAnimation = Tween<double>(begin: 20, end: radius).animate(
            CurvedAnimation(parent: _mainController, curve: const Interval(0, 0.4, curve: Curves.easeInOut)),
          );
          _isLayoutCalculated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _mainController.forward());
        }
        if (!_isLayoutCalculated) return const Scaffold(backgroundColor: primaryBlue);

        return Scaffold(
          backgroundColor: _currentBackgroundColor,
          body: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_mainController, _pulseController]),
              builder: (context, child) {
                double centerScale = _centerTextScaleAnimation.value;
                if (_mainController.isCompleted) centerScale *= _pulseAnimation.value;
                final double maxTipFont = max(8.0, _finalStarRadius * 0.12);
                final double maxCenterFont = max(14.0, _finalStarRadius * 0.25);
                return GestureDetector(
                  onTap: _handleTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        key: _starPaintKey,
                        size: Size(_starSizeAnimation.value * 2, _starSizeAnimation.value * 2),
                        painter: StarPainter(
                          radius: _starSizeAnimation.value,
                          rotation: _starRotationAnimation.value,
                          color: _currentStarColor,
                        ),
                      ),
                      ...List.generate(_tipTexts.length, (i) {
                        final angle = _tipAngles[i];
                        final dx = _finalStarRadius * 0.65 * cos(angle) + _tipTextAdjustments[i].dx;
                        final dy = _finalStarRadius * 0.65 * sin(angle) + _tipTextAdjustments[i].dy;
                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Opacity(
                            opacity: _tipTextOpacityAnimations[i].value,
                            child: Transform.scale(
                              scale: _tipTextScaleAnimations[i].value,
                              child: Text(
                                _tipTexts[i],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  color: tertiaryColor,
                                  fontSize: maxTipFont,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Opacity(
                        opacity: _centerTextOpacityAnimation.value,
                        child: Transform.rotate(
                          angle: _centerTextRotationAnimation.value,
                          child: Transform.scale(
                            scale: centerScale,
                            child: Text(
                              "UNA",
                              style: GoogleFonts.pacifico(
                                color: tertiaryColor,
                                fontSize: maxCenterFont,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
