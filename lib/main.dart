import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

void main() => runApp(MaterialApp(
    title: 'Dart Zähler',
    theme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
        useMaterial3: true),
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

  void _manual() => showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
          padding: const EdgeInsets.all(12),
          child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (_, k) {
                final s = k.maxWidth, R = s / 2 * 0.92;
                return GestureDetector(
                    onTapUp: (t) {
                      Navigator.pop(c);
                      _add(fromBoard((t.localPosition.dx - s / 2) / R, (t.localPosition.dy - s / 2) / R));
                    },
                    child: CustomPaint(painter: BoardPainter(), size: Size(s, s)));
              }))));

  @override
  Widget build(BuildContext c) {
    final cc = ctrl;
    return Scaffold(
      appBar: AppBar(
          title: Text(g.winner != null ? '🏆 ${g.winner} gewinnt!' : 'Dran: ${g.names[g.cur]}'),
          actions: [
            const Text('Auto'),
            Switch(value: auto, onChanged: (v) => setState(() => auto = v))
          ]),
      body: Column(children: [
        SizedBox(
          height: 76,
          child: Row(children: [
            for (var i = 0; i < g.names.length; i++)
              Expanded(
                  child: GestureDetector(
                      onTap: i == g.cur && g.winner == null ? _arm : null,
                      child: Card(
                          color: i == g.cur
                              ? (armed ? Colors.green.shade800 : Theme.of(c).colorScheme.primaryContainer)
                              : null,
                          child: Center(
                              child: Text('${g.names[i]}\n${g.scores[i]}',
                                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)))))),
          ]),
        ),
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

class BoardPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final ctr = s.center(Offset.zero), R = s.width / 2 * 0.92;
    c.drawCircle(ctr, s.width / 2, Paint()..color = Colors.black);
    void ring(double a, double b, Color col, int i) {
      final p = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = (b - a) * R;
      c.drawArc(Rect.fromCircle(center: ctr, radius: (a + b) / 2 * R),
          (-90 - 9 + i * 18) * pi / 180, 18 * pi / 180, false, p);
    }

    for (var i = 0; i < 20; i++) {
      final even = i % 2 == 0;
      final single = even ? const Color(0xFF222222) : const Color(0xFFE8D9B0);
      final color = even ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
      ring(0.094, 0.582, single, i);
      ring(0.582, 0.629, color, i);
      ring(0.629, 0.953, single, i);
      ring(0.953, 1.0, color, i);
      final a = (-90 + i * 18) * pi / 180;
      final tp = TextPainter(
          text: TextSpan(text: '${order[i]}', style: const TextStyle(fontSize: 13)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, ctr + Offset(cos(a), sin(a)) * R * 1.04 - Offset(tp.width / 2, tp.height / 2));
    }
    c.drawCircle(ctr, 0.094 * R, Paint()..color = const Color(0xFF2E7D32));
    c.drawCircle(ctr, 0.037 * R, Paint()..color = const Color(0xFFC62828));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------- Kamera-Overlay ----------
class _Overlay extends CustomPainter {
  final List<Offset> pts;
  _Overlay(this.pts);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.greenAccent
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
