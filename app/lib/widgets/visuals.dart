import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A 3D illustration from assets/3d (Fluent Emoji).
class Img3D extends StatelessWidget {
  const Img3D(this.name, {super.key, this.size = 48});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    img3d(name),
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
  );
}

/// 3D illustration sitting on a soft tinted circle (category badges, option tiles).
class Img3DBadge extends StatelessWidget {
  const Img3DBadge(this.name, {super.key, required this.color, this.size = 56});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Img3D(name, size: size * 0.72),
  );
}

/// The friendly doctor guide with a speech bubble. Used to ask questions and encourage.
class DoctorSays extends StatelessWidget {
  const DoctorSays({
    super.key,
    required this.text,
    this.sub,
    this.size = 92,
    this.onDark = false,
  });
  final String text;
  final String? sub;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE6F6F1), Color(0xFFCBEBE2)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          padding: EdgeInsets.all(size * 0.08),
          child: const Img3D('doctor'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: size * 0.18),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(22),
                topEnd: Radius.circular(22),
                bottomEnd: Radius.circular(22),
                bottomStart: Radius.circular(6),
              ).resolve(Directionality.of(context)),
              boxShadow: kShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.35,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated "water filling a glass ball" progress indicator.
class WaterBall extends StatefulWidget {
  const WaterBall({
    super.key,
    required this.value,
    required this.label,
    this.sub,
    this.size = 150,
    this.color = AppColors.water,
  });
  final double value; // 0..1
  final String label;
  final String? sub;
  final double size;
  final Color color;

  @override
  State<WaterBall> createState() => _WaterBallState();
}

class _WaterBallState extends State<WaterBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.value >= 1;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: widget.color.withValues(alpha: 0.35),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: full ? 0.45 : 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, level, _) => AnimatedBuilder(
            animation: _wave,
            builder: (context, _) => CustomPaint(
              painter: _WavePainter(
                level: level,
                phase: _wave.value * 2 * math.pi,
                color: widget.color,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.size * 0.22,
                          fontWeight: FontWeight.w900,
                          color: level > 0.5 ? Colors.white : AppColors.ink,
                          shadows: level > 0.5
                              ? const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    if (widget.sub != null)
                      Text(
                        widget.sub!,
                        style: TextStyle(
                          fontSize: widget.size * 0.1,
                          fontWeight: FontWeight.w800,
                          color: level > 0.3 ? Colors.white : AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.level, required this.phase, required this.color});
  final double level;
  final double phase;
  final Color color;

  Path _wave(Size size, double amp, double shift) {
    final y0 = size.height * (1 - level);
    final path = Path()..moveTo(0, y0);
    for (double x = 0; x <= size.width; x += 2) {
      path.lineTo(
        x,
        y0 + math.sin((x / size.width * 2 * math.pi) + phase + shift) * amp,
      );
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    final amp = size.height * 0.035;
    canvas.drawPath(
      _wave(size, amp, math.pi),
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      _wave(size, amp, 0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.85),
            Color.lerp(color, Colors.black, 0.25)!,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.level != level || old.phase != phase || old.color != color;
}

/// Glowing ring for dark dashboard cards.
class GlowRing extends StatelessWidget {
  const GlowRing({
    super.key,
    required this.value,
    required this.label,
    this.sub,
    this.size = 120,
    this.color = AppColors.glow,
  });
  final double value;
  final String label;
  final String? sub;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(
                      fontSize: size * 0.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark gradient "dashboard" card with a soft glow, for charts and key numbers.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      gradient: kDashboardGradient,
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: AppColors.glow.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.35),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}
