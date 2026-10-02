import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
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

class Det {
  final Dart dart;
  final Offset tip, board;
  final int area;
  Det(this.dart, this.tip, this.board, this.area);
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
  if (bw < 50 || bh < 50) return null;
  final d = List.filled(bw * bh * 3, 0.0);
  var sum = 0.0;
  for (var y = 0; y < bh; y++) {
    for (var x = 0; x < bw; x++) {
      final pa = a.getPixel(X0 + x, Y0 + y), pb = b.getPixel(X0 + x, Y0 + y);
      final i = (y * bw + x) * 3;
      d[i] = (pb.r - pa.r).toDouble();
      d[i + 1] = (pb.g - pa.g).toDouble();
      d[i + 2] = (pb.b - pa.b).toDouble();
      sum += d[i] + d[i + 1] + d[i + 2];
    }
  }
  final shift = sum / (bw * bh * 3); // globale Helligkeitsänderung ignorieren
  const f = 3;
  final gw = (bw + f - 1) ~/ f, gh = (bh + f - 1) ~/ f;
  final cnt = List.filled(gw * gh, 0);
  final cand = <int>[];
  for (var y = 0; y < bh; y++) {
    for (var x = 0; x < bw; x++) {
      final i = (y * bw + x) * 3;
      if (((d[i] - shift).abs() + (d[i + 1] - shift).abs() + (d[i + 2] - shift).abs()) / 3 > 22) {
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
  if (bestN < 25 || bestN > 0.06 * bw * bh) return null; // nichts / Hand im Bild
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
  return Det(fromBoard(bp.dx, bp.dy), tip, bp, pts.length);
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
    ctrl?.dispose();
    super.dispose();
  }

  Future<img.Image?> _shot() async {
    final f = await ctrl!.takePicture();
    var im = img.decodeImage(await f.readAsBytes());
    if (im == null) return null;
    return img.copyResize(img.bakeOrientation(im), width: 960);
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
      try {
        await ctrl!.setExposureMode(ExposureMode.auto);
        await ctrl!.setFocusMode(FocusMode.auto);
        await Future.delayed(const Duration(milliseconds: 800));
        await ctrl!.setExposureMode(ExposureMode.locked);
        await ctrl!.setFocusMode(FocusMode.locked);
      } catch (_) {}
      base = await _shot();
      var note = '';
      final cur = edges(base!);
      if (calDirty || refG == null || refCalib == null) {
        refG = cur; // Referenz für das automatische Nachführen
        refCalib = List.of(calib);
        calDirty = false;
      } else {
        final sh = align(refG!, cur, refCalib!);
        if (sh != null) {
          calib = [for (final p in refCalib!) p + Offset(sh.dx / cur.ow, sh.dy / cur.oh)];
          note = ' (Scheibe nachgeführt: ${sh.dx.toInt()}/${sh.dy.toInt()} px)';
        } else {
          note = ' (Ausrichtung unsicher – ggf. neu kalibrieren)';
        }
      }
      pending = null;
      seen = 0;
      armed = true;
      info = 'Bereit – ${g.names[g.cur]} wirft$note';
    } catch (e) {
      info = 'Fehler: $e';
    }
    busy = false;
    if (mounted) setState(() {});
  }

  /// Auto-Erkennung: Position muss in zwei Aufnahmen hintereinander (fast) gleich sein.
  Future<void> _tick() async {
    if (!auto || !armed || busy || ctrl == null || base == null || g.winner != null) return;
    busy = true;
    try {
      final now = await _shot();
      if (now == null) return;
      final d = detect(base!, now);
      if (d == null) {
        pending = null;
        seen = 0;
      } else {
        seen++;
        if (mounted) {
          setState(() {
            tip = Offset(d.tip.dx / now.width, d.tip.dy / now.height);
            info = 'Blob ${d.area}px → ${d.dart.label}';
          });
        }
        if (pending != null && ((pending!.board - d.board).distance < 0.12 || seen >= 3)) {
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
              // Menü bleibt offen, bis der Zug zu Ende ist
              void pick(Dart d) {
                _add(d);
                if (g.winner != null || g.darts.isEmpty) {
                  Navigator.pop(c);
                } else {
                  set(() {});
                }
              }

              return SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${g.names[g.cur].toUpperCase()}  ${g.scores[g.cur]}   ${g.darts.map((d) => d.label).join(' · ')}',
                            style: const TextStyle(fontSize: 16, color: kViolet)),
                        const SizedBox(height: 6),
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
                          key('↶', () {
                            setState(g.undo);
                            set(() {});
                          }),
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
                                onPanStart: (d) => _panStart(d.localPosition, Size(k.maxWidth, k.maxHeight)),
                                onPanUpdate: (d) => _panUpdate(d.delta, Size(k.maxWidth, k.maxHeight)),
                                onPanEnd: (_) => drag = null,
                                child: Stack(fit: StackFit.expand, children: [
                                  CameraPreview(cc),
                                  CustomPaint(painter: _Overlay(List.of(calib), tip)),
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
                          calDirty = true;
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
  final Offset? tip;
  _Overlay(this.pts, this.tip);
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
    if (tip != null) {
      c.drawCircle(sc(tip!), 6, Paint()..color = kViolet);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}