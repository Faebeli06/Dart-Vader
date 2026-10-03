import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

// Palette: Dunkel = 90s auf Nothing-Schwarz, Hell = Beige mit Rot/Blau/Orange/Gelb. Umschaltung per applyTheme().
final darkMode = ValueNotifier<bool>(true), vibOn = ValueNotifier<bool>(true), soundOn = ValueNotifier<bool>(true);
final diagOn = ValueNotifier<bool>(false), autoFit = ValueNotifier<bool>(true);
String diagWhy = '';
Color kBg = const Color(0xFF09080F), kCard = const Color(0xFF14121C), kLine = const Color(0xFF2B2838);
Color kInk = const Color(0xFFF4F2FA), kDim = const Color(0xFF9A97A8), kOnAccent = Colors.black;
Color kAccent = const Color(0xFF1AE5D0), kViolet = const Color(0xFF9A6BFF);
List<Color> teamColors = [kAccent, kViolet, const Color(0xFFFF5FA2), const Color(0xFFFFD23F)];

void applyTheme(bool d) {
  if (d) {
    kBg = Color(0xFF09080F); kCard = Color(0xFF14121C); kLine = Color(0xFF2B2838);
    kInk = Color(0xFFF4F2FA); kDim = Color(0xFF9A97A8); kOnAccent = Colors.black;
    kAccent = Color(0xFF1AE5D0); kViolet = Color(0xFF9A6BFF);
    teamColors = [kAccent, kViolet, Color(0xFFFF5FA2), Color(0xFFFFD23F)];
  } else {
    kBg = Color(0xFFF1E7D3); kCard = Color(0xFFFBF5E6); kLine = Color(0xFFC9BB9C);
    kInk = Color(0xFF1B1A22); kDim = Color(0xFF6B6558); kOnAccent = Colors.white;
    kAccent = Color(0xFF2563EB); kViolet = Color(0xFFE63B2E);
    teamColors = [kAccent, kViolet, Color(0xFFFF8A00), Color(0xFFE0A800)];
  }
}

void feedback() {
  if (vibOn.value) HapticFeedback.mediumImpact();
  if (soundOn.value) SystemSound.play(SystemSoundType.click);
}

Future<void> saveCalib() async {
  final p = await SharedPreferences.getInstance();
  if (calib.length == 4) {
    await p.setStringList('calib', [for (final o in calib) '${o.dx},${o.dy}']);
  } else {
    await p.remove('calib');
  }
}

ThemeData appTheme(bool d) => ThemeData(
    brightness: d ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    fontFamily: 'monospace',
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: (d ? ColorScheme.dark() : ColorScheme.light()).copyWith(primary: kAccent, secondary: kViolet, surface: kBg),
    appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: kInk,
        titleTextStyle: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, color: kInk)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: kCard),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: kAccent, foregroundColor: kOnAccent, shape: StadiumBorder(), minimumSize: Size.fromHeight(52))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: StadiumBorder(), foregroundColor: kInk, side: BorderSide(color: kLine))));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  darkMode.value = p.getBool('dark') ?? true;
  vibOn.value = p.getBool('vib') ?? true;
  soundOn.value = p.getBool('snd') ?? true;
  diagOn.value = p.getBool('diag') ?? false;
  autoFit.value = p.getBool('fit') ?? true;
  final cs = p.getStringList('calib');
  if (cs != null && cs.length == 4) {
    calib = [for (final s in cs) Offset(double.parse(s.split(',')[0]), double.parse(s.split(',')[1]))];
  }
  runApp(ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (_, d, __) {
        applyTheme(d);
        return MaterialApp(
            title: 'StanDart',
            debugShowCheckedModeBanner: false,
            builder: (c, child) => Container(color: kBg, child: CustomPaint(painter: _Dots(), child: child)),
            theme: appTheme(d),
            home: const SplashPage());
      }));
}

// ---------- Spiellogik ----------
const order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

class Dart {
  final int n, m; // n: 0=Fehl, 25=Bull; m: Multiplikator
  const Dart(this.n, this.m);
  int get points => n * m;
  String get label => n == 0
      ? 'OUT'
      : n == 25
          ? (m == 2 ? 'D-Bull' : 'S-Bull')
          : '${m == 3 ? 'T' : m == 2 ? 'D' : ''}$n';
}

/// dx, dy: Abstand vom Mittelpunkt, normiert auf den Außenrand des Doppelrings.
Dart fromBoard(double dx, double dy) {
  final r = sqrt(dx * dx + dy * dy);
  if (r > 1.0) return const Dart(0, 1);
  if (r <= 0.037) return const Dart(25, 2);
  if (r <= 0.094) return const Dart(25, 1);
  final a = (atan2(dx, -dy) * 180 / pi + 9 + 360) % 360;
  final n = order[(a ~/ 18) % 20];
  if (r >= 0.953) return Dart(n, 2);
  if (r >= 0.582 && r <= 0.629) return Dart(n, 3);
  return Dart(n, 1);
}

class Game {
  final List<String> names;
  final int start;
  final bool dbl;
  late List<int> scores, thrown;
  late List<List<Dart>> last;
  int cur = 0, turnStart;
  List<Dart> darts = [];
  String? winner, msg;
  bool hold = false, held = false; // hold: Zugende erst nach Bestätigung
  Game(this.names, this.start, this.dbl) : turnStart = start {
    scores = List.filled(names.length, start);
    thrown = List.filled(names.length, 0);
    last = List.generate(names.length, (_) => <Dart>[]);
  }
  String avg(int i) => thrown[i] == 0 ? '–' : ((start - scores[i]) / thrown[i] * 3).toStringAsFixed(1);
  int _sum() => darts.fold<int>(0, (s, d) => s + d.points);
  void add(Dart d) {
    if (winner != null || held) return;
    _save();
    msg = null;
    thrown[cur]++;
    darts.add(d);
    final rem = turnStart - _sum();
    final bust = rem < 0 || (dbl && rem == 1) || (rem == 0 && dbl && d.m != 2);
    if (bust) {
      scores[cur] = turnStart;
      msg = 'Bust!';
      if (hold) {
        held = true;
      } else {
        _next();
      }
      return;
    }
    scores[cur] = rem;
    if (rem == 0) {
      winner = names[cur];
      return;
    }
    if (darts.length == 3) {
      if (hold) {
        held = true;
      } else {
        _next();
      }
    }
  }

  void _next() {
    last[cur] = darts;
    cur = (cur + 1) % names.length;
    darts = [];
    turnStart = scores[cur];
  }

  final hist = <List<Object?>>[];
  void _save() => hist.add([
        List<int>.of(scores),
        List<int>.of(thrown),
        [for (final l in last) List<Dart>.of(l)],
        cur,
        turnStart,
        List<Dart>.of(darts),
        winner,
        msg,
        held
      ]);

  void confirmTurn() {
    if (held) {
      held = false;
      _next();
    }
  }

  void replace(int k, Dart d) {
    final ds = List<Dart>.of(darts);
    ds[k] = d;
    for (var i = ds.length - k; i > 0; i--) {
      undo();
    }
    for (final x in ds.skip(k)) {
      add(x);
    }
  }

  /// Nimmt den letzten Dart zurück, auch über den Spielerwechsel hinweg.
  void undo() {
    if (hist.isEmpty) return;
    final h = hist.removeLast();
    scores = h[0] as List<int>;
    thrown = h[1] as List<int>;
    last = h[2] as List<List<Dart>>;
    cur = h[3] as int;
    turnStart = h[4] as int;
    darts = h[5] as List<Dart>;
    winner = h[6] as String?;
    msg = h[7] as String?;
    held = h[8] as bool;
  }
}

// ---------- Checkout-Vorschläge ----------
final _all = <Dart>[
  for (var n = 20; n >= 1; n--) Dart(n, 3),
  for (var n = 20; n >= 1; n--) Dart(n, 2),
  for (var n = 20; n >= 1; n--) Dart(n, 1),
  const Dart(25, 2),
  const Dart(25, 1),
];
final _memo = <String, List<Dart>?>{};

int _cost(List<Dart> r, bool dbl) {
  const pref = [20, 16, 8, 10, 12, 18, 14, 6, 4, 2, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
  var c = 0;
  for (var i = 0; i < r.length; i++) {
    final d = r[i];
    if (i < r.length - 1) {
      if (d.m == 3 && d.n < 17) c += 10;
      if (d.m == 2) c += 6;
    } else if (dbl) {
      c += d.n == 25 ? 12 : pref.indexOf(d.n);
    } else {
      c += d.m == 1 ? 0 : d.m == 2 ? 1 : 3;
    }
  }
  return c;
}

/// Kürzester Weg auf 0 mit höchstens [left] Darts (bei Double-Out: letzter Dart ein Double).
List<Dart>? checkout(int rem, bool dbl, int left) {
  return _memo.putIfAbsent('$rem$dbl$left', () {
    for (var n = 1; n <= left; n++) {
      List<Dart>? best;
      var bc = 1 << 30;
      void go(int r, List<Dart> acc) {
        final k = n - acc.length;
        if (k == 1) {
          for (final d in _all) {
            if (d.points == r && (!dbl || d.m == 2)) {
              final route = [...acc, d];
              final c = _cost(route, dbl);
              if (c < bc) {
                bc = c;
                best = route;
              }
            }
          }
          return;
        }
        for (final d in _all) {
          final r2 = r - d.points;
          if (r2 < (dbl ? 2 : 1) || r2 > 60 * (k - 1)) continue;
          go(r2, [...acc, d]);
        }
      }

      go(rem, []);
      if (best != null) return best;
    }
    return null;
  });
}

// ---------- Setup ----------
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupState();
}

class _SetupState extends State<SetupPage> {
  int players = 2, start = 501;
  bool dbl = true;
  final ctr = [for (var i = 1; i <= 4; i++) TextEditingController(text: 'Spieler $i')];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final n = p.getStringList('names');
      setState(() {
        players = p.getInt('players') ?? players;
        start = p.getInt('start') ?? start;
        dbl = p.getBool('dbl') ?? dbl;
        if (n != null) {
          for (var i = 0; i < n.length && i < 4; i++) {
            ctr[i].text = n[i];
          }
        }
      });
    });
  }

  Future<void> _saveSetup() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('players', players);
    await p.setInt('start', start);
    await p.setBool('dbl', dbl);
    await p.setStringList('names', [for (final t in ctr) t.text]);
  }

  void _settings(BuildContext c) => showModalBottomSheet(
      context: c,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                    title: const Text('Helles Design'),
                    value: !darkMode.value,
                    onChanged: (v) async {
                      darkMode.value = !v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('dark', !v);
                    }),
                SwitchListTile(
                    title: const Text('Vibration'),
                    value: vibOn.value,
                    onChanged: (v) async {
                      vibOn.value = v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('vib', v);
                    }),
                SwitchListTile(
                    title: const Text('Ton'),
                    value: soundOn.value,
                    onChanged: (v) async {
                      soundOn.value = v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('snd', v);
                    }),
                SwitchListTile(
                    title: const Text('Auto-Feinabgleich der Scheibe'),
                    value: autoFit.value,
                    onChanged: (v) async {
                      autoFit.value = v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('fit', v);
                    }),
                SwitchListTile(
                    title: const Text('Diagnose-Modus'),
                    subtitle: const Text('zeigt erkannte Flecken und Gründe'),
                    value: diagOn.value,
                    onChanged: (v) async {
                      diagOn.value = v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('diag', v);
                    }),
                ListTile(
                    leading: const Icon(Icons.crop_free),
                    title: const Text('Kalibrierung zurücksetzen'),
                    onTap: () {
                      calib = [];
                      saveCalib();
                      Navigator.pop(c);
                    }),
              ]))));

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (c, _, __) => Scaffold(
        appBar: AppBar(title: const Text('STANDART'), actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => _settings(c))
        ]),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Expanded(
                child: ListView(children: [
              Text('SPIELER', style: TextStyle(letterSpacing: 2, color: kDim)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                  segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))],
                  selected: {players},
                  onSelectionChanged: (s) => setState(() => players = s.first)),
              const SizedBox(height: 16),
              for (var i = 0; i < players; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                        controller: ctr[i],
                        decoration: InputDecoration(
                            labelText: 'Name ${i + 1}',
                            prefixIcon: Icon(Icons.circle, color: teamColors[i], size: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))))),
              const SizedBox(height: 10),
              Text('STARTPUNKTE', style: TextStyle(letterSpacing: 2, color: kDim)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 301, label: Text('301')),
                    ButtonSegment(value: 501, label: Text('501')),
                    ButtonSegment(value: 701, label: Text('701'))
                  ],
                  selected: {start},
                  onSelectionChanged: (s) => setState(() => start = s.first)),
              SwitchListTile(title: const Text('Double-Out'), value: dbl, onChanged: (v) => setState(() => dbl = v)),
            ])),
            FilledButton(
                onPressed: () {
                  _saveSetup();
                  Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => GamePage(Game([
                              for (var i = 0; i < players; i++)
                                ctr[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctr[i].text.trim()
                            ], start, dbl))));
                },
                child: const Text('Spiel starten')),
          ]),
        ),
      ));
}

// ---------- Kalibrierung / Perspektive ----------
/// Normierte Kalibrierpunkte (0..1) im Kamerabild: Außenrand Doppelring bei 20|1, 6|10, 3|19, 11|14
List<Offset> calib = [];
final boardPts = [
  for (final a in [9, 99, 189, 279]) Offset(sin(a * pi / 180), -cos(a * pi / 180))
];
const calibNames = ['20|1 (oben)', '6|10 (rechts)', '3|19 (unten)', '11|14 (links)'];

List<double> homography(List<Offset> s, List<Offset> d) {
  final m = List.generate(8, (_) => List.filled(9, 0.0));
  for (var i = 0; i < 4; i++) {
    final x = s[i].dx, y = s[i].dy, u = d[i].dx, v = d[i].dy;
    m[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    m[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }
  for (var c = 0; c < 8; c++) {
    var p = c;
    for (var r = c + 1; r < 8; r++) {
      if (m[r][c].abs() > m[p][c].abs()) p = r;
    }
    final t = m[c];
    m[c] = m[p];
    m[p] = t;
    for (var r = 0; r < 8; r++) {
      if (r == c) continue;
      final f = m[r][c] / m[c][c];
      for (var k = c; k < 9; k++) {
        m[r][k] -= f * m[c][k];
      }
    }
  }
  return [for (var i = 0; i < 8; i++) m[i][8] / m[i][i]];
}

Offset apply(List<double> h, double x, double y) {
  final k = h[6] * x + h[7] * y + 1;
  return Offset((h[0] * x + h[1] * y + h[2]) / k, (h[3] * x + h[4] * y + h[5]) / k);
}

class Gray {
  final int w, h, ow, oh; // Größe + Originalgröße
  final Uint8List d;
  Gray(this.w, this.h, this.ow, this.oh, this.d);
}

/// Kantenbild in halber Auflösung (unabhängig von der Helligkeit).
Gray edges(img.Image im) {
  const f = 2;
  final w = im.width ~/ f, h = im.height ~/ f;
  final g = Uint8List(w * h), e = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      g[y * w + x] = im.getPixel(x * f, y * f).luminance.toInt();
    }
  }
  for (var y = 0; y < h - 1; y++) {
    for (var x = 0; x < w - 1; x++) {
      final v = (g[y * w + x + 1] - g[y * w + x]).abs() + (g[(y + 1) * w + x] - g[y * w + x]).abs();
      e[y * w + x] = v > 255 ? 255 : v;
    }
  }
  return Gray(w, h, im.width, im.height, e);
}

/// Wie weit (Originalpixel) hat sich das Bild [cur] gegenüber [ref] verschoben? null = unsicher.
Offset? align(Gray ref, Gray cur, List<Offset> pts) {
  var x0 = 1.0, y0 = 1.0, x1 = 0.0, y1 = 0.0;
  for (final p in pts) {
    x0 = min(x0, p.dx);
    x1 = max(x1, p.dx);
    y0 = min(y0, p.dy);
    y1 = max(y1, p.dy);
  }
  const R = 20, st = 3;
  final cx = (x0 + x1) / 2 * ref.w, cy = (y0 + y1) / 2 * ref.h;
  final hw = (x1 - x0) * ref.w * 0.75, hh = (y1 - y0) * ref.h * 0.75;
  final rx0 = max(R.toDouble(), cx - hw).toInt(), rx1 = min(ref.w - R - 2.0, cx + hw).toInt();
  final ry0 = max(R.toDouble(), cy - hh).toInt(), ry1 = min(ref.h - R - 2.0, cy + hh).toInt();
  if (rx1 - rx0 < 40 || ry1 - ry0 < 40) return null;
  var best = 1 << 60, bx = 0, by = 0;
  for (var dy = -R; dy <= R; dy++) {
    for (var dx = -R; dx <= R; dx++) {
      var sad = 0;
      for (var y = ry0; y < ry1; y += st) {
        final ro = y * ref.w, co = (y + dy) * cur.w + dx;
        for (var x = rx0; x < rx1; x += st) {
          sad += (ref.d[ro + x] - cur.d[co + x]).abs();
        }
      }
      if (sad < best) {
        best = sad;
        bx = dx;
        by = dy;
      }
    }
  }
  if (bx.abs() >= R || by.abs() >= R) return null;
  return Offset(bx * 2.0, by * 2.0);
}

/// Wackel-tolerant: kleinster Unterschied zu Pixeln im Umkreis von 2 px im Referenzbild.
double _wob(Uint8List a, Uint8List b, int w, int h, int x, int y, double shift) {
  final i = (y * w + x) * 3;
  var best = 1e9;
  for (var oy = -2; oy <= 2; oy += 2) {
    final yy = y + oy;
    if (yy < 0 || yy >= h) continue;
    for (var ox = -2; ox <= 2; ox += 2) {
      final xx = x + ox;
      if (xx < 0 || xx >= w) continue;
      final j = (yy * w + xx) * 3;
      final d = ((b[i] - shift - a[j]).abs() + (b[i + 1] - shift - a[j + 1]).abs() + (b[i + 2] - shift - a[j + 2]).abs()) / 3;
      if (d < best) best = d;
    }
  }
  return best;
}

/// Mittlere Helligkeitsänderung zwischen zwei Bildern (Bewegung im Bild?)
double motion(img.Image a, img.Image b) {
  var s = 0.0, n = 0;
  for (var y = 0; y < a.height && y < b.height; y += 12) {
    for (var x = 0; x < a.width && x < b.width; x += 12) {
      s += (a.getPixel(x, y).luminance - b.getPixel(x, y).luminance).abs();
      n++;
    }
  }
  return s / n;
}

/// Feinabgleich: die 4 Punkte werden in kleinen Schritten (max. 4 px) verschoben, bis die
/// gezeichneten Ringe am besten auf starken Kanten liegen. Nur übernommen, wenn es klar besser wird.
List<Offset> refineCalib(Gray g, List<Offset> start) {
  double score(List<Offset> p) {
    final hb = homography(boardPts, p);
    var sum = 0.0;
    for (final r in [1.0, 0.953, 0.629, 0.582]) {
      for (var i = 0; i < 90; i++) {
        final t = i * 4 * pi / 180;
        final q = apply(hb, r * sin(t), -r * cos(t));
        final x = (q.dx * g.w).round(), y = (q.dy * g.h).round();
        if (x < 1 || y < 1 || x >= g.w - 1 || y >= g.h - 1) continue;
        sum += g.d[y * g.w + x];
      }
    }
    return sum;
  }

  var best = List<Offset>.of(start);
  var bs = score(best);
  final s0 = bs;
  for (var iter = 0; iter < 12; iter++) {
    var improved = false;
    for (var i = 0; i < 4; i++) {
      for (final dx in [-1, 0, 1]) {
        for (final dy in [-1, 0, 1]) {
          if (dx == 0 && dy == 0) continue;
          final cand = List<Offset>.of(best);
          cand[i] = Offset(cand[i].dx + dx / g.w, cand[i].dy + dy / g.h);
          if ((cand[i].dx - start[i].dx).abs() * g.w > 4 || (cand[i].dy - start[i].dy).abs() * g.h > 4) continue;
          final sc = score(cand);
          if (sc > bs) {
            bs = sc;
            best = cand;
            improved = true;
          }
        }
      }
    }
    if (!improved) break;
  }
  return bs > s0 * 1.03 ? best : start;
}

class Det {
  final Dart dart;
  final Offset tip, board;
  final int area;
  final List<Offset> blob;
  Det(this.dart, this.tip, this.board, this.area, this.blob);
}

/// Neuer Dart = größter veränderter Bereich im Board. Die Spitze ist das schmale Ende
/// (die Flights sind breit) und wird per Homographie auf die Scheibe abgebildet.
Det? detect(img.Image a, img.Image b) {
  final w = min(a.width, b.width), h = min(a.height, b.height);
  final pix = [for (final o in calib) Offset(o.dx * w, o.dy * h)];
  final hm = homography(pix, boardPts), hb = homography(boardPts, pix);
  var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (var i = 0; i < 72; i++) {
    final t = i * 5 * pi / 180;
    final p = apply(hb, 1.2 * sin(t), -1.2 * cos(t));
    x0 = min(x0, p.dx);
    x1 = max(x1, p.dx);
    y0 = min(y0, p.dy);
    y1 = max(y1, p.dy);
  }
  final X0 = max(0, x0.floor()), Y0 = max(0, y0.floor());
  final bw = min(w - 1, x1.ceil()) - X0 + 1, bh = min(h - 1, y1.ceil()) - Y0 + 1;
  if (bw < 50 || bh < 50) {
    diagWhy = 'Scheibenbereich zu klein';
    return null;
  }
  final ra = Uint8List(bw * bh * 3), rb = Uint8List(bw * bh * 3);
  var sa = 0.0, sb = 0.0;
  for (var y = 0; y < bh; y++) {
    for (var x = 0; x < bw; x++) {
      final pa = a.getPixel(X0 + x, Y0 + y), pb = b.getPixel(X0 + x, Y0 + y);
      final i = (y * bw + x) * 3;
      ra[i] = pa.r.toInt();
      ra[i + 1] = pa.g.toInt();
      ra[i + 2] = pa.b.toInt();
      rb[i] = pb.r.toInt();
      rb[i + 1] = pb.g.toInt();
      rb[i + 2] = pb.b.toInt();
      sa += ra[i] + ra[i + 1] + ra[i + 2];
      sb += rb[i] + rb[i + 1] + rb[i + 2];
    }
  }
  final shift = (sb - sa) / (bw * bh * 3); // globale Helligkeitsänderung ignorieren
  const f = 3;
  final gw = (bw + f - 1) ~/ f, gh = (bh + f - 1) ~/ f;
  final cnt = List.filled(gw * gh, 0);
  final cand = <int>[];
  for (var y = 0; y < bh; y++) {
    for (var x = 0; x < bw; x++) {
      if (_wob(ra, rb, bw, bh, x, y, shift) > 24) {
        final p = apply(hm, (X0 + x).toDouble(), (Y0 + y).toDouble());
        if (p.distance < 1.2) {
          cand.add(y * bw + x);
          cnt[(y ~/ f) * gw + x ~/ f]++;
        }
      }
    }
  }
  final label = List.filled(gw * gh, 0);
  var id = 0, bestId = 0, bestN = 0;
  for (var s = 0; s < gw * gh; s++) {
    if (cnt[s] == 0 || label[s] != 0) continue;
    id++;
    var n = 0;
    final q = [s];
    label[s] = id;
    while (q.isNotEmpty) {
      final c = q.removeLast();
      n += cnt[c];
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = c % gw + dx, ny = c ~/ gw + dy;
          if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
          final ni = ny * gw + nx;
          if (cnt[ni] > 0 && label[ni] == 0) {
            label[ni] = id;
            q.add(ni);
          }
        }
      }
    }
    if (n > bestN) {
      bestN = n;
      bestId = id;
    }
  }
  if (bestN < 25 || bestN > 0.06 * bw * bh) {
    diagWhy = bestN < 25 ? 'nichts Neues ($bestN px)' : 'Fleck zu groß – Hand? ($bestN px)';
    return null;
  }
  final pts = <Offset>[];
  for (final i in cand) {
    final x = i % bw, y = i ~/ bw;
    if (label[(y ~/ f) * gw + x ~/ f] == bestId) pts.add(Offset(x + X0.toDouble(), y + Y0.toDouble()));
  }
  var mx = 0.0, my = 0.0;
  for (final p in pts) {
    mx += p.dx;
    my += p.dy;
  }
  mx /= pts.length;
  my /= pts.length;
  var sxx = 0.0, sxy = 0.0, syy = 0.0;
  for (final p in pts) {
    final u = p.dx - mx, v = p.dy - my;
    sxx += u * u;
    sxy += u * v;
    syy += v * v;
  }
  final th = 0.5 * atan2(2 * sxy, sxx - syy);
  final ax = cos(th), ay = sin(th);
  double tt(Offset p) => (p.dx - mx) * ax + (p.dy - my) * ay;
  pts.sort((p, q) => tt(p).compareTo(tt(q)));
  final lo = tt(pts.first), hi = tt(pts.last), len = hi - lo;
  if (len > 0.6 * (bw / 2.4)) {
    diagWhy = 'Fleck zu lang (${len.toInt()} px) – Ringkante/Hand?';
    return null;
  }
  var nLo = 0, nHi = 0;
  for (final p in pts) {
    final t = tt(p);
    if (t < lo + 0.3 * len) nLo++;
    if (t > hi - 0.3 * len) nHi++;
  }
  final k = max(3, pts.length ~/ 25);
  final end = len < 12 ? pts : (nLo < nHi ? pts.take(k) : pts.skip(pts.length - k)).toList();
  final tip = end.reduce((p, q) => p + q) / end.length.toDouble();
  final bp = apply(hm, tip.dx, tip.dy);
  return Det(fromBoard(bp.dx, bp.dy), tip, bp, pts.length,
      [for (var i = 0; i < pts.length; i += max(1, pts.length ~/ 300)) pts[i]]);
}

// ---------- Spiel ----------
class GamePage extends StatefulWidget {
  final Game g;
  const GamePage(this.g, {super.key});
  @override
  State<GamePage> createState() => _GameState();
}

class _GameState extends State<GamePage> {
  Game get g => widget.g;
  CameraController? ctrl;
  img.Image? base;
  bool armed = false, auto = true, busy = false;
  Det? pending;
  Offset? tip;
  List<Offset> blob = [];
  bool locked = false;
  img.Image? prev;
  bool manual = false;
  int mult = 1;
  final pc = PageController(initialPage: 1);
  int? drag;
  int seen = 0;
  Gray? refG;
  List<Offset>? refCalib;
  bool calDirty = true;
  String info = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    info = calib.length < 4
        ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an'
        : '${g.names[g.cur]} antippen, um zu starten';
    g.hold = true;
    availableCameras().then((cams) async {
      final cc = CameraController(cams.first, ResolutionPreset.veryHigh, enableAudio: false);
      await cc.initialize();
      try {
        await cc.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (mounted) setState(() => ctrl = cc);
    });
    timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    ctrl?.dispose();
    super.dispose();
  }

  Future<img.Image?> _shot() async {
    final f = await ctrl!.takePicture();
    var im = img.decodeImage(await f.readAsBytes());
    if (im == null) return null;
    return img.copyResize(img.bakeOrientation(im), width: 960);
  }

  void _add(Dart d) {
    feedback();
    setState(() {
      g.add(d);
      if (g.winner != null) {
        info = 'Gewonnen!';
      } else if (g.held) {
        armed = false;
        base = null;
        info = 'Zug beendet. Darts antippen = ändern. Darts ziehen, dann ${g.names[(g.cur + 1) % g.names.length]} antippen.';
      } else if (g.darts.isEmpty) {
        armed = false;
        base = null;
        info = manual ? '' : '${g.msg ?? ''} Darts ziehen, dann ${g.names[g.cur]} antippen.';
      } else {
        info = 'Erkannt: ${d.label}';
      }
    });
  }

  Future<void> _arm() async {
    if (ctrl == null || busy) return;
    if (calib.length < 4) {
      setState(() => info = 'Erst kalibrieren (4 Punkte im Bild antippen)');
      return;
    }
    busy = true;
    try {
      if (!locked) {
        // Fokus/Belichtung nur einmal sperren, danach kein Warten mehr beim Zugwechsel
        try {
          await ctrl!.setExposureMode(ExposureMode.auto);
          await ctrl!.setFocusMode(FocusMode.auto);
          await Future.delayed(const Duration(milliseconds: 800));
          await ctrl!.setExposureMode(ExposureMode.locked);
          await ctrl!.setFocusMode(FocusMode.locked);
        } catch (_) {}
        locked = true;
      }
      base = await _shot();
      var note = '';
      final cur = edges(base!);
      if (calDirty || refG == null || refCalib == null) {
        if (autoFit.value) {
          final r = refineCalib(cur, calib);
          if (!identical(r, calib)) {
            calib = r;
            note = ' (Scheibe fein justiert)';
            saveCalib();
          }
        }
        refG = cur; // Referenz für das automatische Nachführen
        refCalib = List.of(calib);
        calDirty = false;
      } else {
        final sh = align(refG!, cur, refCalib!);
        if (sh != null) {
          calib = [for (final p in refCalib!) p + Offset(sh.dx / cur.ow, sh.dy / cur.oh)];
          if (autoFit.value) calib = refineCalib(cur, calib);
          note = ' (Scheibe nachgeführt: ${sh.dx.toInt()}/${sh.dy.toInt()} px)';
        } else {
          note = ' (Ausrichtung unsicher – ggf. neu kalibrieren)';
        }
      }
      pending = null;
      prev = null;
      seen = 0;
      armed = true;
      info = 'Bereit – ${g.names[g.cur]} wirft$note';
      feedback();
    } catch (e) {
      info = 'Fehler: $e';
    }
    busy = false;
    if (mounted) setState(() {});
  }

  /// Auto-Erkennung: Position muss in zwei Aufnahmen hintereinander (fast) gleich sein.
  Future<void> _tick() async {
    if (manual || !auto || !armed || busy || ctrl == null || base == null || g.winner != null) return;
    busy = true;
    try {
      final now = await _shot();
      if (now == null) return;
      final moving = prev != null && motion(prev!, now) > 3; // Hand/Dart noch in Bewegung
      prev = now;
      if (moving) {
        pending = null;
        seen = 0;
        return;
      }
      final d = detect(base!, now);
      if (d == null) {
        pending = null;
        seen = 0;
        if (diagOn.value && mounted) {
          setState(() {
            info = 'Kein Dart: $diagWhy';
            blob = [];
          });
        }
      } else {
        seen++;
        if (mounted) {
          setState(() {
            tip = Offset(d.tip.dx / now.width, d.tip.dy / now.height);
            blob = [for (final o in d.blob) Offset(o.dx / now.width, o.dy / now.height)];
            info = 'Blob ${d.area}px → ${d.dart.label}';
          });
        }
        if (pending != null && (pending!.board - d.board).distance < 0.10) {
          pending = null;
          seen = 0;
          base = now;
          _add(d.dart);
        } else {
          pending = d;
        }
      }
    } catch (e) {
      info = 'Fehler: $e';
    } finally {
      busy = false;
    }
  }

  void _calibTap(Offset p, Size s) {
    if (calib.length >= 4) return;
    setState(() {
      calDirty = true;
      calib.add(Offset(p.dx / s.width, p.dy / s.height));
      info = calib.length < 4
          ? 'Weiter: ${calibNames[calib.length]}'
          : 'Kalibriert (Punkte lassen sich verschieben). ${g.names[g.cur]} antippen.';
      if (calib.length == 4) saveCalib();
    });
  }

  void _panStart(Offset p, Size s) {
    int? best;
    var bd = 70.0;
    for (var i = 0; i < calib.length; i++) {
      final dd = (Offset(calib[i].dx * s.width, calib[i].dy * s.height) - p).distance;
      if (dd < bd) {
        bd = dd;
        best = i;
      }
    }
    drag = best;
  }

  /// Feinjustierung: der Punkt bewegt sich nur halb so weit wie der Finger.
  void _panUpdate(Offset delta, Size s) {
    final i = drag;
    if (i == null) return;
    setState(() {
      calDirty = true;
      final o = calib[i];
      calib[i] = Offset((o.dx + delta.dx * 0.5 / s.width).clamp(0.0, 1.0).toDouble(),
          (o.dy + delta.dy * 0.5 / s.height).clamp(0.0, 1.0).toDouble());
    });
  }

  Widget _keys(void Function(Dart) onPick, void Function(VoidCallback) refresh, String lastLabel, VoidCallback onLast) {
    Widget key(String t, VoidCallback f, {bool sel = false}) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: sel ? kOnAccent : kInk,
                    backgroundColor: sel ? kAccent : null,
                    side: BorderSide(color: sel ? kAccent : kLine, width: 1.5)),
                onPressed: f,
                child: FittedBox(child: Text(t, style: const TextStyle(fontSize: 20))))));
    Widget row(List<Widget> k) => Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: k));
    return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          row([
            key('SINGLE', () => refresh(() => mult = 1), sel: mult == 1),
            key('DOUBLE', () => refresh(() => mult = 2), sel: mult == 2),
            key('TRIPLE', () => refresh(() => mult = 3), sel: mult == 3),
          ]),
          for (var r = 0; r < 5; r++)
            row([for (var i = 1; i <= 4; i++) key('${r * 4 + i}', () => onPick(Dart(r * 4 + i, mult)))]),
          row([
            key('S-BULL', () => onPick(const Dart(25, 1))),
            key('D-BULL', () => onPick(const Dart(25, 2))),
            key('OUT', () => onPick(const Dart(0, 1))),
            key(lastLabel, onLast),
          ]),
        ]));
  }

  void _edit(int k) => showModalBottomSheet(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => SizedBox(
              height: 430,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('DART ${k + 1} ÄNDERN (jetzt ${g.darts[k].label})', style: TextStyle(color: kViolet))),
                Expanded(
                    child: _keys((d) {
                  Navigator.pop(c);
                  mult = 1;
                  setState(() => g.replace(k, d));
                }, set, '✕', () => Navigator.pop(c))),
              ]))));

  void _tips() => showDialog(
      context: context,
      builder: (c) => AlertDialog(
              title: const Text('TIPPS FÜR DIE KAMERA'),
              content: const SingleChildScrollView(
                  child: Text('• Winkel: etwa 20–35° seitlich zur Scheibe, auf Höhe der Scheibenmitte. So sieht man die Darts von der Seite statt von hinten oder von vorn.\n'
                      '• Handy fest aufstellen und nicht berühren. Das Board muss an der Wand fest sein, ein Wackeln beim Treffer stört die Erkennung am meisten.\n'
                      '• Gleichmäßig von vorn beleuchten, kein Gegenlicht, keine Schatten vom Werfer.\n'
                      '• Alle vier Kalibrierpunkte genau auf den Außenrand des Doppelrings setzen. Sie lassen sich ziehen.\n'
                      '• Nach dem Wurf Hand und Dart kurz ruhig lassen, bis der Dart erkannt ist.\n'
                      '• Zugende: Darts prüfen (antippen = ändern), Darts ziehen, dann den nächsten Spieler antippen.')),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));

  Widget _card(int i) {
    final col = teamColors[i % teamColors.length];
    final cur = i == g.cur;
    final ds = cur ? g.darts : g.last[i];
    final nextI = (g.cur + 1) % g.names.length;
    final canEdit = cur && g.held && !manual;
    return Expanded(
        child: GestureDetector(
            onTap: () {
              if (manual || g.winner != null) return;
              if (g.held) {
                if (i == nextI) {
                  setState(g.confirmTurn);
                  _arm();
                }
              } else if (cur) {
                _arm();
              }
            },
            child: Container(
                margin: const EdgeInsets.fromLTRB(5, 5, 9, 9),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cur || (g.held && i == nextI) ? col : kLine, width: cur ? 2 : 1.5),
                    boxShadow: cur ? [BoxShadow(color: col, offset: const Offset(4, 4))] : null),
                child: Column(children: [
                  Text('${cur && armed ? '● ' : ''}${g.names[i].toUpperCase()}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 2, color: col)),
                  const SizedBox(height: 4),
                  FittedBox(child: DotNum('${g.scores[i]}', kInk)),
                  Text('Ø ${g.avg(i)}', style: TextStyle(fontSize: 12, color: kDim)),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var k = 0; k < 3; k++)
                      Expanded(
                          child: GestureDetector(
                              onTap: canEdit && k < ds.length ? () => _edit(k) : null,
                              child: Container(
                                  height: 26,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: canEdit && k < ds.length ? col : kLine)),
                                  child: k < ds.length
                                      ? FittedBox(child: Text(ds[k].label, style: TextStyle(fontSize: 12, color: kInk)))
                                      : null))),
                  ]),
                ]))));
  }

  Widget _win(BuildContext c) => WinScreen(
      g: g,
      onUndo: () => setState(g.undo),
      onRematch: () => Navigator.pushReplacement(
          c, MaterialPageRoute(builder: (_) => GamePage(Game(g.names, g.start, g.dbl)))),
      onMenu: () => Navigator.pop(c));

  Widget _cameraPage(CameraController? cc) => Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(info, textAlign: TextAlign.center)),
        Expanded(
            child: cc == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                        aspectRatio: 1 / cc.value.aspectRatio,
                        child: LayoutBuilder(builder: (_, k) {
                          final sz = Size(k.maxWidth, k.maxHeight);
                          // Listener statt Pan: Punkte ziehen, aber Wischen zwischen den Seiten bleibt möglich
                          return Listener(
                              onPointerDown: (e) => setState(() => _panStart(e.localPosition, sz)),
                              onPointerMove: (e) => _panUpdate(e.delta, sz),
                              onPointerUp: (_) {
                                if (drag != null) saveCalib();
                                setState(() => drag = null);
                              },
                              onPointerCancel: (_) => setState(() => drag = null),
                              child: GestureDetector(
                                  onTapUp: (t) => _calibTap(t.localPosition, sz),
                                  child: Stack(fit: StackFit.expand, children: [
                                    CameraPreview(cc),
                                    CustomPaint(painter: _Overlay(List.of(calib), tip, diagOn.value ? blob : const [])),
                                  ])));
                        })))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => setState(g.undo), icon: const Icon(Icons.undo), label: const Text('Undo'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                          calib = [];
                          saveCalib();
                          calDirty = true;
                          armed = false;
                          info = 'Kalibrieren: ${calibNames[0]} antippen';
                        }),
                    icon: const Icon(Icons.crop_free),
                    label: const Text('Kalib.'))),
            IconButton(icon: const Icon(Icons.info_outline), onPressed: _tips),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext c) {
    if (g.winner != null) return _win(c);
    final rem = g.scores[g.cur];
    final route = rem <= (g.dbl ? 170 : 180) ? checkout(rem, g.dbl, 3 - g.darts.length) : null;
    Widget pill(int i, String t) {
      final on = (manual ? 0 : 1) == i;
      return GestureDetector(
          onTap: () => pc.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
          child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: on ? kAccent.withOpacity(.15) : null,
                  border: Border.all(color: on ? kAccent : kLine)),
              child: Text(t, style: const TextStyle(fontSize: 11, letterSpacing: 2))));
    }

    return Scaffold(
      appBar: AppBar(title: Text('DRAN: ${g.names[g.cur].toUpperCase()}'), actions: [
        if (!manual) const Text('Auto'),
        if (!manual) Switch(value: auto, onChanged: (v) => setState(() => auto = v)),
      ]),
      body: Column(children: [
        SizedBox(
            height: 180,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < g.names.length; i++) _card(i)
            ])),
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (g.msg != null)
                const Text('BUST   ', style: TextStyle(color: Color(0xFFFF6B8A), letterSpacing: 2, fontSize: 14)),
              if (route != null) ...[
                Text('CHECKOUT  ', style: TextStyle(color: kDim, letterSpacing: 2, fontSize: 11)),
                Text(route.map((d) => d.label).join(' · '), style: TextStyle(color: kViolet, fontSize: 18)),
              ],
            ])),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [pill(0, 'MANUELL'), pill(1, 'KAMERA')]),
        Expanded(
            child: PageView(
          controller: pc,
          physics: drag != null ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          onPageChanged: (i) => setState(() {
            manual = i == 0;
            g.hold = !manual;
            if (manual) g.confirmTurn();
            if (!manual) {
              armed = false;
              base = null;
              pending = null;
              info = '${g.names[g.cur]} antippen für Referenzbild';
            }
          }),
          children: [_keys((d) {
            mult = 1;
            _add(d);
          }, setState, '↶', () => setState(g.undo)), _cameraPage(ctrl)],
        )),
      ]),
    );
  }
}

// ---------- Design-Bausteine ----------
/// Dezentes Punktraster im Hintergrund (Nothing-Stil)
class _Dots extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final pts = <Offset>[
      for (var y = 10.0; y < s.height; y += 16)
        for (var x = 10.0; x < s.width; x += 16) Offset(x, y)
    ];
    c.drawPoints(PointMode.points, pts,
        Paint()..color = kInk.withOpacity(.07)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_) => true;
}

const _glyph = {
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '–': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  't': ['01000', '01000', '11110', '01000', '01000', '01001', '00110'],
  'a': ['00000', '00000', '01110', '00001', '01111', '10001', '01111'],
  'n': ['00000', '00000', '10110', '11001', '10001', '10001', '10001'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'r': ['00000', '00000', '10110', '11001', '10000', '10000', '10000'],
};

/// Text als Punktmatrix-Anzeige (5x7), unbelegte Punkte schwach sichtbar; reveal = spaltenweises Aufleuchten
class DotNum extends StatelessWidget {
  final String text;
  final Color color;
  final double u, reveal;
  final bool multi;
  const DotNum(this.text, this.color, {super.key, this.u = 8, this.reveal = 1, this.multi = false});
  @override
  Widget build(BuildContext c) =>
      CustomPaint(size: Size(text.length * 6 * u - u, 7 * u), painter: _DotNum(text, color, u, reveal, multi));
}

class _DotNum extends CustomPainter {
  final String text;
  final Color color;
  final double u, reveal;
  final bool multi;
  _DotNum(this.text, this.color, this.u, this.reveal, this.multi);
  @override
  void paint(Canvas c, Size s) {
    final lit = reveal * text.length * 6;
    for (var i = 0; i < text.length; i++) {
      final col = multi ? teamColors[i % teamColors.length] : color;
      final on = Paint()..color = col, off = Paint()..color = col.withOpacity(.10);
      final g = _glyph[text[i]] ?? _glyph['–']!;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 5; x++) {
          final isOn = g[y][x] == '1' && i * 6 + x <= lit;
          c.drawCircle(Offset(i * 6 * u + x * u + u / 2, y * u + u / 2), u * .36, isOn ? on : off);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotNum o) => o.text != text || o.color != color || o.reveal != reveal;
}

/// Sieger: blinkender Titel, Name springt ein, Pixel-Konfetti in Teamfarbe
class WinScreen extends StatefulWidget {
  final Game g;
  final VoidCallback onUndo, onRematch, onMenu;
  const WinScreen({super.key, required this.g, required this.onUndo, required this.onRematch, required this.onMenu});
  @override
  State<WinScreen> createState() => _WinState();
}

class _WinState extends State<WinScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final g = widget.g, col = teamColors[g.cur % teamColors.length];
    Widget btn(String t, VoidCallback f) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(4),
            child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: f,
                child: FittedBox(child: Text(t)))));
    return Scaffold(
        backgroundColor: col,
        body: Stack(children: [
          Positioned.fill(
              child: AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: _Confetti(ac.value)))),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Spacer(),
                    AnimatedBuilder(
                        animation: ac,
                        builder: (_, __) => Opacity(
                            opacity: (ac.value * 10).floor() % 2 == 0 ? 1 : .3,
                            child: const Text('★ GEWINNER ★',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black, letterSpacing: 6, fontSize: 18)))),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: FittedBox(
                            child: Text(g.winner!.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))])))),
                    const SizedBox(height: 28),
                    for (var i = 0; i < g.names.length; i++)
                      Text('${g.names[i]}   Ø ${g.avg(i)}   ${g.thrown[i]} Darts',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.6)),
                    const Spacer(),
                    Row(children: [btn('ZURÜCK', widget.onUndo), btn('REVANCHE', widget.onRematch), btn('MENÜ', widget.onMenu)]),
                  ]))),
        ]));
  }
}

class _Confetti extends CustomPainter {
  final double t;
  _Confetti(this.t);
  @override
  void paint(Canvas c, Size s) {
    final cols = [Colors.white, Colors.black, kViolet, kAccent, Color(0xFFFF5FA2), Color(0xFFFFD23F)];
    const n = 48;
    for (var i = 0; i < n; i++) {
      final x = (i * 0.618034 % 1) * s.width;
      final y = ((t * (1 + i % 2) + i / n) % 1) * (s.height + 20) - 10;
      final sz = 6.0 + (i % 3) * 4;
      c.drawRect(Rect.fromLTWH(x, y, sz, sz), Paint()..color = cols[i % cols.length].withOpacity(.85));
    }
  }

  @override
  bool shouldRepaint(_Confetti o) => o.t != t;
}

/// Logo: Punktmatrix-Scheibe in 90er-Farben mit hartem Schatten und Pfeil
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark(this.size, {super.key});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(size, size), painter: _Logo());
}

class _Logo extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final m = s.center(Offset.zero), R = s.width * .42;
    const radii = [1.0, .72, .46, .2];
    const counts = [36, 26, 16, 7];
    for (var pass = 0; pass < 2; pass++) {
      final sh = pass == 0 ? Offset(s.width * .035, s.width * .035) : Offset.zero;
      for (var r = 0; r < 4; r++) {
        final p = Paint()..color = pass == 0 ? kInk.withOpacity(.3) : teamColors[r];
        for (var k = 0; k < counts[r]; k++) {
          final a = k * 2 * pi / counts[r];
          c.drawCircle(m + sh + Offset(cos(a), sin(a)) * R * radii[r], s.width * .026, p);
        }
      }
      final ap = Paint()..color = pass == 0 ? kInk.withOpacity(.3) : kInk;
      for (var k = 0; k < 7; k++) {
        final t = k / 6;
        c.drawCircle(m + sh + Offset(R * 1.05 * (1 - t), -R * 1.05 * (1 - t)), s.width * (.018 + .012 * t), ap);
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

/// Kurzer Startbildschirm, Tippen überspringt
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashState();
}

class _SplashState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _go();
    })
    ..forward();
  bool gone = false;
  void _go() {
    if (gone || !mounted) return;
    gone = true;
    Navigator.pushReplacement(
        context,
        PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SetupPage(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 250)));
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _go,
      child: Scaffold(
          body: Center(
              child: AnimatedBuilder(
                  animation: ac,
                  builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
                        Opacity(opacity: min(1.0, ac.value * 4), child: const LogoMark(150)),
                        const SizedBox(height: 32),
                        FittedBox(child: DotNum('StanDart', kInk, u: 6, reveal: min(1.0, ac.value * 1.5), multi: true)),
                      ])))));
}

// ---------- Kamera-Overlay ----------
class _Overlay extends CustomPainter {
  final List<Offset> pts;
  final Offset? tip;
  final List<Offset> blob;
  _Overlay(this.pts, this.tip, this.blob);
  @override
  void paint(Canvas c, Size s) {
    final thick = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final thin = Paint()
      ..color = kAccent.withOpacity(.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    Offset sc(Offset o) => Offset(o.dx * s.width, o.dy * s.height);
    for (final o in pts) {
      c.drawCircle(sc(o), 7, thick);
    }
    if (pts.length == 4) {
      final hb = homography(boardPts, pts); // Board -> Bild (normiert)
      Offset at(double r, double deg) {
        final t = deg * pi / 180;
        return sc(apply(hb, r * sin(t), -r * cos(t)));
      }

      for (final r in [1.0, 0.953, 0.629, 0.582, 0.094, 0.037]) {
        final path = Path();
        for (var i = 0; i <= 72; i++) {
          final q = at(r, i * 5.0);
          i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
        }
        c.drawPath(path, r == 1.0 ? thick : thin);
      }
      for (var k = 0; k < 20; k++) {
        c.drawLine(at(0.094, 9.0 + 18 * k), at(1.0, 9.0 + 18 * k), thin);
        final tp = TextPainter(
            text: TextSpan(text: '${order[k]}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(c, at(1.1, 18.0 * k) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    final bp = Paint()..color = kViolet.withOpacity(.6);
    for (final o in blob) {
      c.drawCircle(sc(o), 1.6, bp);
    }
    if (tip != null) {
      c.drawCircle(sc(tip!), 6, Paint()..color = kViolet);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}