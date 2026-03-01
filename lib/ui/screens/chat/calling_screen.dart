import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/misc/youtube_player.dart';
import 'package:wurp/ui/router.dart';
import 'package:wurp/ui/widgets/camera/web_camera.dart';

class CallingApp extends StatelessWidget {
  final String name;
  final String? profileImageUrl;

  const CallingApp({super.key, required this.name, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return CallingScreen(
      joinFuture: Future.delayed(const Duration(milliseconds: 2500)),
      name: name,
      profileImageUrl: profileImageUrl,
    );
  }
}

class CallingScreen extends StatefulWidget {
  final Future<void> joinFuture;
  final String name;
  final String? profileImageUrl;

  const CallingScreen({super.key, required this.joinFuture, required this.name, this.profileImageUrl});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  late AnimationController _videoAppearController;
  bool _joined = false;
  bool _cameraConnected = false;
  final GlobalObjectKey<WebCameraState> _cameraKey = GlobalObjectKey("CallCamera");

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 12.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _videoAppearController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _videoAppearController.dispose();
    super.dispose();
  }

  Widget buildActionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required VoidCallback onTap,
    double size = 68,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Container(
                    width: size + _pulse.value,
                    height: size + _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg.withValues(alpha: 0.12),
                    ),
                  );
                },
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [bg.withValues(alpha: 0.95), bg.withValues(alpha: 0.78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    const redAccent = Colors.redAccent;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.80),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: widget.profileImageUrl == null
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [primary, secondary]),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4))],
                          )
                        : null,
                    child: widget.profileImageUrl == null
                        ? Center(child: Text(widget.name.substring(0, 2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))
                        : Avatar(imageUrl: widget.profileImageUrl, name: widget.name, colorScheme: theme.colorScheme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.more_vert, color: Colors.white54),
                    ],
                  )
                ],
              ),
            ),
            Positioned(
              top: media.size.height * 0.14,
              left: 16,
              right: 16,
              height: media.size.height * 0.56,
              child: AnimatedBuilder(
                animation: _videoAppearController,
                builder: (context, child) {
                  if (!_joined || !_cameraConnected) {
                    return Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white10,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation(primary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Establishing Connection...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    );
                  }

                  final t = Curves.easeOut.transform(_videoAppearController.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * t,
                      child: child,
                    ),
                  );
                },
                child: Hero(
                  tag: 'video_placeholder',
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.03), Colors.white.withValues(alpha: 0.01)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 12))],
                      ),
                      child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: SizedBox(
                              width: 1024,
                              height: 1024,
                              child: ClipRect(
                                  child: Transform.scale(
                                      scale: 2,
                                      child: const YouTubePlayerWidget(
                                          videoUrl: "https://www.youtube.com/watch?v=-Dh6-F4sVmI", showControls: false, autoPlay: true)))))),
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      buildActionButton(
                        icon: Icons.mic_off,
                        label: 'Mute',
                        bg: theme.colorScheme.primary,
                        onTap: () {},
                        size: 60,
                      ),
                      GestureDetector(
                        onTap: () {
                          routerConfig.pop();
                        },
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, child) {
                                    return Container(
                                      width: 84 + _pulse.value,
                                      height: 84 + _pulse.value,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: redAccent.withValues(alpha: 0.12)),
                                    );
                                  },
                                ),
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [redAccent, redAccent.withValues(alpha: 0.9)]),
                                    boxShadow: [BoxShadow(color: redAccent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10))],
                                  ),
                                  child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Hang Up', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      buildActionButton(
                        icon: Icons.cameraswitch,
                        label: 'Flip Camera',
                        bg: theme.colorScheme.secondary,
                        onTap: () {
                          _cameraKey.currentState?.switchCamera();
                        },
                        size: 60,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 28,
              top: media.size.height * 0.14 + 12,
              child: Container(
                  width: 96,
                  height: 120,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14), color: Colors.black.withValues(alpha: 0.5), border: Border.all(color: Colors.white12)),
                  child: ClipRRect(
                    borderRadius: const BorderRadiusGeometry.all(Radius.circular(5)),
                    child: WebCamera(
                        preferFrontCamera: true,
                        key: _cameraKey,
                        onCameraConnected: () {
                          setState(() {
                            _cameraConnected = true;
                            _videoAppearController.animateTo(0.1);
                            widget.joinFuture.then((_) {
                              if (mounted) {
                                setState(() => _joined = true);
                                _videoAppearController.forward();
                              }
                            }).catchError((_) {});
                          });
                        }),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
