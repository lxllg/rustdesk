import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';

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
      case LxPrefs.actionMoveClick:
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
        // Nur beim langen Drücken folgt ein «Maustaste hoch» (onLongPressUp
        // im Original-Code); bei anderen Gesten wird normal geklickt.
        if (gesture == LxPrefs.gestureLongPress) {
          await input.tapDown(MouseButtons.left);
        } else {
          await input.tap(MouseButtons.left);
        }
        break;
      case LxPrefs.actionMove:
      default:
        break;
    }
    return true;
  }

  /// Maus-Modus: «Tippen = Mauszeiger hierher + Linksklick».
  /// Gibt true zurück, wenn erledigt (dann kein Klick an alter Stelle).
  static Future<bool> mouseModeTap(FFI ffi, Offset? localPos) async {
    if (!isMobile || ffi.ffiModel.touchMode || localPos == null) return false;
    if (LxPrefs.touchAction(LxPrefs.gestureTap) != LxPrefs.actionMoveClick) {
      return false;
    }
    final moved = await ffi.cursorModel.move(localPos.dx, localPos.dy);
    if (moved) await ffi.inputModel.tap(MouseButtons.left);
    return true;
  }

  // Zwei Finger: 0 = offen, 1 = verschieben, 2 = zoomen (wie RustDesk).
  static int _twoMode = 0;
  static Offset _twoMove = Offset.zero;

  static void twoFingerStart() {
    _twoMode = 0;
    _twoMove = Offset.zero;
  }

  /// true = nur verschieben (bereits erledigt), false = Original-Code (zoomen).
  static bool twoFingerPan(FFI ffi, double scale, Offset focalDelta) {
    if (!isMobile || !LxPrefs.twoFingerPan) return false;
    if (_twoMode == 0) {
      if ((scale - 1).abs() > 0.06) {
        _twoMode = 2;
      } else {
        _twoMove += focalDelta;
        if (_twoMove.distance > 16) _twoMode = 1;
      }
    }
    if (_twoMode == 2) return false;
    ffi.canvasModel.panX(focalDelta.dx);
    ffi.canvasModel.panY(focalDelta.dy);
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
      !ffi.ffiModel.isPeerMobile &&
      LxPrefs.oneFingerPan == LxPrefs.panCanvas;

  /// Ränder links/rechts verschieben das Bild, die Mitte zieht/markiert.
  static bool edgePan(FFI ffi) =>
      isMobile &&
      ffi.ffiModel.touchMode &&
      !ffi.ffiModel.isPeerMobile &&
      LxPrefs.oneFingerPan == LxPrefs.panEdges;

  // Fester Modus: Die Richtung wird zu Beginn jeder Wischbewegung festgelegt.
  static Offset _acc = Offset.zero;
  static int _axis = 0; // 0 = offen, 1 = waagrecht, 2 = senkrecht
  static double _scrollAcc = 0;

  static void panStart() {
    _acc = Offset.zero;
    _axis = 0;
    _scrollAcc = 0;
  }

  static void panCanvas(FFI ffi, Offset delta) {
    if (ffi.canvasModel.locked) return;
    final d = LxPrefs.panInvert ? -delta : delta;
    if (!LxView.fixedMode) {
      ffi.canvasModel.panX(d.dx);
      ffi.canvasModel.panY(d.dy);
      return;
    }
    if (_axis == 0) {
      _acc += delta;
      if (_acc.distance < 12) return;
      _axis = _acc.dx.abs() >= _acc.dy.abs() ? 1 : 2;
    }
    if (_axis == 1) {
      ffi.canvasModel.panX(d.dx);
      return;
    }
    // Senkrecht: als Mausrad an den PC senden (gleiche Richtung wie das
    // Scrollen am rechten Rand).
    _scrollAcc += d.dy;
    final step = LxPrefs.edgeScrollStepPx;
    while (_scrollAcc.abs() >= step) {
      final dir = _scrollAcc > 0 ? 1 : -1;
      ffi.inputModel.scroll(dir);
      _scrollAcc -= dir * step;
    }
  }
}

/// Eigene Anpassung: Zoom und Verschieben auf das PC-Bild begrenzen.
class LxView {
  static bool get _on => isMobile && (LxPrefs.limitZoom || fixedMode);

  /// Fester Zoom: kein Zoomen, Start mittig, hoch/runter scrollt am PC.
  static bool get fixedMode => isMobile && LxPrefs.viewMode == LxPrefs.viewFixed;

  // Ungefähre Höhe der Fusszeile, die unten über dem Bild liegt.
  static const _footer = 56.0;

  static double fixedScale(Size view, int dw, int dh, double dpr) {
    if (dw <= 0 || dh <= 0 || view.width <= 0 || view.height <= 0) return 1;
    switch (LxPrefs.fixedZoom) {
      case LxPrefs.zoomWidth:
        return view.width / dw;
      case LxPrefs.zoomOriginal:
        return dpr > 0 ? 1 / dpr : 1;
      default:
        final h = view.height - _footer;
        return (h > 0 ? h : view.height) / dh;
    }
  }

  /// Senkrecht mittig im sichtbaren Bereich über der Fusszeile.
  static double fixedTop(double viewHeight, double contentHeight) =>
      (viewHeight - _footer - contentHeight) / 2;

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

/// Eigene Anpassung: Schwärzen ohne Meldung in der Bildschirmmitte.
/// Der Zustand erscheint stattdessen als kleines Zeichen am Symbol in der
/// Fusszeile (Häkchen = ein, X = aus, Kreis = wird umgeschaltet).
class LxPrivacyUi {
  /// Gewünschter Zustand, solange das Umschalten läuft (sonst null).
  static final target = Rxn<bool>();
  static Timer? _timer;

  static void start(bool on) {
    _timer?.cancel();
    target.value = on;
    _timer = Timer(const Duration(seconds: 12), done);
  }

  static void done() {
    _timer?.cancel();
    _timer = null;
    target.value = null;
  }

  /// true = Meldung von RustDesk nicht als Dialog anzeigen.
  static bool intercept(String? type, String? title, String? text) {
    if (!isMobile || title != 'Privacy mode') return false;
    done();
    // Ein-/Ausschalten hat geklappt: das Symbol zeigt es bereits.
    if (type == 'custom-nocancel') return true;
    // Fehler kurz unten einblenden statt als Dialog in der Mitte.
    showToast('Schwärzen: ${translate(text ?? '')}');
    return true;
  }
}

/// Eigene Anpassung: Bei kurzzeitigen Netzwerkfehlern (Server nicht
/// erreichbar, Adresse nicht auflösbar) still erneut verbinden, statt sofort
/// eine Fehlermeldung zu zeigen.
class LxConn {
  static const maxTries = 4;
  static int _tries = 0;

  static const _transient = [
    'Failed to connect to',
    'failed to lookup address',
    'No address associated with hostname',
    'Network is unreachable',
    'timed out',
    'Timeout',
  ];

  /// Neue Verbindung oder erfolgreich verbunden: Zähler zurücksetzen.
  static void reset() => _tries = 0;

  /// Liefert die Wartezeit bis zum nächsten Versuch, oder null = Meldung zeigen.
  static Duration? retryDelay(String? type, String? title, String? text) {
    if (!isMobile || !LxPrefs.autoRetry) return null;
    if (title != 'Connection Error' || text == null) return null;
    if (!_transient.any((t) => text.contains(t))) return null;
    if (_tries >= maxTries) return null;
    _tries++;
    return Duration(milliseconds: 1000 + 700 * _tries);
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
