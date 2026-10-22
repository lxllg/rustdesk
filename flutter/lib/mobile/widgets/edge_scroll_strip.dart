import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/input_model.dart';
import '../../models/model.dart';
import '../pages/lx_settings_page.dart';

/// Eigene Anpassung: Zonen am Bildschirmrand der Fernsteuerungsansicht.
///
/// Rechter Rand (immer, wenn «Scrollen am Rand» an ist):
/// - Mit einem Finger hoch/runter wischen = Mausrad
/// - Antippen = Linksklick (wird an den PC weitergegeben)
/// - Lange drücken = Rechtsklick
///
/// Mit «Ränder verschieben das Bild» ([edgePan]) gibt es links und rechts eine
/// Zone. Gedrückt halten verschiebt die Ansicht in diese Richtung, hoch/runter
/// wischen scrollt, Antippen klickt.
///
/// Die Zonen liegen über der normalen Gestenerkennung, damit sich Scrollen und
/// Maus-/Touch-Gesten nicht gegenseitig in die Quere kommen.
class EdgeScrollOverlay extends StatelessWidget {
  final Widget child;
  final FFI ffi;
  final bool enabled;
  final bool edgePan;

  const EdgeScrollOverlay({
    Key? key,
    required this.child,
    required this.ffi,
    required this.enabled,
    this.edgePan = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Die Struktur (LayoutBuilder > Stack > erstes Kind) bleibt immer gleich,
    // auch wenn die Zonen ausgeblendet werden. So wird die Ansicht darunter
    // (inkl. Eingabefeld der Bildschirmtastatur) nie neu aufgebaut.
    final width = LxPrefs.edgeScrollWidth;
    // Mit eingeblendeter virtueller Maus keine Randzonen (RustDesk unverändert).
    return AnimatedBuilder(
        animation: ffi.ffiModel.virtualMouseMode,
        child: child,
        builder: (context, child) {
          final on =
              enabled && !ffi.ffiModel.virtualMouseMode.showVirtualMouse;
          return _build(child!, width, on);
        });
  }

  Widget _build(Widget child, double width, bool enabled) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(child: child),
          if (enabled && edgePan)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: width,
              child: _EdgeScrollZone(
                ffi: ffi,
                offsetX: 0,
                side: -1,
                edgePan: true,
              ),
            ),
          if (enabled)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: width,
              child: _EdgeScrollZone(
                ffi: ffi,
                offsetX: constraints.maxWidth - width,
                side: 1,
                edgePan: edgePan,
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

  /// -1 = linker Rand, 1 = rechter Rand.
  final int side;

  /// Gedrückt halten verschiebt das Bild.
  final bool edgePan;

  const _EdgeScrollZone({
    required this.ffi,
    required this.offsetX,
    required this.side,
    required this.edgePan,
  });

  @override
  State<_EdgeScrollZone> createState() => _EdgeScrollZoneState();
}

class _EdgeScrollZoneState extends State<_EdgeScrollZone> {
  // Verschieben beim Halten: Wartezeit, damit Antippen ein Klick bleibt,
  // und Schrittweite pro Bild (~60 Bilder/s).
  static const _holdDelay = Duration(milliseconds: 220);
  static const _panStep = 14.0;

  double _accumulated = 0;
  double _step = 14;
  bool _invert = false;
  bool _active = false;
  bool _panned = false;
  Timer? _holdTimer;
  Timer? _panTimer;

  InputModel get _input => widget.ffi.inputModel;

  @override
  void dispose() {
    _stopPan();
    super.dispose();
  }

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

  void _onPointerDown(PointerDownEvent e) {
    _panned = false;
    if (!widget.edgePan) return;
    _stopPan();
    _holdTimer = Timer(_holdDelay, () {
      if (!mounted) return;
      _panned = true;
      setState(() => _active = true);
      _panTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (widget.ffi.canvasModel.locked) return;
        // Links halten zeigt mehr vom linken Teil: Bild wandert nach rechts.
        widget.ffi.canvasModel.panX(-widget.side * _panStep);
      });
    });
  }

  void _onPointerEnd() {
    if (!widget.edgePan) return;
    final wasPanning = _panTimer != null;
    _stopPan();
    if (wasPanning && mounted) setState(() => _active = false);
  }

  void _stopPan() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _panTimer?.cancel();
    _panTimer = null;
  }

  void _onDragStart(DragStartDetails d) {
    _stopPan();
    _panned = true;
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
    final alignRight = widget.side > 0;
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Nur Finger/Stift – eine echte Maus läuft über den normalen Weg.
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        onTapUp: (d) {
          if (_panned) return;
          _click(d.localPosition, MouseButtons.left);
        },
        // Mit Verschieben am Rand ist Halten fürs Verschieben reserviert.
        onLongPressStart: widget.edgePan
            ? null
            : (d) => _click(d.localPosition, MouseButtons.right),
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: (_) => _onDragEnd(),
        onVerticalDragCancel: _onDragEnd,
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: alignRight
                ? const EdgeInsets.only(right: 3)
                : const EdgeInsets.only(left: 3),
            width: _active ? 6 : 4,
            height: _active ? 120 : 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_active ? 0.6 : 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
