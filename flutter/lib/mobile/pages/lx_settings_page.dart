import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import '../../common.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';

/// Eigene Anpassungen dieser Version.
/// Alles wird lokal auf dem Gerät gespeichert (lokale RustDesk-Optionen).
class LxPrefs {
  static const _kAutoConnectId = 'lx-auto-connect-id';
  static const _kEdgeScroll = 'lx-edge-scroll';
  static const _kEdgeScrollWidth = 'lx-edge-scroll-width';
  static const _kEdgeScrollSpeed = 'lx-edge-scroll-speed';
  static const _kEdgeScrollInvert = 'lx-edge-scroll-invert';
  static const _kBarAlwaysVisible = 'lx-bar-always-visible';
  static const _kBarItems = 'lx-bar-items';

  // Zwischenspeicher: manche Werte werden bei jeder Geste/Bewegung gelesen.
  // Nur dieser Code schreibt die lx-Optionen, darum bleibt er aktuell.
  static final Map<String, String> _cache = {};

  static String _get(String key) =>
      _cache[key] ??= bind.mainGetLocalOption(key: key);
  static Future<void> _set(String key, String value) {
    _cache[key] = value;
    return bind.mainSetLocalOption(key: key, value: value);
  }

  // ---------- Auto-Verbinden ----------

  static String get autoConnectId => _get(_kAutoConnectId).trim();
  static Future<void> setAutoConnectId(String id) =>
      _set(_kAutoConnectId, id.replaceAll(' ', ''));

  static bool _autoConnectTried = false;

  /// Wird einmal pro App-Start aufgerufen. Nach dem Trennen der Verbindung
  /// landet man normal auf dem Startbildschirm, ohne erneut zu verbinden.
  static Future<void> tryAutoConnect(BuildContext context) async {
    if (_autoConnectTried) return;
    _autoConnectTried = true;
    if (bind.isIncomingOnly()) return;
    final id = autoConnectId;
    if (id.isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!context.mounted) return;
    connect(context, id);
  }

  // ---------- Scrollen am rechten Rand ----------

  static bool get edgeScrollEnabled => _get(_kEdgeScroll) != 'N';
  static Future<void> setEdgeScrollEnabled(bool v) =>
      _set(_kEdgeScroll, v ? 'Y' : 'N');

  static const edgeScrollWidths = <String, double>{
    'narrow': 24,
    'medium': 36,
    'wide': 48,
  };
  static const edgeScrollWidthLabels = <String, String>{
    'narrow': 'Schmal',
    'medium': 'Mittel',
    'wide': 'Breit',
  };
  static String get edgeScrollWidthKey {
    final v = _get(_kEdgeScrollWidth);
    return edgeScrollWidths.containsKey(v) ? v : 'medium';
  }

  static double get edgeScrollWidth => edgeScrollWidths[edgeScrollWidthKey]!;
  static Future<void> setEdgeScrollWidthKey(String v) =>
      _set(_kEdgeScrollWidth, v);

  /// Fingerweg in Pixeln pro Mausrad-Raste.
  static const edgeScrollSteps = <String, double>{
    'slow': 24,
    'normal': 14,
    'fast': 7,
  };
  static const edgeScrollSpeedLabels = <String, String>{
    'slow': 'Langsam',
    'normal': 'Normal',
    'fast': 'Schnell',
  };
  static String get edgeScrollSpeedKey {
    final v = _get(_kEdgeScrollSpeed);
    return edgeScrollSteps.containsKey(v) ? v : 'normal';
  }

  static double get edgeScrollStepPx => edgeScrollSteps[edgeScrollSpeedKey]!;
  static Future<void> setEdgeScrollSpeedKey(String v) =>
      _set(_kEdgeScrollSpeed, v);

  static bool get edgeScrollInvert => _get(_kEdgeScrollInvert) == 'Y';
  static Future<void> setEdgeScrollInvert(bool v) =>
      _set(_kEdgeScrollInvert, v ? 'Y' : 'N');

  // ---------- Fusszeile ----------

  static bool get barAlwaysVisible => _get(_kBarAlwaysVisible) == 'Y';
  static Future<void> setBarAlwaysVisible(bool v) =>
      _set(_kBarAlwaysVisible, v ? 'Y' : 'N');

  static const barClose = 'close';
  static const barDisplay = 'display';
  static const barKeyboard = 'keyboard';
  static const barMode = 'mode';
  static const barLock = 'lock';
  static const barPrivacy = 'privacy';
  static const barChat = 'chat';
  static const barMore = 'more';

  /// Reihenfolge = Reihenfolge in der Fusszeile.
  static const barItems = <String>[
    barClose,
    barDisplay,
    barKeyboard,
    barMode,
    barLock,
    barPrivacy,
    barChat,
    barMore,
  ];

  static const barItemLabels = <String, String>{
    barClose: 'Verbindung beenden',
    barDisplay: 'Anzeige-Optionen',
    barKeyboard: 'Tastatur',
    barMode: 'Maus-/Touch-Modus (bei Android-Geräten: Werkzeuge)',
    barLock: 'Nach Sitzungsende sperren (Ein/Aus)',
    barPrivacy: 'PC-Bildschirm schwärzen (Ein/Aus)',
    barChat: 'Chat / Sprachanruf',
    barMore: 'Weitere Aktionen',
  };

  static const barItemIcons = <String, IconData>{
    barClose: Icons.clear,
    barDisplay: Icons.tv,
    barKeyboard: Icons.keyboard,
    barMode: Icons.touch_app,
    barLock: Icons.lock_outline,
    barPrivacy: Icons.desktop_access_disabled,
    barChat: Icons.message,
    barMore: Icons.more_vert,
  };

  static const _kNone = '-';
  // Später hinzugekommene Knöpfe haben je einen eigenen Schalter,
  // damit sie auch bei bereits angepasster Fusszeile standardmässig erscheinen.
  static const _lateBarItems = <String, String>{
    barLock: 'lx-bar-lock',
    barPrivacy: 'lx-bar-privacy',
  };

  static Set<String> get enabledBarItems {
    final raw = _get(_kBarItems).trim();
    final Set<String> items;
    if (raw.isEmpty) {
      items = barItems.toSet();
    } else if (raw == _kNone) {
      items = <String>{};
    } else {
      items = raw.split(',').where(barItems.contains).toSet();
    }
    for (final e in _lateBarItems.entries) {
      items.remove(e.key);
      if (_get(e.value) != 'N') items.add(e.key);
    }
    return items;
  }

  static bool isBarItemEnabled(String key) => enabledBarItems.contains(key);

  static Future<void> setBarItemEnabled(String key, bool enabled) {
    final lateKey = _lateBarItems[key];
    if (lateKey != null) return _set(lateKey, enabled ? 'Y' : 'N');
    final items = enabledBarItems..removeAll(_lateBarItems.keys);
    if (enabled) {
      items.add(key);
    } else {
      items.remove(key);
    }
    final ordered = barItems.where(items.contains).toList();
    return _set(_kBarItems, ordered.isEmpty ? _kNone : ordered.join(','));
  }

  // ---------- Android-Navigationsleiste ----------

  static const _kShowSystemNav = 'lx-show-system-nav';
  static bool get showSystemNav => _get(_kShowSystemNav) == 'Y';
  static Future<void> setShowSystemNav(bool v) =>
      _set(_kShowSystemNav, v ? 'Y' : 'N');

  // ---------- Verbindung im Hintergrund halten ----------

  static const _kKeepAlive = 'lx-keep-alive';
  static bool get keepAlive => _get(_kKeepAlive) != 'N';
  static Future<void> setKeepAlive(bool v) => _set(_kKeepAlive, v ? 'Y' : 'N');

  // ---------- PC-Bildschirm schwärzen ----------

  static const _kAutoPrivacy = 'lx-auto-privacy';
  static bool get autoPrivacy => _get(_kAutoPrivacy) == 'Y';
  static Future<void> setAutoPrivacy(bool v) =>
      _set(_kAutoPrivacy, v ? 'Y' : 'N');

  // ---------- Tastatur ----------

  /// Bildschirmtastatur verdeckt nur den unteren Teil, das Bild bleibt stehen.
  static const _kKeyboardOverlay = 'lx-keyboard-overlay';
  static bool get keyboardOverlay => _get(_kKeyboardOverlay) != 'N';
  static Future<void> setKeyboardOverlay(bool v) =>
      _set(_kKeyboardOverlay, v ? 'Y' : 'N');

  /// Vorhandene Tasten der Leiste über der Tastatur, die sich ausblenden lassen.
  static const builtinKeys = <String>[
    'Ctrl', 'Alt', 'Shift', 'Win', 'Fn', 'Esc', 'Tab', 'Home', 'End', 'Ins',
    'Del', 'PgUp', 'PgDn', 'PrtScr', 'ScrollLock', 'Pause', 'Menu', 'Enter',
    'arrows', 'Ctrl+C', 'Ctrl+V', 'Ctrl+S',
  ];

  static const builtinKeyLabels = <String, String>{
    'Fn': 'Fn (F1–F12)',
    'Home': 'Home (Pos1)',
    'End': 'End (Ende)',
    'Ins': 'Ins (Einfg)',
    'Del': 'Del (Entf)',
    'PgUp': 'PgUp (Bild auf)',
    'PgDn': 'PgDn (Bild ab)',
    'PrtScr': 'PrtScr (Druck)',
    'Menu': 'Menu (Kontextmenü)',
    'arrows': 'Pfeiltasten',
  };

  static const _kHiddenKeys = 'lx-hidden-keys';

  static Set<String> get hiddenKeys {
    final raw = _get(_kHiddenKeys).trim();
    if (raw.isEmpty) return <String>{};
    return raw.split(',').where(builtinKeys.contains).toSet();
  }

  static Future<void> setKeyVisible(String key, bool visible) {
    final hidden = hiddenKeys;
    if (visible) {
      hidden.remove(key);
    } else {
      hidden.add(key);
    }
    return _set(_kHiddenKeys, builtinKeys.where(hidden.contains).join(','));
  }

  /// [text] = Beschriftung in der Leiste (z. B. ' Alt ', 'Cmd+C'),
  /// [arrow] = true für die Pfeiltasten.
  static bool isBuiltinKeyHidden(String text, {bool arrow = false}) {
    final hidden = hiddenKeys;
    if (hidden.isEmpty) return false;
    if (arrow) return hidden.contains('arrows');
    var id = text.trim().replaceAll('Cmd', text.contains('+') ? 'Ctrl' : 'Win');
    return hidden.contains(id);
  }

  // ---------- Wischen mit 1 Finger ----------

  static const panCanvas = 'canvas';
  static const panDrag = 'drag';
  static const panLabels = <String, String>{
    panCanvas: 'Bild verschieben',
    panDrag: 'Maus ziehen / markieren (wie RustDesk)',
  };
  static const _kOneFingerPan = 'lx-one-finger-pan';
  static String get oneFingerPan =>
      _get(_kOneFingerPan) == panDrag ? panDrag : panCanvas;
  static Future<void> setOneFingerPan(String v) => _set(_kOneFingerPan, v);

  static const _kPanInvert = 'lx-pan-invert';
  static bool get panInvert => _get(_kPanInvert) == 'Y';
  static Future<void> setPanInvert(bool v) => _set(_kPanInvert, v ? 'Y' : 'N');

  // ---------- Zoom begrenzen ----------

  static const _kLimitZoom = 'lx-limit-zoom';
  static bool get limitZoom => _get(_kLimitZoom) != 'N';
  static Future<void> setLimitZoom(bool v) => _set(_kLimitZoom, v ? 'Y' : 'N');

  // ---------- Gesten im Touch-Modus ----------

  static const gestureTap = 'tap';
  static const gestureDoubleTap = 'doubleTap';
  static const gestureLongPress = 'longPress';
  static const gestureTwoFingerTap = 'twoFingerTap';

  static const gestures = <String>[
    gestureTap,
    gestureDoubleTap,
    gestureLongPress,
    gestureTwoFingerTap,
  ];

  static const gestureLabels = <String, String>{
    gestureTap: 'Tippen (1 Finger)',
    gestureDoubleTap: 'Doppeltippen (1 Finger)',
    gestureLongPress: 'Lange drücken (1 Finger)',
    gestureTwoFingerTap: 'Tippen mit 2 Fingern',
  };

  /// Verhalten von RustDesk – bei dieser Wahl läuft der Original-Code.
  static const gestureRustdesk = <String, String>{
    gestureTap: actionLeft,
    gestureDoubleTap: actionDouble,
    gestureLongPress: actionRight,
    gestureTwoFingerTap: actionNone,
  };

  /// Voreinstellung dieser Version.
  static const gestureDefaults = <String, String>{
    gestureTap: actionLeft,
    gestureDoubleTap: actionDouble,
    gestureLongPress: actionDrag,
    gestureTwoFingerTap: actionRight,
  };

  static const actionLeft = 'left';
  static const actionRight = 'right';
  static const actionDouble = 'double';
  static const actionMiddle = 'middle';
  static const actionMove = 'move';
  static const actionDrag = 'drag';
  static const actionNone = 'none';

  static const actionLabels = <String, String>{
    actionLeft: 'Linksklick',
    actionRight: 'Rechtsklick',
    actionDouble: 'Doppelklick',
    actionMiddle: 'Mittelklick',
    actionMove: 'Nur Mauszeiger hierher bewegen',
    actionDrag: 'Klicken & ziehen (Maustaste halten)',
    actionNone: 'Nichts',
  };

  static String touchAction(String gesture) {
    final v = _get('lx-gesture-$gesture');
    return actionLabels.containsKey(v) ? v : gestureDefaults[gesture]!;
  }

  static Future<void> setTouchAction(String gesture, String action) =>
      _set('lx-gesture-$gesture', action);

  // ---------- Eigene Tastenkürzel ----------

  static const _kShortcuts = 'lx-shortcuts';

  static List<LxShortcut> get shortcuts {
    final raw = _get(_kShortcuts).trim();
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => LxShortcut.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.isValid)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setShortcuts(List<LxShortcut> list) =>
      _set(_kShortcuts, jsonEncode(list.map((e) => e.toJson()).toList()));
}

/// Platzhalter für ausgeblendete Tasten; wird vor dem Anzeigen herausgefiltert.
class LxHiddenKey extends StatelessWidget {
  const LxHiddenKey({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Ein eigenes Tastenkürzel, z. B. Win+E oder Alt+F4.
class LxShortcut {
  final String label;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool win;
  final String key;

  const LxShortcut({
    required this.label,
    required this.ctrl,
    required this.alt,
    required this.shift,
    required this.win,
    required this.key,
  });

  factory LxShortcut.fromJson(Map<String, dynamic> j) => LxShortcut(
        label: (j['l'] ?? '').toString(),
        ctrl: j['c'] == true,
        alt: j['a'] == true,
        shift: j['s'] == true,
        win: j['w'] == true,
        key: (j['k'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() =>
      {'l': label, 'c': ctrl, 'a': alt, 's': shift, 'w': win, 'k': key};

  /// Anzeige der Tastenfolge, z. B. "Ctrl+Alt+Entf".
  String get combo => [
        if (ctrl) 'Ctrl',
        if (alt) 'Alt',
        if (shift) 'Shift',
        if (win) 'Win',
        if (key.isNotEmpty) key.toUpperCase(),
      ].join('+');

  String get displayLabel => label.trim().isNotEmpty ? label.trim() : combo;

  /// RustDesk-Name der Taste, oder null wenn unbekannt.
  /// Nur "Win" ohne weitere Taste öffnet das Startmenü.
  String? get rustKey {
    if (key.isEmpty) return (win && !ctrl && !alt && !shift) ? 'Meta' : null;
    return keyToRust(key);
  }

  bool get isValid => rustKey != null;

  static const _named = <String, String>{
    'ESC': 'VK_ESCAPE',
    'ESCAPE': 'VK_ESCAPE',
    'TAB': 'VK_TAB',
    'ENTER': 'VK_RETURN',
    'EINGABE': 'VK_RETURN',
    'SPACE': 'VK_SPACE',
    'LEER': 'VK_SPACE',
    'LEERTASTE': 'VK_SPACE',
    'BACKSPACE': 'VK_BACK',
    'RÜCK': 'VK_BACK',
    'DEL': 'VK_DELETE',
    'ENTF': 'VK_DELETE',
    'DELETE': 'VK_DELETE',
    'INS': 'VK_INSERT',
    'EINFG': 'VK_INSERT',
    'HOME': 'VK_HOME',
    'POS1': 'VK_HOME',
    'END': 'VK_END',
    'ENDE': 'VK_END',
    'PGUP': 'VK_PRIOR',
    'BILDAUF': 'VK_PRIOR',
    'PGDN': 'VK_NEXT',
    'BILDAB': 'VK_NEXT',
    'LEFT': 'VK_LEFT',
    'LINKS': 'VK_LEFT',
    'RIGHT': 'VK_RIGHT',
    'RECHTS': 'VK_RIGHT',
    'UP': 'VK_UP',
    'HOCH': 'VK_UP',
    'DOWN': 'VK_DOWN',
    'RUNTER': 'VK_DOWN',
    'PRTSCR': 'VK_SNAPSHOT',
    'DRUCK': 'VK_SNAPSHOT',
  };

  static String? keyToRust(String raw) {
    final k = raw.trim().toUpperCase().replaceAll(' ', '');
    if (k.isEmpty) return null;
    if (RegExp(r'^[A-Z0-9]$').hasMatch(k)) return 'VK_$k';
    final f = RegExp(r'^F([1-9]|1[0-2])$').firstMatch(k);
    if (f != null) return 'VK_$k';
    return _named[k];
  }

  /// Lesbare Liste der erlaubten Tasten für die Hilfe im Dialog.
  static const helpText = 'Buchstabe (A–Z), Ziffer (0–9), F1–F12, Esc, Tab, '
      'Enter, Leer, Rück, Entf, Einfg, Pos1, Ende, BildAuf, BildAb, '
      'Links, Rechts, Hoch, Runter, Druck. Nur «Win» ohne Taste öffnet das Startmenü.';
}

/// Einstellungsseite für die eigenen Anpassungen.
class LxSettingsPage extends StatefulWidget {
  const LxSettingsPage({Key? key}) : super(key: key);

  @override
  State<LxSettingsPage> createState() => _LxSettingsPageState();
}

class _LxSettingsPageState extends State<LxSettingsPage> {
  String _peerLabel(String id) {
    if (id.isEmpty) return 'Aus';
    for (final p in gFFI.recentPeersModel.peers) {
      if (p.id == id) {
        final name = p.alias.isNotEmpty ? p.alias : p.hostname;
        return name.isNotEmpty ? '$name ($id)' : id;
      }
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    gFFI.recentPeersModel.addListener(_onPeersChanged);
    if (gFFI.recentPeersModel.peers.isEmpty) {
      bind.mainLoadRecentPeers();
    }
  }

  @override
  void dispose() {
    gFFI.recentPeersModel.removeListener(_onPeersChanged);
    super.dispose();
  }

  void _onPeersChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final autoId = LxPrefs.autoConnectId;
    final edgeOn = LxPrefs.edgeScrollEnabled;
    final enabledItems = LxPrefs.enabledBarItems;
    final shortcuts = LxPrefs.shortcuts;
    final hiddenKeys = LxPrefs.hiddenKeys;

    return Scaffold(
      appBar: AppBar(title: const Text('Eigene Anpassungen')),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('Beim Start'),
            tiles: [
              SettingsTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Automatisch verbinden'),
                description: Text(_peerLabel(autoId)),
                onPressed: (context) => _pickAutoConnect(),
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Scrollen am rechten Rand'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Mit einem Finger am rechten Rand scrollen'),
                initialValue: edgeOn,
                onToggle: (v) async {
                  await LxPrefs.setEdgeScrollEnabled(v);
                  setState(() {});
                },
              ),
              if (edgeOn)
                SettingsTile(
                  leading: const Icon(Icons.straighten),
                  title: const Text('Breite der Scroll-Zone'),
                  description: Text(LxPrefs
                      .edgeScrollWidthLabels[LxPrefs.edgeScrollWidthKey]!),
                  onPressed: (context) => _pickOption(
                    title: 'Breite der Scroll-Zone',
                    options: LxPrefs.edgeScrollWidthLabels,
                    current: LxPrefs.edgeScrollWidthKey,
                    onSelected: LxPrefs.setEdgeScrollWidthKey,
                  ),
                ),
              if (edgeOn)
                SettingsTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('Scroll-Geschwindigkeit'),
                  description: Text(LxPrefs
                      .edgeScrollSpeedLabels[LxPrefs.edgeScrollSpeedKey]!),
                  onPressed: (context) => _pickOption(
                    title: 'Scroll-Geschwindigkeit',
                    options: LxPrefs.edgeScrollSpeedLabels,
                    current: LxPrefs.edgeScrollSpeedKey,
                    onSelected: LxPrefs.setEdgeScrollSpeedKey,
                  ),
                ),
              if (edgeOn)
                SettingsTile.switchTile(
                  leading: const Icon(Icons.flip),
                  title: const Text('Richtung umkehren'),
                  description: const Text(
                      'Falls sich die Scroll-Richtung falsch anfühlt.'),
                  initialValue: LxPrefs.edgeScrollInvert,
                  onToggle: (v) async {
                    await LxPrefs.setEdgeScrollInvert(v);
                    setState(() {});
                  },
                ),
            ],
          ),
          SettingsSection(
            title: const Text('Fusszeile während der Verbindung'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Immer sichtbar'),
                description:
                    const Text('Blendet den Knopf zum Einklappen aus.'),
                initialValue: LxPrefs.barAlwaysVisible,
                onToggle: (v) async {
                  await LxPrefs.setBarAlwaysVisible(v);
                  setState(() {});
                },
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.space_bar),
                title: const Text('Android-Navigationsleiste anzeigen'),
                description: const Text(
                    'Lässt Zurück/Home/Übersicht von Android während der '
                    'Verbindung sichtbar. Die Fusszeile liegt dann darüber.'),
                initialValue: LxPrefs.showSystemNav,
                onToggle: (v) async {
                  await LxPrefs.setShowSystemNav(v);
                  setState(() {});
                },
              ),
              for (final key in LxPrefs.barItems)
                SettingsTile.switchTile(
                  leading: Icon(LxPrefs.barItemIcons[key]),
                  title: Text(LxPrefs.barItemLabels[key]!),
                  description: key == LxPrefs.barClose
                      ? const Text(
                          'Trennen geht auch jederzeit mit der Zurück-Geste.')
                      : null,
                  initialValue: enabledItems.contains(key),
                  onToggle: (v) async {
                    await LxPrefs.setBarItemEnabled(key, v);
                    setState(() {});
                  },
                ),
            ],
          ),
          SettingsSection(
            title: const Text('Verbindung'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.link),
                title: const Text('Verbindung im Hintergrund halten'),
                description: const Text(
                    'Beim Wechsel in eine andere App bleibt die Verbindung '
                    'bestehen. Solange verbunden ist, zeigt Android dazu eine '
                    'Mitteilung an.'),
                initialValue: LxPrefs.keepAlive,
                onToggle: (v) async {
                  await LxPrefs.setKeepAlive(v);
                  setState(() {});
                },
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.desktop_access_disabled),
                title: const Text('PC-Bildschirm automatisch schwärzen'),
                description: const Text(
                    'Schaltet beim Verbinden den Privatsphäre-Modus ein: Am PC '
                    'sieht man nur Schwarz, du siehst weiterhin alles. Nach dem '
                    'Trennen ist der PC-Bildschirm wieder normal.'),
                initialValue: LxPrefs.autoPrivacy,
                onToggle: (v) async {
                  await LxPrefs.setAutoPrivacy(v);
                  setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Ansicht'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.fit_screen),
                title: const Text('Zoom auf Bildschirmbreite begrenzen'),
                description: const Text(
                    'Weiter herauszoomen geht nur, bis der PC-Bildschirm links '
                    'und rechts anstösst. Kein Verschieben über den Rand hinaus.'),
                initialValue: LxPrefs.limitZoom,
                onToggle: (v) async {
                  await LxPrefs.setLimitZoom(v);
                  setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Gesten im Touch-Modus'),
            tiles: [
              SettingsTile(
                leading: const Icon(Icons.swipe),
                title: const Text('Wischen mit 1 Finger'),
                description:
                    Text(LxPrefs.panLabels[LxPrefs.oneFingerPan]!),
                onPressed: (context) => _pickOption(
                  title: 'Wischen mit 1 Finger',
                  options: LxPrefs.panLabels,
                  current: LxPrefs.oneFingerPan,
                  onSelected: LxPrefs.setOneFingerPan,
                ),
              ),
              if (LxPrefs.oneFingerPan == LxPrefs.panCanvas)
                SettingsTile.switchTile(
                  leading: const Icon(Icons.flip),
                  title: const Text('Verschieben umkehren'),
                  description: const Text(
                      'Aus: Bild folgt dem Finger. Ein: Ansicht bewegt sich in '
                      'Fingerrichtung.'),
                  initialValue: LxPrefs.panInvert,
                  onToggle: (v) async {
                    await LxPrefs.setPanInvert(v);
                    setState(() {});
                  },
                ),
              for (final g in LxPrefs.gestures)
                SettingsTile(
                  leading: const Icon(Icons.gesture),
                  title: Text(LxPrefs.gestureLabels[g]!),
                  description: Text(
                      LxPrefs.actionLabels[LxPrefs.touchAction(g)]! +
                          (g == LxPrefs.gestureLongPress &&
                                  LxPrefs.touchAction(g) == LxPrefs.actionMove
                              ? ' (folgt dem Finger)'
                              : '') +
                          (g == LxPrefs.gestureLongPress &&
                                  LxPrefs.touchAction(g) == LxPrefs.actionDrag
                              ? ' – loslassen ohne Bewegen = Klick'
                              : '')),
                  onPressed: (context) => _pickOption(
                    title: LxPrefs.gestureLabels[g]!,
                    options: g == LxPrefs.gestureLongPress
                        ? LxPrefs.actionLabels
                        : (Map.of(LxPrefs.actionLabels)
                          ..remove(LxPrefs.actionDrag)),
                    current: LxPrefs.touchAction(g),
                    onSelected: (v) => LxPrefs.setTouchAction(g, v),
                  ),
                ),
            ],
          ),
          SettingsSection(
            title: const Text('Tastatur'),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.keyboard_hide),
                title: const Text('Bild beim Öffnen der Tastatur nicht verschieben'),
                description: const Text(
                    'Die Tastatur verdeckt nur den unteren Teil, oben bleibt '
                    'alles wie vorher. Die Tastenleiste sitzt direkt über der '
                    'Tastatur.'),
                initialValue: LxPrefs.keyboardOverlay,
                onToggle: (v) async {
                  await LxPrefs.setKeyboardOverlay(v);
                  setState(() {});
                },
              ),
            ],
          ),
          SettingsSection(
            title: const Text('Vorhandene Tasten in der Tastatur-Leiste'),
            tiles: [
              for (final k in LxPrefs.builtinKeys)
                SettingsTile.switchTile(
                  title: Text(LxPrefs.builtinKeyLabels[k] ?? k),
                  initialValue: !hiddenKeys.contains(k),
                  onToggle: (v) async {
                    await LxPrefs.setKeyVisible(k, v);
                    setState(() {});
                  },
                ),
            ],
          ),
          SettingsSection(
            title: const Text('Eigene Tastenkürzel (Tastatur-Leiste)'),
            tiles: [
              for (final s in shortcuts)
                SettingsTile(
                  leading: const Icon(Icons.keyboard_command_key),
                  title: Text(s.displayLabel),
                  description: Text(s.combo),
                  trailing: const Icon(Icons.delete_outline),
                  onPressed: (context) => _deleteShortcut(s),
                ),
              SettingsTile(
                leading: const Icon(Icons.add),
                title: const Text('Kürzel hinzufügen'),
                description: const Text(
                    'Erscheint als Knopf in der Leiste über der Tastatur, '
                    'z. B. Win+E, Ctrl+A, Alt+F4.'),
                onPressed: (context) => _addShortcut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShortcut(LxShortcut s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kürzel löschen?'),
        content: Text('${s.displayLabel} (${s.combo})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    final list = LxPrefs.shortcuts;
    final i = list.indexWhere((e) =>
        e.label == s.label && e.combo == s.combo);
    if (i >= 0) list.removeAt(i);
    await LxPrefs.setShortcuts(list);
    if (mounted) setState(() {});
  }

  Future<void> _addShortcut() async {
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    var ctrl = false, alt = false, shift = false, win = false;
    String? error;
    final result = await showDialog<LxShortcut>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          Widget chip(String text, bool value, ValueChanged<bool> onChanged) =>
              FilterChip(
                label: Text(text),
                selected: value,
                onSelected: (v) => setDialogState(() => onChanged(v)),
              );
          return AlertDialog(
            title: const Text('Kürzel hinzufügen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    chip('Ctrl', ctrl, (v) => ctrl = v),
                    chip('Alt', alt, (v) => alt = v),
                    chip('Shift', shift, (v) => shift = v),
                    chip('Win', win, (v) => win = v),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    decoration: InputDecoration(
                      labelText: 'Taste',
                      hintText: 'z. B. E, F4, Tab',
                      errorText: error,
                    ),
                  ),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Bezeichnung (optional)',
                      hintText: 'z. B. Explorer',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(LxShortcut.helpText,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('Abbrechen')),
              TextButton(
                onPressed: () {
                  final s = LxShortcut(
                    label: labelController.text.trim(),
                    ctrl: ctrl,
                    alt: alt,
                    shift: shift,
                    win: win,
                    key: keyController.text.trim(),
                  );
                  if (!s.isValid) {
                    setDialogState(() => error = 'Diese Taste kenne ich nicht.');
                    return;
                  }
                  Navigator.of(c).pop(s);
                },
                child: const Text('Hinzufügen'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    await LxPrefs.setShortcuts([...LxPrefs.shortcuts, result]);
    if (mounted) setState(() {});
  }

  Future<void> _pickOption({
    required String title,
    required Map<String, String> options,
    required String current,
    required Future<void> Function(String) onSelected,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final e in options.entries)
            RadioListTile<String>(
              value: e.key,
              groupValue: current,
              title: Text(e.value),
              onChanged: (v) => Navigator.of(ctx).pop(v),
            ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await onSelected(selected);
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickAutoConnect() async {
    final current = LxPrefs.autoConnectId;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: gFFI.recentPeersModel,
        builder: (ctx, _) {
          final List<Peer> peers = gFFI.recentPeersModel.peers;
          return SimpleDialog(
            title: const Text('Automatisch verbinden mit'),
            children: [
              RadioListTile<String>(
                value: '',
                groupValue: current,
                title: const Text('Aus'),
                onChanged: (v) => Navigator.of(ctx).pop(v),
              ),
              for (final p in peers)
                RadioListTile<String>(
                  value: p.id,
                  groupValue: current,
                  title: Text(p.alias.isNotEmpty
                      ? p.alias
                      : (p.hostname.isNotEmpty ? p.hostname : p.id)),
                  subtitle: Text(p.id),
                  onChanged: (v) => Navigator.of(ctx).pop(v),
                ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('ID manuell eingeben'),
                onTap: () async {
                  final id = await _askId(ctx, current);
                  if (id != null && ctx.mounted) Navigator.of(ctx).pop(id);
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  'Tipp: Beim ersten Verbinden «Passwort merken» aktivieren, '
                  'dann klappt das automatische Verbinden ohne Nachfrage.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      await LxPrefs.setAutoConnectId(result);
      if (mounted) setState(() {});
    }
  }

  Future<String?> _askId(BuildContext ctx, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('ID eingeben'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'z. B. 123 456 789'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(c).pop(controller.text.replaceAll(' ', '')),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
