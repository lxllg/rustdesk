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

  static String _get(String key) => bind.mainGetLocalOption(key: key);
  static Future<void> _set(String key, String value) =>
      bind.mainSetLocalOption(key: key, value: value);

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
  static const barChat = 'chat';
  static const barMore = 'more';

  /// Reihenfolge = Reihenfolge in der Fusszeile.
  static const barItems = <String>[
    barClose,
    barDisplay,
    barKeyboard,
    barMode,
    barChat,
    barMore,
  ];

  static const barItemLabels = <String, String>{
    barClose: 'Verbindung beenden',
    barDisplay: 'Anzeige-Optionen',
    barKeyboard: 'Tastatur',
    barMode: 'Maus-/Touch-Modus (bei Android-Geräten: Werkzeuge)',
    barChat: 'Chat / Sprachanruf',
    barMore: 'Weitere Aktionen',
  };

  static const barItemIcons = <String, IconData>{
    barClose: Icons.clear,
    barDisplay: Icons.tv,
    barKeyboard: Icons.keyboard,
    barMode: Icons.touch_app,
    barChat: Icons.message,
    barMore: Icons.more_vert,
  };

  static const _kNone = '-';

  static Set<String> get enabledBarItems {
    final raw = _get(_kBarItems).trim();
    if (raw.isEmpty) return barItems.toSet();
    if (raw == _kNone) return <String>{};
    return raw.split(',').where(barItems.contains).toSet();
  }

  static bool isBarItemEnabled(String key) => enabledBarItems.contains(key);

  static Future<void> setBarItemEnabled(String key, bool enabled) {
    final items = enabledBarItems;
    if (enabled) {
      items.add(key);
    } else {
      items.remove(key);
    }
    final ordered = barItems.where(items.contains).toList();
    return _set(_kBarItems, ordered.isEmpty ? _kNone : ordered.join(','));
  }
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
        ],
      ),
    );
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
