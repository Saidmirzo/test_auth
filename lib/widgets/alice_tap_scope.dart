import 'package:flutter/material.dart';
import 'package:test_auth/services/alice_inspector.dart';

class AliceTapScope extends StatefulWidget {
  const AliceTapScope({super.key, required this.child});

  final Widget child;

  @override
  State<AliceTapScope> createState() => _AliceTapScopeState();
}

class _AliceTapScopeState extends State<AliceTapScope> {
  final _pointers = <int>{};
  Offset _chip = const Offset(16, 120);

  @override
  Widget build(BuildContext context) {
    if (!AliceInspector.isEnabled) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointers.add(event.pointer);
        if (_pointers.length >= 2) {
          AliceInspector.show();
        }
      },
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: (event) => _pointers.remove(event.pointer),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: _chip.dx,
            top: _chip.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() => _chip += details.delta);
              },
              onTap: AliceInspector.show,
              child: Material(
                color: const Color(0xE02196F3),
                borderRadius: BorderRadius.circular(20),
                elevation: 4,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Alice',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
