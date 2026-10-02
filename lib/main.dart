import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

const kAccent = Color(0xFF2DE2C8); // türkis
const kViolet = Color(0xFF9B7BFF);
const kLine = Color(0xFF2A2A2A);

void main() => runApp(MaterialApp(
    title: 'Dart Zähler',
    theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'monospace',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kViolet, surface: Colors.black),
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, color: Colors.white)),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF0D0D0D)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(52))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                foregroundColor: Colors.white,
                side: const BorderSide(color: kLine)))),
    home: const SetupPage()));

// ---------- Spiellogik ----------
const order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

class Dart {
  final int n, m; // n: 0=Fehl, 25=Bull; m: Multiplikator
  const Dart(this.n, this.m);
  int get points => n * m;
  String get label => n == 0
      ? 'Fehl'
      : n == 25
          ? (m == 2 ? 'Bull' : '25')
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
  late List<int> scores;
  int cur = 0, turnStart;
  List<Dart> darts = [];
  String? winner, msg;
  Game(this.names, this.start, this.dbl) : turnStart = start {
    scores = List.filled(names.length, start);
  }
  int _sum() => darts.fold<int>(0, (s, d) => s + d.points);
  void add(Dart d) {
    if (winner != null) return;
    msg = null;
    darts.add(d);
    final rem = turnStart - _sum();
    final bust = rem < 0 || (dbl && rem == 1) || (rem == 0 && dbl && d.m != 2);
    if (bust) {
      scores[cur] = turnStart;
      msg = 'Bust!';
      _next();
      return;
    }
    scores[cur] = rem;
    if (rem == 0) {
      winner = names[cur];
      return;
    }
    if (darts.length == 3) _next();
  }

  void _next() {
    cur = (cur + 1) % names.length;
    darts = [];
    turnStart = scores[cur];
  }

  void undo() {
    if (darts.isEmpty) return;
    winner = null;
    darts.removeLast();
    scores[cur] = turnStart - _sum();
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
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Dart Zähler')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Spieler'),
            SegmentedButton<int>(
                segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))],
                selected: {players},
                onSelectionChanged: (s) => setState(() => players = s.first)),
            const SizedBox(height: 20),
            const Text('Startpunkte'),
            SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 301, label: Text('301')),
                  ButtonSegment(value: 501, label: Text('501')),
                  ButtonSegment(value: 701, label: Text('701'))
                ],
                selected: {start},
                onSelectionChanged: (s) => setState(() => start = s.first)),
            SwitchListTile(
                title: const Text('Double-Out'),
                value: dbl,
                onChanged: (v) => setState(() => dbl = v)),
            const Spacer(),
            FilledButton(
                onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => GamePage(Game(
                            [for (var i = 1; i <= players; i++) 'Spieler $i'], start, dbl)))),
                child: const Text('Spiel starten')),
          ]),
        ),
      );
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

/// Findet die Spitze des neuen Darts. Bei schrägem Blick ragt der Dart zur Kamera hin
/// aus dem Board; die Spitze (Höhe 0) ist der Punkt des veränderten Bereichs, der
/// in Board-Koordinaten am nächsten zur Kamera liegt ("unten" im Bild = näher an der Kamera).
Dart? detect(img.Image a, img.Image b) {
  final w = min(a.width, b.width), h = min(a.height, b.height);
  final pix = [for (final o in calib) Offset(o.dx * w, o.dy * h)];
  final hm = homography(pix, boardPts), hb = homography(boardPts, pix);
  final c = apply(hb, 0, 0);
  final dn = apply(hm, c.dx, c.dy + 20);
  final dir = dn.distance < 1e-6 ? const Offset(0, 1) : dn / dn.distance;
  final pts = <Offset>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if ((a.getPixel(x, y).luminance - b.getPixel(x, y).luminance).abs() > 40) {
        final p = apply(hm, x.toDouble(), y.toDouble());
        if (p.distance < 1.3) pts.add(p);
      }
    }
  }
  if (pts.length < 30 || pts.length > 0.05 * w * h) return null; // nichts / Hand im Bild
  double sc(Offset p) => p.dx * dir.dx + p.dy * dir.dy;
  pts.sort((p, q) => sc(q).compareTo(sc(p)));
  final top = pts.take(max(8, pts.length ~/ 20)).toList();
  final t = top.reduce((p, q) => p + q) / top.length.toDouble();
  return fromBoard(t.dx, t.dy);
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
  Dart? pending;
  String info = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    info = calib.length < 4
        ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an'
        : '${g.names[g.cur]} antippen, um zu starten';
    availableCameras().then((cams) async {
      final cc = CameraController(cams.first, ResolutionPreset.medium, enableAudio: false);
      await cc.initialize();
      if (mounted) setState(() => ctrl = cc);
    });
    timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick());
  }

  @override
  void dispose() {
    timer?.cancel();
    ctrl?.dispose();
    super.dispose();
  }

  Future<img.Image?> _shot() async {
    final f = await ctrl!.takePicture();
    var im = img.decodeImage(await f.readAsBytes());
    if (im == null) return null;
    return img.copyResize(img.bakeOrientation(im), width: 640);
  }

  void _add(Dart d) => setState(() {
        g.add(d);
        if (g.winner != null) {
          info = 'Gewonnen!';
        } else if (g.darts.isEmpty) {
          armed = false;
          base = null;
          info = '${g.msg ?? ''} Darts ziehen, dann ${g.names[g.cur]} antippen.';
        } else {
          info = 'Erkannt: ${d.label}';
        }
      });

  Future<void> _arm() async {
    if (ctrl == null || busy) return;
    if (calib.length < 4) {
      setState(() => info = 'Erst kalibrieren (4 Punkte im Bild antippen)');
      return;
    }
    busy = true;
    try {
      base = await _shot();
      pending = null;
      armed = true;
      info = 'Bereit – ${g.names[g.cur]} wirft';
    } catch (e) {
      info = 'Fehler: $e';
    }
    busy = false;
    if (mounted) setState(() {});
  }

  /// Auto-Erkennung: Ergebnis muss in zwei Aufnahmen hintereinander gleich sein (Hand weg, Dart ruhig).
  Future<void> _tick() async {
    if (!auto || !armed || busy || ctrl == null || base == null || g.winner != null) return;
    busy = true;
    try {
      final now = await _shot();
      if (now == null) return;
      final d = detect(base!, now);
      if (d == null) {
        pending = null;
      } else if (pending != null && pending!.label == d.label) {
        pending = null;
        base = now;
        _add(d);
      } else {
        pending = d;
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
      calib.add(Offset(p.dx / s.width, p.dy / s.height));
      info = calib.length < 4
          ? 'Weiter: ${calibNames[calib.length]}'
          : 'Kalibriert. ${g.names[g.cur]} antippen, um zu starten.';
    });
  }

  void _manual() {
    var mult = 1;
    showModalBottomSheet(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, set) {
              Widget key(String t, VoidCallback f, {bool sel = false}) => Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: sel ? kAccent.withOpacity(.18) : null,
                              side: BorderSide(color: sel ? kAccent : kLine)),
                          onPressed: f,
                          child: Text(t, style: const TextStyle(fontSize: 18)))));
              void pick(Dart d) {
                Navigator.pop(c);
                _add(d);
              }

              return SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          key('SINGLE', () => set(() => mult = 1), sel: mult == 1),
                          key('DOUBLE', () => set(() => mult = 2), sel: mult == 2),
                          key('TRIPLE', () => set(() => mult = 3), sel: mult == 3),
                        ]),
                        for (var r = 0; r < 5; r++)
                          Row(children: [for (var i = 1; i <= 4; i++) key('${r * 4 + i}', () => pick(Dart(r * 4 + i, mult)))]),
                        Row(children: [
                          key('25', () => pick(const Dart(25, 1))),
                          key('BULL', () => pick(const Dart(25, 2))),
                          key('MISS', () => pick(const Dart(0, 1))),
                        ]),
                      ])));
            }));
  }

  @override
  Widget build(BuildContext c) {
    final cc = ctrl;
    final rem = g.scores[g.cur];
    final route = g.winner == null && rem <= (g.dbl ? 170 : 180) ? checkout(rem, g.dbl, 3 - g.darts.length) : null;
    return Scaffold(
      appBar: AppBar(
          title: Text(g.winner != null ? '🏆 ${g.winner} gewinnt!' : 'Dran: ${g.names[g.cur]}'),
          actions: [
            const Text('Auto'),
            Switch(value: auto, onChanged: (v) => setState(() => auto = v))
          ]),
      body: Column(children: [
        SizedBox(
          height: 100,
          child: Row(children: [
            for (var i = 0; i < g.names.length; i++)
              Expanded(
                  child: GestureDetector(
                      onTap: i == g.cur && g.winner == null ? _arm : null,
                      child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: i == g.cur && armed ? kAccent.withOpacity(.15) : const Color(0xFF0C0C0C),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: i == g.cur ? (armed ? kAccent : kViolet) : kLine,
                                  width: i == g.cur ? 1.5 : 1)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(g.names[i].toUpperCase(),
                                style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white54)),
                            Text('${g.scores[i]}',
                                style: TextStyle(
                                    fontSize: 36, color: i == g.cur ? Colors.white : Colors.white70)),
                          ])))),
          ]),
        ),
        if (route != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'CHECKOUT  ', style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 11)),
                TextSpan(text: route.map((d) => d.label).join(' · '), style: const TextStyle(color: kViolet, fontSize: 18)),
              ]))),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${g.darts.map((d) => d.label).join('  ')}\n$info', textAlign: TextAlign.center)),
        Expanded(
            child: cc == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                        aspectRatio: 1 / cc.value.aspectRatio,
                        child: LayoutBuilder(
                            builder: (_, k) => GestureDetector(
                                onTapUp: (t) => _calibTap(t.localPosition, Size(k.maxWidth, k.maxHeight)),
                                child: Stack(fit: StackFit.expand, children: [
                                  CameraPreview(cc),
                                  CustomPaint(painter: _Overlay(List.of(calib))),
                                ])))))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => setState(g.undo), icon: const Icon(Icons.undo), label: const Text('Undo'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: g.winner == null ? _manual : null,
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Manuell'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                          calib = [];
                          armed = false;
                          info = 'Kalibrieren: ${calibNames[0]} antippen';
                        }),
                    icon: const Icon(Icons.crop_free),
                    label: const Text('Kalib.'))),
          ]),
        ),
      ]),
    );
  }
}

// ---------- Kamera-Overlay ----------
class _Overlay extends CustomPainter {
  final List<Offset> pts;
  _Overlay(this.pts);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    Offset sc(Offset o) => Offset(o.dx * s.width, o.dy * s.height);
    for (final o in pts) {
      c.drawCircle(sc(o), 5, p);
    }
    if (pts.length < 4) return;
    final hb = homography(boardPts, pts); // Board -> Bild (normiert)
    for (final r in [1.0, 0.629, 0.582, 0.094]) {
      final path = Path();
      for (var i = 0; i <= 72; i++) {
        final t = i * 5 * pi / 180;
        final q = sc(apply(hb, r * sin(t), -r * cos(t)));
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
