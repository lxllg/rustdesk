import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/input_model.dart';
import '../../models/model.dart';
import '../pages/lx_settings_page.dart';

/// Eigene Anpassung: Scroll-Zone am rechten Rand der Fernsteuerungsansicht.
///
/// - Mit einem Finger hoch/runter wischen = Mausrad
/// - Antippen = Linksklick (wird an den PC weitergegeben)
/// - Lange drücken = Rechtsklick
///
/// Die Zone liegt über der normalen Gestenerkennung, damit sich Scrollen und
/// Maus-/Touch-Gesten nicht gegenseitig in die Quere kommen.
class EdgeScrollOverlay extends StatelessWidget {
  final Widget child;
  final FFI ffi;
  final bool enabled;

  const EdgeScrollOverlay({
    Key? key,
    required this.child,
    required this.ffi,
    required this.enabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Die Struktur (LayoutBuilder > Stack > erstes Kind) bleibt immer gleich,
    // auch wenn die Zone ausgeblendet wird. So wird die Ansicht darunter
    // (inkl. Eingabefeld der Bildschirmtastatur) nie neu aufgebaut.
    final width = enabled ? LxPrefs.edgeScrollWidth : 0.0;
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(child: child),
          if (enabled)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              child: _EdgeScrollZone(
                ffi: ffi,
                offsetX: constraints.maxWidth - width,
              ),
            ),
        ],
      );
    });
  }
}

class _EdgeScrollZone extends StatefulWidget {
  final FFI ffi;

  /// Linker Rand der Zone innerhalb der Fernsteuerungsansicht,
  /// damit Klicks an der richtigen Stelle ankommen.
  final double offsetX;

  const _EdgeScrollZone({required this.ffi, required this.offsetX});

  @override
  State<_EdgeScrollZone> createState() => _EdgeScrollZoneState();
}

class _EdgeScrollZoneState extends State<_EdgeScrollZone> {
  double _accumulated = 0;
  double _step = 14;
  bool _invert = false;
  bool _active = false;

  InputModel get _input => widget.ffi.inputModel;

  Future<void> _click(Offset local, MouseButtons button) async {
    final ffi = widget.ffi;
    if (ffi.ffiModel.touchMode) {
      // Touch-Modus: Mauszeiger an die getippte Stelle setzen, dann klicken.
      final moved =
          await ffi.cursorModel.move(widget.offsetX + local.dx, local.dy);
      if (!moved) return;
    }
    // Maus-Modus: Klick an der aktuellen Zeigerposition (wie sonst auch).
    await _input.tap(button);
  }

  void _onDragStart(DragStartDetails d) {
    _accumulated = 0;
    _step = LxPrefs.edgeScrollStepPx;
    _invert = LxPrefs.edgeScrollInvert;
    setState(() => _active = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _accumulated += d.delta.dy;
    while (_accumulated.abs() >= _step) {
      final dir = _accumulated > 0 ? 1 : -1;
      // Gleiche Richtung wie das Scrollen mit drei Fingern in RustDesk.
      _input.scroll(_invert ? -dir : dir);
      _accumulated -= dir * _step;
    }
  }

  void _onDragEnd() {
    _accumulated = 0;
    if (mounted) setState(() => _active = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Nur Finger/Stift – eine echte Maus läuft über den normalen Weg.
      supportedDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      },
      onTapUp: (d) => _click(d.localPosition, MouseButtons.left),
      onLongPressStart: (d) => _click(d.localPosition, MouseButtons.right),
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: (_) => _onDragEnd(),
      onVerticalDragCancel: _onDragEnd,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 3),
          width: _active ? 6 : 4,
          height: _active ? 120 : 72,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_active ? 0.6 : 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
