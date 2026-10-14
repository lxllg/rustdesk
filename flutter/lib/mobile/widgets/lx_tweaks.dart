import 'dart:ui';

import '../../common.dart';
import '../../models/input_model.dart';
import '../../models/model.dart';
import '../pages/lx_settings_page.dart';

/// Eigene Anpassung: frei zuordenbare Gesten im Touch-Modus.
class LxTouch {
  /// Führt die gewählte Aktion für [gesture] aus.
  /// Gibt false zurück, wenn die Standard-Aktion von RustDesk gewählt ist –
  /// dann läuft der Original-Code unverändert weiter.
  static Future<bool> handle(FFI ffi, String gesture, Offset localPos) async {
    if (!isMobile || !ffi.ffiModel.touchMode) return false;
    final action = LxPrefs.touchAction(gesture);
    if (action == LxPrefs.gestureRustdesk[gesture]) return false;
    if (action == LxPrefs.actionNone) return true;
    final moved = await ffi.cursorModel.move(localPos.dx, localPos.dy);
    if (!moved) return true;
    final input = ffi.inputModel;
    switch (action) {
      case LxPrefs.actionLeft:
        await input.tap(MouseButtons.left);
        break;
      case LxPrefs.actionRight:
        await input.tap(MouseButtons.right);
        break;
      case LxPrefs.actionMiddle:
        await input.tap(MouseButtons.wheel);
        break;
      case LxPrefs.actionDouble:
        await input.tap(MouseButtons.left);
        await input.tap(MouseButtons.left);
        break;
      case LxPrefs.actionDrag:
        // Loslassen schickt «Maustaste hoch» (onLongPressUp im Original-Code).
        await input.tapDown(MouseButtons.left);
        break;
      case LxPrefs.actionMove:
      default:
        break;
    }
    return true;
  }

  /// Bei «Lange drücken = Mauszeiger bewegen» folgt der Zeiger dem Finger.
  static bool followsFingerOnLongPress(FFI ffi) {
    if (!isMobile || !ffi.ffiModel.touchMode) return false;
    final a = LxPrefs.touchAction(LxPrefs.gestureLongPress);
    return a == LxPrefs.actionMove || a == LxPrefs.actionDrag;
  }

  /// Wischen mit 1 Finger verschiebt das Bild statt die Maus zu ziehen.
  static bool panMovesCanvas(FFI ffi) =>
      isMobile &&
      ffi.ffiModel.touchMode &&
      LxPrefs.oneFingerPan == LxPrefs.panCanvas;

  static void panCanvas(FFI ffi, Offset delta) {
    if (ffi.canvasModel.locked) return;
    final d = LxPrefs.panInvert ? -delta : delta;
    ffi.canvasModel.panX(d.dx);
    ffi.canvasModel.panY(d.dy);
  }
}

/// Eigene Anpassung: Zoom und Verschieben auf das PC-Bild begrenzen.
class LxView {
  static bool get _on => isMobile && LxPrefs.limitZoom;

  /// Tastatur verdeckt nur den unteren Teil, das Bild bleibt stehen.
  static bool get keyboardOverlay => isMobile && LxPrefs.keyboardOverlay;

  /// Kleinster Zoom = PC-Bild füllt die Breite der Ansicht.
  static double? minScale(double viewWidth, int contentWidth) {
    if (!_on || viewWidth <= 0 || contentWidth <= 0) return null;
    return viewWidth / contentWidth;
  }

  /// Hebt [scale] mindestens auf die Breite der Ansicht an.
  static double limitScale(double scale, double viewWidth, int contentWidth) {
    final m = minScale(viewWidth, contentWidth);
    return (m != null && scale < m) ? m : scale;
  }

  /// Hält das Bild im Sichtbereich: grösser als die Ansicht → kein leerer Rand,
  /// kleiner als die Ansicht → mittig.
  static double clampOffset(double pos, double viewLen, double contentLen) {
    if (!_on || viewLen <= 0 || contentLen <= 0) return pos;
    if (contentLen <= viewLen) return (viewLen - contentLen) / 2;
    final min = viewLen - contentLen;
    if (pos < min) return min;
    if (pos > 0) return 0;
    return pos;
  }

  /// Senkrecht: Die gemessene Höhe enthält Fusszeile und Navigationsleiste,
  /// darum darf das Bild unten um diesen Puffer weiter hochgeschoben werden.
  /// Ist das Bild niedriger als die Ansicht, bleibt das Verschieben frei.
  static const _bottomSlack = 160.0;

  static double clampOffsetY(double pos, double viewLen, double contentLen) {
    if (!_on || viewLen <= 0 || contentLen <= viewLen) return pos;
    final min = viewLen - contentLen - _bottomSlack;
    if (pos < min) return min;
    if (pos > 0) return 0;
    return pos;
  }
}

/// Eigene Anpassung: Tastenkürzel an die Gegenstelle senden.
class LxKeys {
  static void send(InputModel input, LxShortcut s) {
    final name = s.rustKey;
    if (name == null) return;
    final oldCtrl = input.ctrl;
    final oldAlt = input.alt;
    final oldShift = input.shift;
    final oldCommand = input.command;
    input.ctrl = s.ctrl;
    input.alt = s.alt;
    input.shift = s.shift;
    // «Win» allein wird als eigene Taste gesendet, nicht als Modifikator.
    input.command = name == 'Meta' ? false : s.win;
    input.inputKey(name);
    input.ctrl = oldCtrl;
    input.alt = oldAlt;
    input.shift = oldShift;
    input.command = oldCommand;
  }
}
