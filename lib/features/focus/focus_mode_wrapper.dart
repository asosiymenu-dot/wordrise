import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'focus_provider.dart';

class FocusModeWrapper extends StatefulWidget {
  final Widget child;

  const FocusModeWrapper({super.key, required this.child});

  @override
  State<FocusModeWrapper> createState() => _FocusModeWrapperState();
}

class _FocusModeWrapperState extends State<FocusModeWrapper> {
  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    // Start listening to the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FocusProvider>().addListener(_onFocusStateChanged);
    });
  }

  @override
  void dispose() {
    // If we can get provider here without context error, we should remove listener.
    // Usually it's fine for the root widget.
    super.dispose();
  }

  void _onFocusStateChanged() {
    final isActive = context.read<FocusProvider>().isActive;
    if (isActive && !_wasActive) {
      _wasActive = true;
      _enterKioskMode();
    } else if (!isActive && _wasActive) {
      _wasActive = false;
      _exitKioskMode();
    }
  }

  Future<void> _enterKioskMode() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    if (!kIsWeb) {
      final started = await startKioskMode();
      if (!started) {
        debugPrint("Failed to start kiosk mode.");
      }
    }
  }

  Future<void> _exitKioskMode() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    if (!kIsWeb) {
      await stopKioskMode();
    }
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, provider, child) {
        if (!provider.isActive) {
          return widget.child;
        }

        final isGoalReached = provider.isGoalReached;

        return Stack(
          children: [
            // The main app
            widget.child,

            // The persistent overlay banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isGoalReached ? Colors.green.shade800 : Colors.deepPurple.shade900,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isGoalReached ? Icons.lock_open : Icons.lock_clock,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DIQQAT REJIMI',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (provider.goalType == FocusGoalType.time)
                                Text(
                                  _formatTime(provider.secondsRemaining),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Text(
                                  '${provider.wordsLearned} / ${provider.targetWords} so\'z',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isGoalReached)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade900,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () {
                              provider.stopFocus();
                            },
                            child: const Text('Ochish'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
