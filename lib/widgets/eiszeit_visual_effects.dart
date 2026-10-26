import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animierter Hintergrund mit schwebenden Eiskristallen & Schneeflocken ("Eiszeit"-Atmosphäre)
class AnimatedFrostBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;

  const AnimatedFrostBackground({
    super.key,
    required this.child,
    this.particleCount = 18,
  });

  @override
  State<AnimatedFrostBackground> createState() => _AnimatedFrostBackgroundState();
}

class _AnimatedFrostBackgroundState extends State<AnimatedFrostBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SnowParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(widget.particleCount, (_) {
      return _SnowParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 2.0 + rng.nextDouble() * 4.5,
        speed: 0.08 + rng.nextDouble() * 0.22,
        drift: (rng.nextDouble() - 0.5) * 0.15,
        alpha: 0.12 + rng.nextDouble() * 0.35,
        isDetailedCrystal: rng.nextBool(),
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SnowParticlePainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SnowParticle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double alpha;
  final bool isDetailedCrystal;

  const _SnowParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.alpha,
    required this.isDetailedCrystal,
  });
}

class _SnowParticlePainter extends CustomPainter {
  final List<_SnowParticle> particles;
  final double progress;

  const _SnowParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = ((p.y + progress * p.speed) % 1.0) * size.height;
      final dx =
          ((p.x + math.sin(progress * math.pi * 2 + p.y * 10) * p.drift) % 1.0) *
              size.width;
      final center = Offset(dx, dy);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.alpha)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (p.isDetailedCrystal && p.radius > 3.5) {
        // Zeichne 6-armigen Eiskristall
        final angleOffset = progress * math.pi * 2 * (p.speed * 2);
        for (int i = 0; i < 6; i++) {
          final angle = angleOffset + (i * math.pi / 3);
          final tip = Offset(
            center.dx + math.cos(angle) * p.radius,
            center.dy + math.sin(angle) * p.radius,
          );
          canvas.drawLine(center, tip, paint);
        }
      } else {
        final fillPaint = Paint()
          ..color = Colors.cyanAccent.withValues(alpha: p.alpha * 0.85)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, p.radius * 0.55, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnowParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Zeichnet glitzernde Eiszapfen an einer Kante für den "Eiszeit"-Look
class IcicleRow extends StatelessWidget {
  final double height;
  final Color color;

  const IcicleRow({
    super.key,
    this.height = 16,
    this.color = const Color(0xFFB3E5FC),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _IciclePainter(color: color),
      ),
    );
  }
}

class _IciclePainter extends CustomPainter {
  final Color color;

  const _IciclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0);
    const peaks = [
      0.45,
      0.85,
      0.35,
      0.95,
      0.50,
      0.75,
      0.30,
      0.90,
      0.40,
      0.80,
      0.55,
      1.0,
      0.45,
      0.70,
      0.35,
      0.88,
      0.50,
      0.65,
    ];
    final step = size.width / peaks.length;

    for (var i = 0; i < peaks.length; i++) {
      final startX = i * step;
      final midX = startX + step * 0.5;
      final endX = startX + step;
      final tipY = size.height * peaks[i];

      path.lineTo(midX, tipY);
      path.lineTo(endX, 0);
    }
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          color.withValues(alpha: 0.45),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IciclePainter oldDelegate) => false;
}

/// Runder Neon-Eis-Tacho / Gauge für das Siemens-Cockpit
class CircularFrostGauge extends StatelessWidget {
  final double progress;
  final String centerValue;
  final String bottomLabel;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const CircularFrostGauge({
    super.key,
    required this.progress,
    required this.centerValue,
    required this.bottomLabel,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(58, 58),
                    painter: _GaugeArcPainter(
                      progress: progress.clamp(0.0, 1.0),
                      color: color,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(height: 1),
                      Text(
                        centerValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bottomLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _GaugeArcPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
