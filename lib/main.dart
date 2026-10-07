import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, File;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final darkSetting = ValueNotifier<bool?>(null);
final darkMode = ValueNotifier<bool>(true);
final vibOn = ValueNotifier<bool>(true);
final soundOn = ValueNotifier<bool>(true);
final diagOn = ValueNotifier<bool>(false);
final autoFit = ValueNotifier<bool>(true);
final checkoutOn = ValueNotifier<bool>(true);
String diagWhy = '';

Color kBg = const Color(0xFF0A0910);
Color kCard = const Color(0xFF16141F);
Color kLine = const Color(0xFF2E2A3D);
Color kInk = const Color(0xFFF4F2FA);
Color kDim = const Color(0xFF9793A8);
Color kOnAccent = Colors.black;
Color kAccent = const Color(0xFF00E5C8);
Color kViolet = const Color(0xFF9A6BFF);
List<Color> teamColors = [kAccent, kViolet, const Color(0xFFFF3D8B), const Color(0xFFFFD100), const Color(0xFF00A6FF), const Color(0xFF6BD100)];

void applyTheme(bool d) {
  if (d) {
    kBg = const Color(0xFF0A0910);
    kCard = const Color(0xFF16141F);
    kLine = const Color(0xFF2E2A3D);
    kInk = const Color(0xFFF4F2FA);
    kDim = const Color(0xFF9793A8);
    kOnAccent = Colors.black;
    kAccent = const Color(0xFF00E5C8);
    kViolet = const Color(0xFF9A6BFF);
    teamColors = [kAccent, kViolet, const Color(0xFFFF3D8B), const Color(0xFFFFD100), const Color(0xFF00A6FF), const Color(0xFF6BD100)];
  } else {
    kBg = const Color(0xFFEFE3C8);
    kCard = const Color(0xFFF8EEDA);
    kLine = const Color(0xFFBFB08C);
    kInk = const Color(0xFF1A1620);
    kDim = const Color(0xFF6A5F4C);
    kOnAccent = Colors.white;
    kAccent = const Color(0xFF0043CE);
    kViolet = const Color(0xFFD32029);
    teamColors = [kAccent, kViolet, const Color(0xFFFF6A00), const Color(0xFFB58A00), const Color(0xFF00787A), const Color(0xFF4A7A00)];
  }
}

void feedback() {
  if (vibOn.value) HapticFeedback.mediumImpact();
  if (soundOn.value) SystemSound.play(SystemSoundType.click);
}

Future<void> sound180() async {
  if (!soundOn.value) return;
  for (var i = 0; i < 3; i++) {
    SystemSound.play(SystemSoundType.click);
    await Future.delayed(const Duration(milliseconds: 90));
  }
}

Future<void> soundBigFish() async {
  if (!soundOn.value) return;
  for (var i = 0; i < 5; i++) {
    SystemSound.play(SystemSoundType.click);
    await Future.delayed(const Duration(milliseconds: 70));
  }
}

Future<void> saveCalib() async {
  final p = await SharedPreferences.getInstance();
  if (calib.length == 4) {
    await p.setStringList('calib', [for (final o in calib) '${o.dx},${o.dy}']);
  } else {
    await p.remove('calib');
  }
}

ThemeData appTheme(bool d) {
  return ThemeData(
    brightness: d ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    fontFamily: 'monospace',
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: (d ? ColorScheme.dark() : ColorScheme.light()).copyWith(primary: kAccent, secondary: kViolet, surface: kBg),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: kInk,
      titleTextStyle: TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, color: kInk),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: kCard),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kOnAccent,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(52),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: kInk, side: BorderSide(color: kLine)),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  final dv = p.getInt('dark');
  darkSetting.value = dv == null ? null : dv == 1;
  vibOn.value = p.getBool('vib') ?? true;
  soundOn.value = p.getBool('snd') ?? true;
  diagOn.value = p.getBool('diag') ?? false;
  autoFit.value = p.getBool('fit') ?? true;
  checkoutOn.value = p.getBool('co') ?? true;
  final cs = p.getStringList('calib');
  if (cs != null && cs.length == 4) {
    calib = [for (final s in cs) Offset(double.parse(s.split(',')[0]), double.parse(s.split(',')[1]))];
  }
  runApp(const StanDartApp());
}

class StanDartApp extends StatefulWidget {
  const StanDartApp({super.key});
  @override
  State<StanDartApp> createState() => _StanDartAppState();
}

class _StanDartAppState extends State<StanDartApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    darkSetting.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    darkSetting.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _sync();

  void _sync() {
    final sysDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final wantDark = darkSetting.value ?? sysDark;
    if (darkMode.value != wantDark) {
      darkMode.value = wantDark;
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext c) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (_, d, __) {
        applyTheme(d);
        return MaterialApp(
          title: 'StanDart',
          debugShowCheckedModeBanner: false,
          builder: (c, child) => Container(color: kBg, child: CustomPaint(painter: _Dots(), child: child)),
          theme: appTheme(d),
          home: const SplashPage(),
        );
      },
    );
  }
}

const order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

class Dart {
  final int n, m;
  const Dart(this.n, this.m);
  int get points => n * m;
  String get label {
    if (n == 0) return 'OUT';
    if (n == 25) return m == 2 ? 'D-Bull' : 'S-Bull';
    final pre = m == 3 ? 'T' : (m == 2 ? 'D' : '');
    return '$pre$n';
  }
}

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

// ---------- Lifetime-Stats ----------
class LifeStats {
  int games;
  int darts;
  int tons;
  int count170;
  int highFin;
  int bestTurn;
  int wins;
  double points;
  LifeStats({this.games = 0, this.darts = 0, this.tons = 0, this.count170 = 0, this.highFin = 0, this.bestTurn = 0, this.wins = 0, this.points = 0});
  String toJson() => jsonEncode({'g': games, 'd': darts, 't': tons, 'c170': count170, 'hf': highFin, 'bt': bestTurn, 'w': wins, 'p': points});
  static LifeStats from(String? s) {
    if (s == null) return LifeStats();
    try {
      final m = jsonDecode(s) as Map;
      return LifeStats(
        games: (m['g'] ?? 0) as int,
        darts: (m['d'] ?? 0) as int,
        tons: (m['t'] ?? 0) as int,
        count170: (m['c170'] ?? 0) as int,
        highFin: (m['hf'] ?? 0) as int,
        bestTurn: (m['bt'] ?? 0) as int,
        wins: (m['w'] ?? 0) as int,
        points: ((m['p'] ?? 0) as num).toDouble(),
      );
    } catch (_) {
      return LifeStats();
    }
  }
}

// ---------- Spielerprofil ----------
class Profile {
  final String name;
  final Song? song;
  final LifeStats stats;
  Profile(this.name, this.song, [LifeStats? stats]) : stats = stats ?? LifeStats();
  String toJson() => jsonEncode({'n': name, 's': song?.toJson(), 'st': stats.toJson()});
  static Profile? from(String? s) {
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map;
      return Profile('${m['n']}', Song.from(m['s'] as String?), LifeStats.from(m['st'] as String?));
    } catch (_) {
      return null;
    }
  }
}

Future<List<Profile>> loadProfiles() async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList('profiles') ?? [];
  return [for (final s in list) if (Profile.from(s) != null) Profile.from(s)!];
}

Future<void> saveProfiles(List<Profile> profiles) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList('profiles', [for (final pr in profiles) pr.toJson()]);
}

Future<String> songCachePath(int id) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/song_$id.mp3';
}

Future<bool> songCached(int id) async {
  final p = await songCachePath(id);
  return File(p).existsSync();
}

Future<String?> cachedSongPath(int id) async {
  final p = await songCachePath(id);
  return File(p).existsSync() ? p : null;
}

class Game {
  final List<String> names;
  final int start;
  final bool dbl;
  final bool doubleIn;
  final bool masterOut;
  late List<int> scores;
  late List<int> thrown;
  late List<List<Dart>> last;
  int cur = 0;
  int turnStart;
  int dartsThisTurn = 0;
  bool opened = false;
  int openIdx = -1; // Index des ersten zählenden Darts (Double-In)
  List<Dart> darts = [];
  String? winner;
  String? msg;
  bool hold = false;
  bool held = false;
  final bool wm;
  final bool tieBreak;
  final int setsToWin;
  late List<int> legs;
  late List<int> sets;
  late List<int> done;
  int legStart = 0;
  int setStart = 0;
  int? legWinner;
  int? setWinner;
  late List<int> tons;
  late List<int> highFin;
  late List<int> bestTurn;
  late List<int> count170;
  final hist = <List<Object?>>[];

  Game(this.names, this.start, this.dbl,
      {this.wm = false, this.setsToWin = 3, this.tieBreak = true, int first = 0, this.doubleIn = false, this.masterOut = false})
      : turnStart = start {
    cur = first;
    legStart = first;
    setStart = first;
    legs = List.filled(names.length, 0);
    sets = List.filled(names.length, 0);
    done = List.filled(names.length, 0);
    scores = List.filled(names.length, start);
    thrown = List.filled(names.length, 0);
    tons = List.filled(names.length, 0);
    highFin = List.filled(names.length, 0);
    bestTurn = List.filled(names.length, 0);
    count170 = List.filled(names.length, 0);
    last = List.generate(names.length, (_) => <Dart>[]);
    turnStart = scores[cur];
    opened = !doubleIn;
  }

  String avg(int i) {
    if (thrown[i] == 0) return '–';
    final v = (done[i] + start - scores[i]) / thrown[i] * 3;
    return v.toStringAsFixed(1);
  }

  // Effektiver Punkte-Summe (Double-In berücksichtigt)
  int _effSum() {
    if (doubleIn && !opened) return 0;
    if (doubleIn && openIdx > 0) {
      var s = 0;
      for (var i = openIdx; i < darts.length; i++) {
        s += darts[i].points;
      }
      return s;
    }
    var s = 0;
    for (final d in darts) {
      s += d.points;
    }
    return s;
  }

  // Finish-Regel: 'any', 'double' oder 'master'
  String get _finishRule {
    if (masterOut) return 'master';
    if (dbl) return 'double';
    return 'any';
  }

  bool _isValidFinish(Dart d) {
    switch (_finishRule) {
      case 'double':
        return d.m == 2;
      case 'master':
        return d.m == 2 || d.m == 3;
      default:
        return true;
    }
  }

  void add(Dart d) {
    if (winner != null || held || legWinner != null) return;
    _save();
    msg = null;
    thrown[cur]++;
    dartsThisTurn++;
    darts.add(d);

    // Double-In: Öffnung prüfen
    if (doubleIn && !opened) {
      if (d.m == 2) {
        opened = true;
        openIdx = darts.length - 1;
      }
      // Turn zu Ende ohne Öffnung?
      if (dartsThisTurn == 3) {
        if (hold) {
          held = true;
        } else {
          _next();
        }
      }
      return;
    }

    final effSum = _effSum();
    final rem = turnStart - effSum;
    final needFinish = _finishRule != 'any';
    final bust = rem < 0 || (needFinish && rem == 1) || (rem == 0 && needFinish && !_isValidFinish(d));
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
      final finish = turnStart;
      if (finish >= 100) highFin[cur]++;
      if (finish == 170) count170[cur]++;
      if (wm) {
        _legWon();
      } else {
        winner = names[cur];
      }
      return;
    }
    if (dartsThisTurn == 3) {
      final sum = _effSum();
      if (sum == 180) tons[cur]++;
      if (sum > bestTurn[cur]) bestTurn[cur] = sum;
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
    dartsThisTurn = 0;
    turnStart = scores[cur];
    opened = !doubleIn;
    openIdx = -1;
  }

  void _legWon() {
    for (var i = 0; i < names.length; i++) {
      done[i] += start - scores[i];
    }
    final w = cur;
    legs[w]++;
    legWinner = w;
    setWinner = null;
    final deciding = sets[0] == setsToWin - 1 && sets[1] == setsToWin - 1;
    final o = legs[1 - w];
    final won = (deciding && tieBreak) ? (legs[w] >= 3 && legs[w] - o >= 2) : legs[w] >= 3;
    if (won) {
      sets[w]++;
      setWinner = w;
      if (sets[w] >= setsToWin) winner = names[w];
    }
  }

  void nextLeg() {
    if (legWinner == null || winner != null) return;
    if (setWinner != null) {
      legs = List.filled(names.length, 0);
      setStart = (setStart + 1) % names.length;
      legStart = setStart;
    } else {
      legStart = (legStart + 1) % names.length;
    }
    legWinner = null;
    setWinner = null;
    scores = List.filled(names.length, start);
    last = List.generate(names.length, (_) => <Dart>[]);
    darts = [];
    dartsThisTurn = 0;
    msg = null;
    held = false;
    hist.clear();
    cur = legStart;
    turnStart = start;
    opened = !doubleIn;
    openIdx = -1;
  }

  void _save() {
    hist.add([
      List<int>.of(scores),
      List<int>.of(thrown),
      [for (final l in last) List<Dart>.of(l)],
      cur,
      turnStart,
      List<Dart>.of(darts),
      winner,
      msg,
      held,
      List<int>.of(legs),
      List<int>.of(sets),
      List<int>.of(done),
      legStart,
      setStart,
      legWinner,
      setWinner,
      List<int>.of(tons),
      List<int>.of(highFin),
      List<int>.of(bestTurn),
      List<int>.of(count170),
      opened,
      openIdx,
      dartsThisTurn,
    ]);
  }

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
    legs = h[9] as List<int>;
    sets = h[10] as List<int>;
    done = h[11] as List<int>;
    legStart = h[12] as int;
    setStart = h[13] as int;
    legWinner = h[14] as int?;
    setWinner = h[15] as int?;
    tons = h[16] as List<int>;
    highFin = h[17] as List<int>;
    bestTurn = h[18] as List<int>;
    count170 = h[19] as List<int>;
    opened = h[20] as bool;
    openIdx = h[21] as int;
    dartsThisTurn = h[22] as int;
  }
}

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
      c += d.m == 1 ? 0 : (d.m == 2 ? 1 : 3);
    }
  }
  return c;
}

List<Dart>? checkout(int rem, bool dbl, int left) {
  final key = '$rem$dbl$left';
  if (!_memo.containsKey(key) && _memo.length > 500) _memo.clear();
  return _memo.putIfAbsent(key, () {
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

void showSettings(BuildContext c) {
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> persistDark() async {
          final p = await SharedPreferences.getInstance();
          if (darkSetting.value == null) {
            await p.remove('dark');
          } else {
            await p.setInt('dark', darkSetting.value! ? 1 : 0);
          }
        }
        return SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('EINSTELLUNGEN', style: TextStyle(letterSpacing: 3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DESIGN', style: TextStyle(letterSpacing: 2, color: kDim, fontSize: 11)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.brightness_auto, size: 16), label: Text('AUTO')),
                  ButtonSegment(value: 1, icon: Icon(Icons.light_mode, size: 16), label: Text('HELL')),
                  ButtonSegment(value: 2, icon: Icon(Icons.dark_mode, size: 16), label: Text('DUNKEL')),
                ],
                selected: {darkSetting.value == null ? 0 : (darkSetting.value! ? 2 : 1)},
                onSelectionChanged: (s) {
                  darkSetting.value = s.first == 0 ? null : s.first == 2;
                  persistDark();
                  set(() {});
                },
              ),
            ]),
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: vibOn.value,
            onChanged: (v) async {
              vibOn.value = v;
              set(() {});
              final p = await SharedPreferences.getInstance();
              p.setBool('vib', v);
            },
          ),
          SwitchListTile(
            title: const Text('Ton'),
            value: soundOn.value,
            onChanged: (v) async {
              soundOn.value = v;
              set(() {});
              final p = await SharedPreferences.getInstance();
              p.setBool('snd', v);
            },
          ),
          SwitchListTile(
            title: const Text('Checkout-Vorschläge'),
            subtitle: const Text('zeigt den kürzesten Weg auf 0'),
            value: checkoutOn.value,
            onChanged: (v) async {
              checkoutOn.value = v;
              set(() {});
              final p = await SharedPreferences.getInstance();
              p.setBool('co', v);
            },
          ),
          SwitchListTile(
            title: const Text('Auto-Feinabgleich der Scheibe'),
            value: autoFit.value,
            onChanged: (v) async {
              autoFit.value = v;
              set(() {});
              final p = await SharedPreferences.getInstance();
              p.setBool('fit', v);
            },
          ),
          SwitchListTile(
            title: const Text('Diagnose-Modus'),
            subtitle: const Text('zeigt erkannte Flecken und Gründe'),
            value: diagOn.value,
            onChanged: (v) async {
              diagOn.value = v;
              set(() {});
              final p = await SharedPreferences.getInstance();
              p.setBool('diag', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.crop_free),
            title: const Text('Kalibrierung zurücksetzen'),
            onTap: () {
              calib = [];
              saveCalib();
              Navigator.pop(ctx);
            },
          ),
        ])));
      });
    },
  );
}

class Song {
  final int id;
  final String title;
  final String artist;
  const Song(this.id, this.title, this.artist);
  String toJson() => jsonEncode({'id': id, 't': title, 'a': artist});
  static Song? from(String? s) {
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map;
      return Song(m['id'] as int, '${m['t']}', '${m['a']}');
    } catch (_) {
      return null;
    }
  }
}

Future<dynamic> deezerJson(String url) async {
  final h = HttpClient();
  try {
    final req = await h.getUrl(Uri.parse(url));
    final res = await req.close().timeout(const Duration(seconds: 10));
    return jsonDecode(await res.transform(utf8.decoder).join());
  } finally {
    h.close();
  }
}

Future<Song?> pickSong(BuildContext c) async {
  return await Navigator.push<Song>(c, MaterialPageRoute(builder: (_) => const SongPickerPage()));
}

class SongPickerPage extends StatefulWidget {
  const SongPickerPage({super.key});
  @override
  State<SongPickerPage> createState() => _SongPickerState();
}

class _SongPickerState extends State<SongPickerPage> {
  final q = TextEditingController();
  final ap = AudioPlayer();
  List<Map<String, dynamic>> res = [];
  bool busy = false;
  String? err;
  int? playing;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    ap.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = null);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ap.stop();
    ap.dispose();
    q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        res = [];
        err = null;
        busy = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), search);
  }

  Future<void> search() async {
    final t = q.text.trim();
    if (t.isEmpty) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final j = await deezerJson('https://api.deezer.com/search?q=${Uri.encodeQueryComponent(t)}&limit=20');
      final list = <Map<String, dynamic>>[];
      final data = j['data'] as List? ?? [];
      for (final e in data) {
        if (e is Map<String, dynamic> && '${e['preview'] ?? ''}'.isNotEmpty) list.add(e);
      }
      if (mounted) {
        setState(() {
          res = list;
          busy = false;
          if (list.isEmpty) err = 'Nichts gefunden';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = 'Suche fehlgeschlagen – Internet?';
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('EINLAUFSONG')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              controller: q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                labelText: 'Song oder Interpret suchen (Deezer)',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (busy) const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: LinearProgressIndicator()),
          if (err != null) Padding(padding: const EdgeInsets.all(8), child: Text(err!, style: TextStyle(color: kDim))),
          Expanded(
            child: ListView(children: [
              for (final e in res)
                ListTile(
                  title: Text('${e['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${(e['artist'] as Map?)?['name'] ?? ''}', maxLines: 1),
                  trailing: IconButton(
                    icon: Icon(playing == e['id'] ? Icons.stop : Icons.play_arrow),
                    onPressed: () async {
                      if (playing == e['id']) {
                        await ap.stop();
                        setState(() => playing = null);
                        return;
                      }
                      setState(() => playing = e['id'] as int);
                      try {
                        await ap.play(UrlSource('${e['preview']}'));
                      } catch (_) {}
                    },
                  ),
                  onTap: () {
                    Navigator.pop(c, Song(e['id'] as int, '${e['title']}', '${(e['artist'] as Map?)?['name'] ?? ''}'));
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- Modus-Auswahl ----------
class ModePage extends StatelessWidget {
  const ModePage({super.key});

  Widget tile(String big, String small, Color col, VoidCallback f) {
    final txt = col.computeLuminance() > .35 ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: kInk.withValues(alpha: .35), offset: const Offset(6, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(small, style: TextStyle(color: txt, fontSize: 11, letterSpacing: 2)),
          const Spacer(),
          FittedBox(child: Text(big, style: TextStyle(color: txt, fontSize: 60, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }

  Widget smallTile(IconData i, String label, VoidCallback f, {Color? accent}) {
    final col = accent ?? kAccent;
    return GestureDetector(
      onTap: f,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col, width: 1.5),
          boxShadow: [BoxShadow(color: col, offset: const Offset(3, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: col, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: col, fontSize: 10, letterSpacing: 1.5)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (c, _, __) {
        void go(int? pts, bool wm) {
          Navigator.push(c, MaterialPageRoute(builder: (_) => SetupPage(startPts: pts, wm: wm)));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('STANDART')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: MediaQuery.of(c).size.width > MediaQuery.of(c).size.height ? 4 : 2,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 22,
                  children: [
                    tile('501', 'FREIES SPIEL', teamColors[0], () => go(501, false)),
                    tile('301', 'FREIES SPIEL', teamColors[1], () => go(301, false)),
                    tile('701', 'FREIES SPIEL', teamColors[2], () => go(701, false)),
                    tile('WM', 'SÄTZE & LEGS', teamColors[3], () => go(null, true)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: smallTile(Icons.tune, 'EINSTELLUNGEN', () => showSettings(c))),
                const SizedBox(width: 12),
                Expanded(child: smallTile(Icons.people, 'PROFILE', () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ProfilesPage())), accent: kViolet)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ---------- Profile ----------
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});
  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  List<Profile> profiles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await loadProfiles();
    if (mounted) {
      setState(() {
        profiles = p;
        loading = false;
      });
    }
  }

  Future<void> _add() async {
    final nameC = TextEditingController();
    Song? song;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('NEUES PROFIL'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final s = await pickSong(c);
                if (s != null) {
                  song = s;
                  set(() {});
                }
              },
              icon: Icon(song == null ? Icons.music_note : Icons.check_circle, color: song == null ? kAccent : teamColors[2], size: 24),
              label: Text(song == null ? 'SONG WÄHLEN' : 'SONG BESTÄTIGT'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ABBRECHEN')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('SPEICHERN')),
          ],
        ),
      ),
    );
    if (ok == true && nameC.text.trim().isNotEmpty) {
      profiles.add(Profile(nameC.text.trim(), song));
      await saveProfiles(profiles);
      setState(() {});
    }
  }

  Future<void> _delete(int i) async {
    profiles.removeAt(i);
    await saveProfiles(profiles);
    setState(() {});
  }

  void _showStats(int i) {
    final p = profiles[i];
    final s = p.stats;
    final avg = s.darts == 0 ? '–' : (s.points / s.darts * 3).toStringAsFixed(1);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LIFETIME – ${p.name.toUpperCase()}', style: TextStyle(letterSpacing: 2, color: kDim, fontSize: 12)),
            const SizedBox(height: 10),
            _row('SPIELE', '${s.games}'),
            _row('SIEGE', '${s.wins}'),
            _row('Ø (LIFETIME)', avg),
            _row('DARTS GESAMT', '${s.darts}'),
            _row('180er', '${s.tons}'),
            _row('170er', '${s.count170}'),
            _row('HIGH FINISHES', '${s.highFin}'),
            _row('BESTER ZUG', s.bestTurn == 0 ? '–' : '${s.bestTurn}'),
          ]),
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: TextStyle(color: kDim, fontSize: 11, letterSpacing: 2))),
        Text(v, style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Future<void> _updateCacheAll() async {
    int done = 0;
    for (final p in profiles) {
      if (p.song == null) continue;
      if (await songCached(p.song!.id)) continue;
      try {
        final j = await deezerJson('https://api.deezer.com/track/${p.song!.id}');
        final u = '${j['preview'] ?? ''}';
        if (u.isEmpty) continue;
        final h = HttpClient();
        final req = await h.getUrl(Uri.parse(u));
        final res = await req.close();
        final path = await songCachePath(p.song!.id);
        final f = File(path);
        await f.writeAsBytes(await res.expand((x) => x).toList());
        h.close();
        done++;
        setState(() {});
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$done Songs offline gespeichert')));
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < profiles.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine, width: 1.5)),
                    child: Row(children: [
                      Icon(Icons.person, color: teamColors[i % teamColors.length]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(profiles[i].name, style: TextStyle(color: kInk, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(profiles[i].song == null ? 'kein Song' : '♪ Song hinterlegt', style: TextStyle(color: kDim, fontSize: 11)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.bar_chart), tooltip: 'Lifetime-Stats', onPressed: () => _showStats(i)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(i)),
                    ]),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('PROFIL HINZUFÜGEN')),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _updateCacheAll, icon: const Icon(Icons.download), label: const Text('SONGS OFFLINE SPEICHERN')),
              ],
            ),
    );
  }
}

// ---------- Setup ----------
class SetupPage extends StatefulWidget {
  final int? startPts;
  final bool wm;
  const SetupPage({super.key, this.startPts, this.wm = false});
  @override
  State<SetupPage> createState() => _SetupState();
}

class _SetupState extends State<SetupPage> {
  int players = 2;
  int start = 501;
  int round = 1;
  int first = 0;
  bool dbl = true;
  bool doubleIn = false;
  bool masterOut = false;
  bool wm = false;
  static const _rounds = ['Runde 1 (kein Tie-Break)', 'Runde 2', 'Runde 3/4', 'Viertelfinale', 'Halbfinale', 'Finale'];
  static const _setsTo = [3, 3, 4, 5, 6, 7];
  final ctr = [for (var i = 0; i < 6; i++) TextEditingController()];
  final songs = List<Song?>.filled(6, null);
  List<Profile> profiles = [];

  int get n => wm ? 2 : players;

  @override
  void initState() {
    super.initState();
    wm = widget.wm;
    if (widget.startPts != null) start = widget.startPts!;
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        players = p.getInt('players') ?? players;
        start = widget.startPts ?? p.getInt('start') ?? start;
        dbl = p.getBool('dbl') ?? dbl;
        doubleIn = p.getBool('dblin') ?? false;
        masterOut = p.getBool('masterout') ?? false;
      });
    });
    loadProfiles().then((v) {
      if (mounted) setState(() => profiles = v);
    });
  }

  Future<void> _saveSetup() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('players', players);
    await p.setInt('start', start);
    await p.setBool('dbl', dbl);
    await p.setBool('dblin', doubleIn);
    await p.setBool('masterout', masterOut);
  }

  Widget _sec(String t, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(letterSpacing: 2, color: kDim, fontSize: 12)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _nameRow(int i) {
    final hasSong = songs[i] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: ctr[i],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Name ${i + 1}',
                prefixIcon: Icon(Icons.circle, color: teamColors[i % teamColors.length], size: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final s = await pickSong(context);
              if (s != null) setState(() => songs[i] = s);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hasSong ? teamColors[2] : kAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: hasSong ? teamColors[2] : kAccent, offset: const Offset(3, 3))],
              ),
              child: Icon(hasSong ? Icons.music_note : Icons.library_music, color: hasSong ? Colors.white : kOnAccent, size: 26),
            ),
          ),
        ]),
        if (hasSong)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 6),
            child: Row(children: [
              Icon(Icons.check_circle, color: teamColors[2], size: 14),
              const SizedBox(width: 6),
              Text('SONG BESTÄTIGT', style: TextStyle(color: teamColors[2], fontSize: 10, letterSpacing: 2)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => songs[i] = null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('ENTFERNEN', style: TextStyle(color: kDim, fontSize: 10, letterSpacing: 1)),
                ),
              ),
            ]),
          ),
        if (profiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<int>(
                tooltip: 'Profil laden',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                color: kCard,
                onSelected: (idx) {
                  setState(() {
                    ctr[i].text = profiles[idx].name;
                    songs[i] = profiles[idx].song;
                  });
                },
                itemBuilder: (_) => [
                  for (var k = 0; k < profiles.length; k++)
                    PopupMenuItem(
                      value: k,
                      child: Row(children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: teamColors[k % teamColors.length], shape: BoxShape.circle),
                          child: const Icon(Icons.person, size: 14, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(profiles[k].name, overflow: TextOverflow.ellipsis)),
                        if (profiles[k].song != null) const Icon(Icons.music_note, size: 14),
                      ]),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kViolet, width: 1.5),
                    color: kViolet.withValues(alpha: .12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_alt, size: 16, color: kViolet),
                    const SizedBox(width: 8),
                    Text('PROFIL LADEN', style: TextStyle(color: kViolet, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 16, color: kViolet),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _names() {
    return Column(children: [for (var i = 0; i < n; i++) _nameRow(i)]);
  }

  void _startGame(BuildContext c) {
    _saveSetup();
    final names = <String>[];
    for (var i = 0; i < n; i++) {
      final t = ctr[i].text.trim();
      names.add(t.isEmpty ? 'Spieler ${i + 1}' : t);
    }
    final g = Game(names, wm ? 501 : start, wm ? true : dbl,
        wm: wm, setsToWin: _setsTo[round], tieBreak: round != 0, first: first,
        doubleIn: wm ? false : doubleIn, masterOut: wm ? false : masterOut);
    final songList = songs.sublist(0, n);
    Navigator.push(c, MaterialPageRoute(builder: (_) => GamePage(g, songs: songList)));
  }

  @override
  Widget build(BuildContext c) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (c, _, __) {
        return Scaffold(
          appBar: AppBar(title: Text(wm ? 'WM-MODUS' : 'NEUES SPIEL')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Expanded(
                child: ListView(children: [
                  if (!wm)
                    _sec('SPIELER', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SegmentedButton<int>(
                        segments: [for (var i = 1; i <= 6; i++) ButtonSegment(value: i, label: Text('$i'))],
                        selected: {players},
                        onSelectionChanged: (s) => setState(() => players = s.first),
                      ),
                      const SizedBox(height: 12),
                      _names(),
                    ]))
                  else
                    _sec('SPIELER', _names()),
                  if (!wm) ...[
                    _sec('SPIEL $start', Column(children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Double-Out'),
                        subtitle: const Text('Finish nur mit Doppel'),
                        value: dbl,
                        onChanged: (v) => setState(() => dbl = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Double-In'),
                        subtitle: const Text('Erst mit Doppel ins Spiel kommen'),
                        value: doubleIn,
                        onChanged: (v) => setState(() => doubleIn = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Master-Out'),
                        subtitle: const Text('Finish mit Doppel oder Triple'),
                        value: masterOut,
                        onChanged: (v) => setState(() => masterOut = v),
                      ),
                    ])),
                  ] else ...[
                    _sec('FORMAT', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < _rounds.length; i++)
                          ChoiceChip(label: Text(_rounds[i]), selected: round == i, onSelected: (_) => setState(() => round = i)),
                      ]),
                      const SizedBox(height: 10),
                      Text('First to ${_setsTo[round]} Sätze · Satz = first to 3 Legs · 501 · Double-Out\nAnwurf wechselt je Leg und Satz.\nEntscheidungssatz: 2 Legs Vorsprung.', style: TextStyle(fontSize: 11, color: kDim)),
                    ])),
                    _sec('BULL-UP: WER WIRFT ZUERST?', Wrap(spacing: 8, children: [
                      for (var i = 0; i < 2; i++)
                        ChoiceChip(
                          label: Text(ctr[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctr[i].text.trim()),
                          selected: first == i,
                          onSelected: (_) => setState(() => first = i),
                        ),
                    ])),
                  ],
                ]),
              ),
              FilledButton(onPressed: () => _startGame(c), child: const Text('Spiel starten')),
            ]),
          ),
        );
      },
    );
  }
}

// ---------- Kalibrierung / Perspektive ----------
List<Offset> calib = [];
final boardPts = [for (final a in [9, 99, 189, 279]) Offset(sin(a * pi / 180), -cos(a * pi / 180))];
const calibNames = ['20|1 (oben)', '6|10 (rechts)', '3|19 (unten)', '11|14 (links)'];

List<double> homography(List<Offset> s, List<Offset> d) {
  final m = List.generate(8, (_) => List.filled(9, 0.0));
  for (var i = 0; i < 4; i++) {
    final x = s[i].dx, y = s[i].dy, u = d[i].dx, v = d[i].dy;
    m[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    m[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }
  for (var cc = 0; cc < 8; cc++) {
    var p = cc;
    for (var r = cc + 1; r < 8; r++) {
      if (m[r][cc].abs() > m[p][cc].abs()) p = r;
    }
    final t = m[cc];
    m[cc] = m[p];
    m[p] = t;
    for (var r = 0; r < 8; r++) {
      if (r == cc) continue;
      final f = m[r][cc] / m[cc][cc];
      for (var k = cc; k < 9; k++) {
        m[r][k] -= f * m[cc][k];
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
  final int w, h, ow, oh;
  final Uint8List d;
  Gray(this.w, this.h, this.ow, this.oh, this.d);
}

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
  final Offset tip;
  final Offset board;
  final int area;
  final List<Offset> blob;
  Det(this.dart, this.tip, this.board, this.area, this.blob);
}

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
  final shift = (sb - sa) / (bw * bh * 3);
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
      final cc = q.removeLast();
      n += cnt[cc];
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = cc % gw + dx, ny = cc ~/ gw + dy;
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
  return Det(fromBoard(bp.dx, bp.dy), tip, bp, pts.length, [for (var i = 0; i < pts.length; i += max(1, pts.length ~/ 300)) pts[i]]);
}

// ---------- Spielseite ----------
class GamePage extends StatefulWidget {
  final Game g;
  final List<Song?> songs;
  const GamePage(this.g, {super.key, this.songs = const []});
  @override
  State<GamePage> createState() => _GameState();
}

class _GameState extends State<GamePage> with TickerProviderStateMixin {
  Game get g => widget.g;
  CameraController? ctrl;
  img.Image? base;
  bool armed = false;
  bool auto = true;
  bool busy = false;
  Det? pending;
  Offset? tip;
  String? camErr;
  List<int> walk = [];
  int walkIdx = 0;
  bool walkLoading = false;
  final walkUrls = <int, String>{};
  bool camStarting = false;
  List<Offset> blob = [];
  bool locked = false;
  img.Image? prev;
  bool manual = true;
  final pc = PageController(initialPage: 0);
  int? drag;
  int seen = 0;
  Gray? refG;
  List<Offset>? refCalib;
  bool calDirty = true;
  String info = '';
  Timer? timer;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    info = calib.length < 4 ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an' : '${g.names[g.cur]} antippen, um zu starten';
    g.hold = false;
    walkLoading = soundOn.value && widget.songs.any((s) => s != null);
    if (walkLoading) _prepareWalkIns();
    timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  Future<void> _prepareWalkIns() async {
    final list = <int>[];
    for (var i = 0; i < widget.songs.length; i++) {
      final sg = widget.songs[i];
      if (sg == null) continue;
      final local = await cachedSongPath(sg.id);
      if (local != null) {
        walkUrls[i] = local;
        list.add(i);
        continue;
      }
      try {
        final j = await deezerJson('https://api.deezer.com/track/${sg.id}');
        final u = '${j['preview'] ?? ''}';
        if (u.isNotEmpty) {
          walkUrls[i] = u;
          list.add(i);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        walk = list;
        walkLoading = false;
      });
    }
  }

  Future<void> _initCam() async {
    if (camStarting) return;
    camStarting = true;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw 'Keine Kamera gefunden';
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      Object? last;
      for (final preset in [ResolutionPreset.veryHigh, ResolutionPreset.high, ResolutionPreset.medium]) {
        final cc = CameraController(cam, preset, enableAudio: false);
        try {
          await cc.initialize();
          try {
            await cc.setFlashMode(FlashMode.off);
          } catch (_) {}
          if (!mounted) {
            await cc.dispose();
            return;
          }
          setState(() => ctrl = cc);
          return;
        } catch (e) {
          last = e;
          await cc.dispose();
        }
      }
      throw last ?? 'Kamera konnte nicht starten';
    } catch (e) {
      final t = '$e';
      camStarting = false;
      if (!mounted) return;
      setState(() => camErr = t.toLowerCase().contains('permission') || t.contains('Access') ? 'Kamera-Berechtigung fehlt.' : 'Kamera konnte nicht starten (BETA-Funktion):\n$t');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    ctrl?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<img.Image?> _shot() async {
    final f = await ctrl!.takePicture();
    final im = img.decodeImage(await f.readAsBytes());
    if (im == null) return null;
    return img.copyResize(img.bakeOrientation(im), width: 960);
  }

  void _add(Dart d) {
    feedback();
    final oldTons = g.tons[g.cur];
    final oldFin = g.highFin[g.cur];
    final old170 = g.count170[g.cur];
    setState(() {
      g.add(d);
      if (g.winner != null) {
        info = 'Gewonnen!';
      } else if (g.held) {
        armed = false;
        base = null;
        info = 'Zug beendet. Darts antippen = ändern.';
      } else if (g.darts.isEmpty) {
        armed = false;
        base = null;
        info = manual ? '' : '${g.msg ?? ''} Darts ziehen, dann ${g.names[g.cur]} antippen.';
      } else {
        info = 'Erkannt: ${d.label}';
      }
    });
    if (g.count170[g.cur] > old170) {
      sound180();
    } else if (g.tons[g.cur] > oldTons) {
      sound180();
    } else if (g.highFin[g.cur] > oldFin) {
      soundBigFish();
    }
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
            note = ' (justiert)';
            saveCalib();
          }
        }
        refG = cur;
        refCalib = List.of(calib);
        calDirty = false;
      } else {
        final sh = align(refG!, cur, refCalib!);
        if (sh != null) {
          calib = [for (final p in refCalib!) p + Offset(sh.dx / cur.ow, sh.dy / cur.oh)];
          if (autoFit.value) calib = refineCalib(cur, calib);
          note = ' (nachgeführt)';
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

  Future<void> _tick() async {
    if (manual || !auto || !armed || busy || ctrl == null || base == null || g.winner != null || g.legWinner != null) return;
    busy = true;
    try {
      final now = await _shot();
      if (now == null) return;
      final moving = prev != null && motion(prev!, now) > 3;
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
      info = calib.length < 4 ? 'Weiter: ${calibNames[calib.length]}' : 'Kalibriert. ${g.names[g.cur]} antippen.';
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

  void _panUpdate(Offset delta, Size s) {
    final i = drag;
    if (i == null) return;
    setState(() {
      calDirty = true;
      final o = calib[i];
      calib[i] = Offset((o.dx + delta.dx * 0.5 / s.width).clamp(0.0, 1.0).toDouble(), (o.dy + delta.dy * 0.5 / s.height).clamp(0.0, 1.0).toDouble());
    });
  }

  Widget _keys(void Function(Dart) onPick, String lastLabel, VoidCallback onLast) {
    Widget big(String t, VoidCallback f) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: f,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kInk.withValues(alpha: .07), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine, width: 1.5)),
              child: FittedBox(child: Text(t, style: TextStyle(fontSize: 18, color: kInk))),
            ),
          ),
        ),
      );
    }
    Widget cell(int n) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: kInk.withValues(alpha: .07), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine, width: 1.5)),
            child: Column(children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(Dart(n, 1)),
                  child: Center(child: FittedBox(child: Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: kInk)))),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(children: [
                  for (final m in [2, 3])
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onPick(Dart(n, m)),
                        child: Container(
                          alignment: Alignment.center,
                          color: (m == 2 ? kViolet : teamColors[2]).withValues(alpha: .32),
                          child: Text(m == 2 ? 'D' : 'T', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kInk)),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (_, k) {
      final cols = k.maxWidth > k.maxHeight ? 10 : 5;
      final rows = 20 ~/ cols;
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Column(children: [
          Expanded(
            flex: 2,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              big('OUT', () => onPick(const Dart(0, 1))),
              big('S-BULL', () => onPick(const Dart(25, 1))),
              big('D-BULL', () => onPick(const Dart(25, 2))),
              big(lastLabel, onLast),
            ]),
          ),
          for (var r = 0; r < rows; r++)
            Expanded(
              flex: 4,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var cc = 0; cc < cols; cc++) cell(r * cols + cc + 1)]),
            ),
        ]),
      );
    });
  }

  void _edit(int k) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SizedBox(
          height: min(430.0, MediaQuery.of(c).size.height * .9),
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(10), child: Text('DART ${k + 1} ÄNDERN (jetzt ${g.darts[k].label})', style: TextStyle(color: kViolet))),
            Expanded(
              child: _keys((d) {
                Navigator.pop(c);
                setState(() => g.replace(k, d));
              }, '✕', () => Navigator.pop(c)),
            ),
          ]),
        ),
      ),
    );
  }

  void _tips() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('TIPPS FÜR DIE KAMERA'),
        content: const SingleChildScrollView(
          child: Text('• Winkel: etwa 20–35° seitlich.\n• Handy fest aufstellen.\n• Gleichmäßig beleuchten.\n• Kalibrierpunkte genau auf den Außenrand des Doppelrings.\n• Nach dem Wurf kurz ruhig halten.'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  void _showStats() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('STATISTIK', style: TextStyle(letterSpacing: 3, color: kDim, fontSize: 12)),
            const SizedBox(height: 12),
            for (var i = 0; i < g.names.length; i++) _statCard(i),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(int i) {
    final col = teamColors[i % teamColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(g.names[i].toUpperCase(), style: TextStyle(color: col, letterSpacing: 2, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        _statRow('Ø', g.avg(i)),
        _statRow('DARTS', '${g.thrown[i]}'),
        _statRow('180er', '${g.tons[i]}'),
        _statRow('170er', '${g.count170[i]}'),
        _statRow('HIGH FINISH', '${g.highFin[i]}'),
        _statRow('BESTER ZUG', g.bestTurn[i] == 0 ? '–' : '${g.bestTurn[i]}'),
        if (g.wm) _statRow('SÄTZE / LEGS', '${g.sets[i]} / ${g.legs[i]}'),
      ]),
    );
  }

  Widget _statRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(k, style: TextStyle(color: kDim, fontSize: 11, letterSpacing: 2))),
        Text(v, style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _pill2(String t, int n, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withValues(alpha: .6))),
      child: Text('$t $n', style: TextStyle(fontSize: 10, color: kInk, fontWeight: FontWeight.bold)),
    );
  }

  Widget _compact(int i, Color col, bool cur, List<Dart> ds, bool canEdit) {
    return Row(children: [
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${g.wm && g.legStart == i ? '◆ ' : ''}${cur && armed ? '● ' : ''}${g.names[i].toUpperCase()}${g.wm ? '  S${g.sets[i]} L${g.legs[i]}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, letterSpacing: 1, color: col)),
          Expanded(child: FittedBox(child: DotNum('${g.scores[i]}', kInk))),
          Text('Ø ${g.avg(i)}', style: TextStyle(fontSize: 10, color: kDim)),
        ]),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 52,
        child: Column(children: [
          for (var k = 0; k < 3; k++)
            Expanded(
              child: GestureDetector(
                onTap: canEdit && k < ds.length ? () => _edit(k) : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: canEdit && k < ds.length ? col : kLine)),
                  child: k < ds.length ? FittedBox(child: Text(ds[k].label, style: TextStyle(fontSize: 11, color: kInk))) : null,
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _card(int i, {bool compact = false}) {
    final col = teamColors[i % teamColors.length];
    final cur = i == g.cur;
    final ds = cur ? g.darts : g.last[i];
    final nextI = (g.cur + 1) % g.names.length;
    final canEdit = cur && g.held && !manual;
    final pulseActive = cur && g.winner == null && g.legWinner == null;

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
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final double borderW = cur ? (pulseActive ? 2.0 + 1.4 * _pulse.value : 2.0) : 1.5;
            final double shadowOff = cur && pulseActive ? 3.0 + 3.0 * _pulse.value : 4.0;
            return Container(
              margin: compact ? const EdgeInsets.fromLTRB(4, 4, 8, 6) : const EdgeInsets.fromLTRB(5, 5, 9, 9),
              padding: EdgeInsets.all(compact ? 6 : 10),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cur ? col : (g.held && i == nextI ? col : kLine), width: borderW),
                boxShadow: cur ? [BoxShadow(color: col, offset: Offset(shadowOff, shadowOff))] : null,
              ),
              child: compact
                  ? _compact(i, col, cur, ds, canEdit)
                  : Column(children: [
                      Text('${g.wm && g.legStart == i ? '◆ ' : ''}${cur && armed ? '● ' : ''}${g.names[i].toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 2, color: col)),
                      if (g.wm)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _pill2('SÄTZE', g.sets[i], col),
                            const SizedBox(width: 6),
                            _pill2('LEGS', g.legs[i], col),
                          ]),
                        ),
                      const SizedBox(height: 4),
                      FittedBox(child: DotNum('${g.scores[i]}', kInk)),
                      Text('Ø ${g.avg(i)}${g.last[i].isNotEmpty ? '  ·  ZUG ${g.last[i].fold<int>(0, (a, d) => a + d.points)}' : ''}', style: TextStyle(fontSize: 11, color: kDim)),
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
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: canEdit && k < ds.length ? col : kLine)),
                                child: k < ds.length ? FittedBox(child: Text(ds[k].label, style: TextStyle(fontSize: 12, color: kInk))) : null,
                              ),
                            ),
                          ),
                      ]),
                    ]),
            );
          },
        ),
      ),
    );
  }

  List<String> _lines() {
    return [
      for (var i = 0; i < g.names.length; i++)
        '${g.names[i]}${g.wm ? '\nSÄTZE ${g.sets[i]} · LEGS ${g.legs[i]}' : ''}\nØ ${g.avg(i)} · ${g.thrown[i]} Darts',
    ];
  }

  Widget _win(BuildContext c) {
    return WinScreen(
      g: g,
      title: 'GEWINNER',
      sound: true,
      who: g.winner!,
      lines: _lines(),
      nextLabel: 'REVANCHE',
      onUndo: () => setState(g.undo),
      onNext: () => Navigator.pushReplacement(
        c,
        MaterialPageRoute(builder: (_) => GamePage(Game(g.names, g.start, g.dbl,
            wm: g.wm, setsToWin: g.setsToWin, tieBreak: g.tieBreak, doubleIn: g.doubleIn, masterOut: g.masterOut), songs: widget.songs)),
      ),
      onMenu: () => Navigator.pop(c),
    );
  }

  Widget _legScreen(BuildContext c) {
    return WinScreen(
      g: g,
      title: g.setWinner != null ? 'SATZ GEWONNEN' : 'LEG GEWONNEN',
      who: g.names[g.legWinner!],
      lines: [for (var i = 0; i < g.names.length; i++) '${g.names[i]}\nSÄTZE ${g.sets[i]} · LEGS ${g.legs[i]} · Ø ${g.avg(i)}'],
      nextLabel: 'NÄCHSTES LEG',
      onUndo: () => setState(g.undo),
      onNext: () => setState(() {
        g.nextLeg();
        armed = false;
        base = null;
        info = manual ? '' : '${g.names[g.cur]} antippen für Referenzbild';
      }),
      onMenu: () => Navigator.pop(c),
    );
  }

  Widget _cameraPage(CameraController? cc) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(info, textAlign: TextAlign.center)),
      Expanded(
        child: cc == null
            ? Center(
                child: camErr == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(camErr!, textAlign: TextAlign.center, style: TextStyle(color: kDim, fontSize: 12)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              setState(() => camErr = null);
                              _initCam();
                            },
                            child: const Text('Erneut versuchen'),
                          ),
                        ]),
                      ),
              )
            : LayoutBuilder(builder: (_, cons) {
                final size = cons.biggest;
                final isPortrait = size.height >= size.width;
                final camAspect = cc.value.aspectRatio;
                final previewAspect = isPortrait ? 1 / camAspect : camAspect;
                double w, h;
                if (size.width / previewAspect <= size.height) {
                  w = size.width;
                  h = w / previewAspect;
                } else {
                  h = size.height;
                  w = h * previewAspect;
                }
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: LayoutBuilder(builder: (_, k) {
                      final sz = Size(k.maxWidth, k.maxHeight);
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
                            CustomPaint(painter: _Overlay(List.of(calib), tip, diagOn.value ? blob : const [], _pulse.value, calib.length < 4)),
                          ]),
                        ),
                      );
                    }),
                  ),
                );
              }),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                g.undo();
                armed = false;
                base = null;
                pending = null;
                prev = null;
                seen = 0;
                tip = null;
                blob = [];
                info = 'Undo – ${g.names[g.cur]} antippen für Referenzbild';
              }),
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
          ),
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
              label: const Text('Kalib.'),
            ),
          ),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _tips),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext c) {
    if (walkLoading) {
      return Scaffold(body: Center(child: Text('EINLAUF WIRD GELADEN …', style: TextStyle(color: kDim, letterSpacing: 2))));
    }
    if (walkIdx < walk.length) {
      final i = walk[walkIdx], sg = widget.songs[i]!;
      return WalkInScreen(
        key: ValueKey(i),
        name: g.names[i],
        color: teamColors[i % teamColors.length],
        title: sg.title,
        artist: sg.artist,
        url: walkUrls[i]!,
        onDone: () => setState(() => walkIdx++),
      );
    }
    if (g.winner != null) return _win(c);
    if (g.legWinner != null) return _legScreen(c);
    final rem = g.scores[g.cur];
    final route = (checkoutOn.value && rem <= (g.dbl ? 170 : 180)) ? checkout(rem, g.dbl, 3 - g.darts.length) : null;

    Widget pill(int i, String t) {
      final on = (manual ? 0 : 1) == i;
      return GestureDetector(
        onTap: () => pc.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: on ? kAccent.withValues(alpha: .15) : null,
            border: Border.all(color: on ? kAccent : kLine),
          ),
          child: Text(t, style: const TextStyle(fontSize: 11, letterSpacing: 2)),
        ),
      );
    }

    final infoBox = Column(mainAxisSize: MainAxisSize.min, children: [
      if (g.wm)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'SATZ ${g.sets[0]}:${g.sets[1]}  ·  LEG ${g.legs[0]}:${g.legs[1]}   |   FIRST TO ${g.setsToWin}${g.sets[0] == g.setsToWin - 1 && g.sets[1] == g.setsToWin - 1 ? '   |   ENTSCHEIDUNG' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: kDim),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (g.msg != null) const Text('BUST   ', style: TextStyle(color: Color(0xFFFF3D8B), letterSpacing: 2, fontSize: 14)),
          if (g.doubleIn && !g.opened) Text('DOUBLE-IN OFFEN   ', style: TextStyle(color: kAccent, letterSpacing: 2, fontSize: 11)),
          if (route != null) ...[
            Text('CHECKOUT  ', style: TextStyle(color: kDim, letterSpacing: 2, fontSize: 11)),
            Text(route.map((d) => d.label).join(' · '), style: TextStyle(color: kViolet, fontSize: 18)),
          ],
        ]),
      ),
    ]);

    final pager = PageView(
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
          final baseInfo = calib.length < 4
              ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an'
              : '${g.names[g.cur]} antippen für Referenzbild';
          info = 'KAMERA-MODUS: BETA – Funktion noch in Entwicklung, Erkennung kann ungenau sein.\n\n$baseInfo';
          if (ctrl == null) _initCam();
        }
      }),
      children: [
        _keys((d) => _add(d), '↶', () => setState(g.undo)),
        _cameraPage(ctrl),
      ],
    );

    final size = MediaQuery.of(c).size;
    if (size.width > size.height) {
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            SizedBox(
              width: size.width * .38,
              child: Column(children: [
                Expanded(child: Column(children: [for (var i = 0; i < g.names.length; i++) _card(i, compact: true)])),
                infoBox,
              ]),
            ),
            Expanded(
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  pill(0, 'MANUELL'),
                  pill(1, 'KAMERA'),
                  IconButton(icon: const Icon(Icons.bar_chart, size: 18), onPressed: _showStats),
                ]),
                Expanded(child: pager),
              ]),
            ),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('DRAN: ${g.names[g.cur].toUpperCase()}'),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart), tooltip: 'Statistik', onPressed: _showStats),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: g.wm ? 212 : 180,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < g.names.length; i++) _card(i)]),
        ),
        infoBox,
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [pill(0, 'MANUELL'), pill(1, 'KAMERA')]),
        Expanded(child: pager),
      ]),
    );
  }
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final pts = <Offset>[
      for (var y = 10.0; y < s.height; y += 16)
        for (var x = 10.0; x < s.width; x += 16) Offset(x, y),
    ];
    c.drawPoints(PointMode.points, pts, Paint()..color = kInk.withValues(alpha: .07)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
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

class DotNum extends StatelessWidget {
  final String text;
  final Color color;
  final double u;
  final double reveal;
  final bool multi;
  const DotNum(this.text, this.color, {super.key, this.u = 8, this.reveal = 1, this.multi = false});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(text.length * 6 * u - u, 7 * u), painter: _DotNum(text, color, u, reveal, multi));
}

class _DotNum extends CustomPainter {
  final String text;
  final Color color;
  final double u;
  final double reveal;
  final bool multi;
  _DotNum(this.text, this.color, this.u, this.reveal, this.multi);
  @override
  void paint(Canvas c, Size s) {
    final lit = reveal * text.length * 6;
    for (var i = 0; i < text.length; i++) {
      final col = multi ? teamColors[i % teamColors.length] : color;
      final on = Paint()..color = col;
      final off = Paint()..color = col.withValues(alpha: .10);
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

class WinScreen extends StatefulWidget {
  final Game g;
  final String title;
  final String who;
  final String nextLabel;
  final List<String> lines;
  final VoidCallback onUndo;
  final VoidCallback onNext;
  final VoidCallback onMenu;
  final bool sound;
  const WinScreen({super.key, this.sound = false, required this.g, required this.title, required this.who, required this.lines, required this.nextLabel, required this.onUndo, required this.onNext, required this.onMenu});
  @override
  State<WinScreen> createState() => _WinState();
}

class _WinState extends State<WinScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  AudioPlayer? _ap;

  @override
  void initState() {
    super.initState();
    if (widget.sound && soundOn.value) {
      try {
        _ap = AudioPlayer();
        _ap!.play(AssetSource('win.mp3')).catchError((_) {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _ap?.stop();
    _ap?.dispose();
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final g = widget.g, col = teamColors[g.cur % teamColors.length];
    Widget btn(String t, VoidCallback f) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: f,
            child: FittedBox(child: Text(t)),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: col,
      body: Stack(children: [
        Positioned.fill(child: AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: _Confetti(ac.value)))),
        SafeArea(
          child: LayoutBuilder(
            builder: (_, k) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: k.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Spacer(),
                      AnimatedBuilder(
                        animation: ac,
                        builder: (_, __) => Opacity(
                          opacity: (ac.value * 10).floor() % 2 == 0 ? 1 : .3,
                          child: Text('★ ${widget.title} ★', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, letterSpacing: 6, fontSize: 18)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: FittedBox(
                          child: Text(widget.who.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 80, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))])),
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final l in widget.lines)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4))),
                      const Spacer(),
                      Row(children: [btn('ZURÜCK', widget.onUndo), btn(widget.nextLabel, widget.onNext), btn('MENÜ', widget.onMenu)]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class WalkInScreen extends StatefulWidget {
  final String name;
  final String title;
  final String artist;
  final String url;
  final Color color;
  final VoidCallback onDone;
  const WalkInScreen({super.key, required this.name, required this.title, required this.artist, required this.url, required this.color, required this.onDone});
  @override
  State<WalkInScreen> createState() => _WalkInState();
}

class _WalkInState extends State<WalkInScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  final AudioPlayer _ap = AudioPlayer();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ap.onPlayerComplete.listen((_) => _finish());
    final isLocal = !widget.url.startsWith('http');
    _ap.play(isLocal ? DeviceFileSource(widget.url) : UrlSource(widget.url)).catchError((_) {
      _finish();
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _ap.stop();
    _ap.dispose();
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: widget.color,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, k) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: k.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Spacer(),
                    const Text('★ EINLAUF ★', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, letterSpacing: 6, fontSize: 16)),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: FittedBox(
                        child: Text(widget.name.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 80, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))])),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.artist, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 15)),
                    const Spacer(),
                    SizedBox(height: 56, child: AnimatedBuilder(animation: ac, builder: (_, __) => CustomPaint(painter: _Eq(ac.value)))),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      onPressed: _finish,
                      child: const Text('ÜBERSPRINGEN'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Eq extends CustomPainter {
  final double t;
  _Eq(this.t);
  @override
  void paint(Canvas c, Size s) {
    const n = 18;
    final bw = s.width / (n * 1.6);
    for (var i = 0; i < n; i++) {
      final h = s.height * (.2 + .8 * sin(t * 2 * pi * (1 + i % 3) + i * 0.9).abs());
      c.drawRect(Rect.fromLTWH(i * bw * 1.6, s.height - h, bw, h), Paint()..color = Colors.black.withValues(alpha: .85));
    }
  }

  @override
  bool shouldRepaint(_Eq o) => o.t != t;
}

class _Confetti extends CustomPainter {
  final double t;
  _Confetti(this.t);
  @override
  void paint(Canvas c, Size s) {
    final cols = [Colors.white, Colors.black, kViolet, kAccent, const Color(0xFFFF3D8B), const Color(0xFFFFD100)];
    const n = 48;
    for (var i = 0; i < n; i++) {
      final x = (i * 0.618034 % 1) * s.width;
      final y = ((t * (1 + i % 2) + i / n) % 1) * (s.height + 20) - 10;
      final sz = 6.0 + (i % 3) * 4;
      c.drawRect(Rect.fromLTWH(x, y, sz, sz), Paint()..color = cols[i % cols.length].withValues(alpha: .85));
    }
  }

  @override
  bool shouldRepaint(_Confetti o) => o.t != t;
}

class LogoMark extends StatelessWidget {
  final double size;
  final bool fixed;
  const LogoMark(this.size, {super.key, this.fixed = false});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(size, size), painter: _Logo(fixed));
}

class _Logo extends CustomPainter {
  final bool fixed;
  _Logo(this.fixed);
  @override
  void paint(Canvas c, Size s) {
    final u = s.width;
    final ink = kInk;
    final acc = kAccent;
    final vio = kViolet;
    final pk = teamColors[2];
    for (var pass = 0; pass < 2; pass++) {
      final off = pass == 0 ? u * .035 : 0.0;
      c.save();
      c.translate(u / 2 + off, u / 2 + off);
      c.rotate(-pi / 4);
      Paint p(Color col) => Paint()..color = pass == 0 ? ink.withValues(alpha: .3) : col;
      c.drawPath(Path()..moveTo(-.46 * u, 0)..lineTo(-.34 * u, -.03 * u)..lineTo(-.34 * u, .03 * u)..close(), p(ink));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-.34 * u, -.055 * u, -.08 * u, .055 * u), Radius.circular(.02 * u)), p(acc));
      c.drawRect(Rect.fromLTRB(-.08 * u, -.018 * u, .14 * u, .018 * u), p(ink));
      c.drawPath(Path()..moveTo(.08 * u, 0)..lineTo(.2 * u, -.16 * u)..lineTo(.44 * u, -.16 * u)..lineTo(.34 * u, 0)..close(), p(vio));
      c.drawPath(Path()..moveTo(.08 * u, 0)..lineTo(.2 * u, .16 * u)..lineTo(.44 * u, .16 * u)..lineTo(.34 * u, 0)..close(), p(pk));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashState();
}

class _SplashState extends State<SplashPage> {
  Timer? _timer;
  bool gone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1250), _go);
  }

  void _go() {
    if (gone || !mounted) return;
    gone = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ModePage(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _go,
      child: Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LayoutBuilder(builder: (_, cons) {
                final shortest = MediaQuery.of(c).size.shortestSide;
                final size = (shortest * 0.42).clamp(90.0, 200.0);
                return LogoMark(size, fixed: true);
              }),
              const SizedBox(height: 32),
              FittedBox(
                child: Text(
                  'StanDart',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: kInk,
                    shadows: [Shadow(color: kAccent, offset: const Offset(4, 4)), Shadow(color: kViolet, offset: const Offset(8, 8))],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Overlay extends CustomPainter {
  final List<Offset> pts;
  final Offset? tip;
  final List<Offset> blob;
  final double pulse;
  final bool pulseActive;
  _Overlay(this.pts, this.tip, this.blob, this.pulse, this.pulseActive);

  @override
  void paint(Canvas c, Size s) {
    final thick = Paint()..color = kAccent..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final thin = Paint()..color = kAccent.withValues(alpha: .7)..style = PaintingStyle.stroke..strokeWidth = 0.8;
    Offset sc(Offset o) => Offset(o.dx * s.width, o.dy * s.height);

    for (var i = 0; i < pts.length; i++) {
      final isNext = pulseActive && i == pts.length - 1;
      c.drawCircle(sc(pts[i]), 7, thick);
      if (isNext) {
        c.drawCircle(sc(pts[i]), 12 + 6 * pulse, Paint()..color = kAccent.withValues(alpha: 0.7 * (1 - pulse))..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
    }

    if (pts.length == 4) {
      final hb = homography(boardPts, pts);
      Offset at(double r, double deg) {
        final t = deg * pi / 180;
        return sc(apply(hb, r * sin(t), -r * cos(t)));
      }
      for (final r in [1.0, 0.953, 0.629, 0.582, 0.094, 0.037]) {
        final path = Path();
        for (var i = 0; i <= 72; i++) {
          final q = at(r, i * 5.0);
          if (i == 0) {
            path.moveTo(q.dx, q.dy);
          } else {
            path.lineTo(q.dx, q.dy);
          }
        }
        c.drawPath(path, r == 1.0 ? thick : thin);
      }
      for (var k = 0; k < 20; k++) {
        c.drawLine(at(0.094, 9.0 + 18 * k), at(1.0, 9.0 + 18 * k), thin);
        final tp = TextPainter(
          text: TextSpan(text: '${order[k]}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, at(1.1, 18.0 * k) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    final bp = Paint()..color = kViolet.withValues(alpha: .6);
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
