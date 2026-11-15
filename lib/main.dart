import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, File;
import 'dart:math';
import 'dart:ui' show PointMode;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final darkSetting = ValueNotifier<bool?>(null);
final darkMode = ValueNotifier<bool>(true);
final vibOn = ValueNotifier<bool>(true);
final soundOn = ValueNotifier<bool>(true);
final checkoutOn = ValueNotifier<bool>(true);

Color kBg = const Color(0xFF0A0910);
Color kCard = const Color(0xFF16141F);
Color kLine = const Color(0xFF2E2A3D);
Color kInk = const Color(0xFFF4F2FA);
Color kDim = const Color(0xFF9793A8);
Color kOnAccent = Colors.black;
Color kAccent = const Color(0xFF00E5C8);
Color kViolet = const Color(0xFF9A6BFF);
List<Color> teamColors = [
  kAccent,
  kViolet,
  const Color(0xFFFF3D8B),
  const Color(0xFFFFD100),
  const Color(0xFF00A6FF),
  const Color(0xFF6BD100),
];

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
    teamColors = [
      kAccent,
      kViolet,
      const Color(0xFFFF3D8B),
      const Color(0xFFFFD100),
      const Color(0xFF00A6FF),
      const Color(0xFF6BD100),
    ];
  } else {
    kBg = const Color(0xFFEFE3C8);
    kCard = const Color(0xFFF8EEDA);
    kLine = const Color(0xFFBFB08C);
    kInk = const Color(0xFF1A1620);
    kDim = const Color(0xFF6A5F4C);
    kOnAccent = Colors.white;
    kAccent = const Color(0xFF0043CE);
    kViolet = const Color(0xFFD32029);
    teamColors = [
      kAccent,
      kViolet,
      const Color(0xFFFF6A00),
      const Color(0xFFB58A00),
      const Color(0xFF00787A),
      const Color(0xFF4A7A00),
    ];
  }
}

Route<T> fadeRoute<T>(Widget page, {int ms = 180}) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    transitionDuration: Duration(milliseconds: ms),
    reverseTransitionDuration: Duration(milliseconds: ms),
  );
}

void feedback() {
  if (vibOn.value) HapticFeedback.mediumImpact();
  if (soundOn.value) SystemSound.play(SystemSoundType.click);
}

void tapTick() {
  if (vibOn.value) HapticFeedback.selectionClick();
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

ThemeData appTheme(bool d) {
  return ThemeData(
    brightness: d ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    fontFamily: 'monospace',
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: (d ? ColorScheme.dark() : ColorScheme.light()).copyWith(
      primary: kAccent,
      secondary: kViolet,
      surface: kBg,
    ),
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
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        foregroundColor: kInk,
        side: BorderSide(color: kLine),
      ),
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
  checkoutOn.value = p.getBool('co') ?? true;
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

class Profile {
  final String name;
  final Song? song;
  Profile(this.name, this.song);
  String toJson() => jsonEncode({'n': name, 's': song?.toJson()});
  static Profile? from(String? s) {
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map;
      return Profile('${m['n']}', Song.from(m['s'] as String?));
    } catch (_) {
      return null;
    }
  }
}

Future<List<Profile>> loadProfiles() async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList('profiles') ?? [];
  return [
    for (final s in list)
      if (Profile.from(s) != null) Profile.from(s)!,
  ];
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
  int openIdx = -1;
  List<Dart> darts = [];
  String? winner;
  String? msg;
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

  Game(
    this.names,
    this.start,
    this.dbl, {
    this.wm = false,
    this.setsToWin = 3,
    this.tieBreak = true,
    int first = 0,
    this.doubleIn = false,
    this.masterOut = false,
  }) : turnStart = start {
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
    if (winner != null || legWinner != null) return;
    _save();
    msg = null;
    thrown[cur]++;
    dartsThisTurn++;
    darts.add(d);

    if (doubleIn && !opened) {
      if (d.m == 2) {
        opened = true;
        openIdx = darts.length - 1;
      }
      if (dartsThisTurn == 3) {
        _next();
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
      _next();
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
      _next();
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

  void replace(int k, Dart d) {
    if (k < 0 || k >= darts.length) return;
    final expectedCur = cur;
    final ds = List<Dart>.of(darts);
    ds[k] = d;
    for (var i = ds.length - k; i > 0; i--) {
      undo();
    }
    for (final x in ds.skip(k)) {
      if (cur != expectedCur || winner != null || legWinner != null) break;
      add(x);
    }
  }

  void replaceLastTurn(int playerIdx, int k, Dart d) {
    if (darts.isNotEmpty) return;
    final turnDarts = last[playerIdx];
    if (k < 0 || k >= turnDarts.length || hist.length < turnDarts.length) return;
    final ds = List<Dart>.of(turnDarts);
    ds[k] = d;
    for (var i = 0; i < turnDarts.length; i++) {
      undo();
    }
    for (final x in ds) {
      if (cur != playerIdx || winner != null || legWinner != null) break;
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
    legs = h[8] as List<int>;
    sets = h[9] as List<int>;
    done = h[10] as List<int>;
    legStart = h[11] as int;
    setStart = h[12] as int;
    legWinner = h[13] as int?;
    setWinner = h[14] as int?;
    tons = h[15] as List<int>;
    highFin = h[16] as List<int>;
    bestTurn = h[17] as List<int>;
    count170 = h[18] as List<int>;
    opened = h[19] as bool;
    openIdx = h[20] as int;
    dartsThisTurn = h[21] as int;
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
  var c = 0;
  for (var i = 0; i < r.length; i++) {
    final d = r[i];
    if (i < r.length - 1) {
      if (d.m == 3 && d.n < 17) c += 10;
      if (d.m == 2 && d.n != 25) c += 6;
    } else if (dbl) {
      final prio = d.n == 25 ? 39 : d.n * 2;
      c += (60 - prio) * 1000;
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

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  if (v) HapticFeedback.mediumImpact();
                  set(() {});
                  final p = await SharedPreferences.getInstance();
                  await p.setBool('vib', v);
                },
              ),
              SwitchListTile(
                title: const Text('Ton'),
                value: soundOn.value,
                onChanged: (v) async {
                  soundOn.value = v;
                  set(() {});
                  final p = await SharedPreferences.getInstance();
                  await p.setBool('snd', v);
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
                  await p.setBool('co', v);
                },
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      });
    },
  );
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
  return await Navigator.push<Song>(c, fadeRoute(const SongPickerPage()));
}

class SongPickerPage extends StatefulWidget {
  const SongPickerPage({super.key});
  @override
  State<SongPickerPage> createState() => _SongPickerState();
}

class _SongPickerState extends State<SongPickerPage> {
  final q = TextEditingController();
  final ap = AudioPlayer();
  List> res = [];
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
      final list = >[];
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
    } catch (_) {
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

  Widget smallTile(Widget icon, String label, VoidCallback f, {Color? accent}) {
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
          icon,
          const SizedBox(height: 6),
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
          Navigator.push(c, fadeRoute(SetupPage(startPts: pts, wm: wm)));
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
                Expanded(child: smallTile(Icon(Icons.tune, color: kAccent, size: 22), 'EINSTELLUNGEN', () => showSettings(c))),
                const SizedBox(width: 12),
                Expanded(
                  child: smallTile(
                    PixelPerson(size: 22, color: kViolet),
                    'PROFILE',
                    () => Navigator.push(c, fadeRoute(const ProfilesPage())),
                    accent: kViolet,
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

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
    final result = await _editDialog();
    if (result != null) {
      profiles.add(Profile(result.$1, result.$2));
      await saveProfiles(profiles);
      setState(() {});
    }
  }

  Future<void> _edit(int i) async {
    final result = await _editDialog(
      initialName: profiles[i].name,
      initialSong: profiles[i].song,
    );
    if (result != null) {
      profiles[i] = Profile(result.$1, result.$2);
      await saveProfiles(profiles);
      setState(() {});
    }
  }

  Future<(String, Song?)?> _editDialog({String? initialName, Song? initialSong}) async {
    final nameC = TextEditingController(text: initialName ?? '');
    Song? song = initialSong;
    final isEdit = initialName != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(isEdit ? 'PROFIL BEARBEITEN' : 'NEUES PROFIL'),
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
            if (song != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: () => set(() => song = null),
                  icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                  label: const Text('SONG ENTFERNEN', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
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
      return (nameC.text.trim(), song);
    }
    return null;
  }

  Future<void> _delete(int i) async {
    profiles.removeAt(i);
    await saveProfiles(profiles);
    setState(() {});
  }

  Future<void> _updateCacheAll() async {
    int done = 0;
    for (final p in profiles) {
      if (p.song == null) continue;
      if (await songCached(p.song!.id)) continue;
      final h = HttpClient();
      try {
        final j = await deezerJson('https://api.deezer.com/track/${p.song!.id}');
        final u = '${j['preview'] ?? ''}';
        if (u.isEmpty) continue;
        final req = await h.getUrl(Uri.parse(u));
        final res = await req.close();
        final path = await songCachePath(p.song!.id);
        final f = File(path);
        await f.writeAsBytes(await res.expand((x) => x).toList());
        done++;
        if (mounted) setState(() {});
      } catch (_) {
      } finally {
        h.close();
      }
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: teamColors[i % teamColors.length],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const PixelPerson(size: 20, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(profiles[i].name, style: TextStyle(color: kInk, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(profiles[i].song == null ? 'kein Song' : '♪ ${profiles[i].song!.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: kDim, fontSize: 11)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Bearbeiten', onPressed: () => _edit(i)),
                      IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Löschen', onPressed: () => _delete(i)),
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

  @override
  void dispose() {
    for (final c in ctr) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSetup() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('players', players);
    await p.setInt('start', start);
    await p.setBool('dbl', dbl);
    await p.setBool('dblin', doubleIn);
    await p.setBool('masterout', masterOut);
  }

  Future<void> _saveCurrentProfile(int i) async {
    final name = ctr[i].text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Namen eingeben')),
      );
      return;
    }
    final idx = profiles.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    if (idx >= 0) {
      profiles[idx] = Profile(name, songs[i]);
    } else {
      profiles.add(Profile(name, songs[i]));
    }
    await saveProfiles(profiles);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profil "$name" gespeichert')),
    );
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Expanded(
                child: Text(
                  'SONG: ${songs[i]!.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: teamColors[2], fontSize: 10, letterSpacing: 1.5),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => songs[i] = null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('ENTFERNEN', style: TextStyle(color: kDim, fontSize: 10, letterSpacing: 1)),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (profiles.isNotEmpty)
              PopupMenuButton<int>(
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: teamColors[k % teamColors.length], borderRadius: BorderRadius.circular(6)),
                          child: const PixelPerson(size: 16, color: Colors.black),
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
                    border: Border.all(color: kAccent, width: 1.5),
                    color: kAccent.withValues(alpha: .12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_alt, size: 16, color: kAccent),
                    const SizedBox(width: 8),
                    Text('PROFIL LADEN', style: TextStyle(color: kAccent, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 16, color: kAccent),
                  ]),
                ),
              ),
            GestureDetector(
              onTap: () => _saveCurrentProfile(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kViolet, width: 1.5),
                  color: kViolet.withValues(alpha: .12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bookmark_add_outlined, size: 16, color: kViolet),
                  const SizedBox(width: 8),
                  Text('PROFIL SPEICHERN', style: TextStyle(color: kViolet, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
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
    final g = Game(
      names,
      wm ? 501 : start,
      wm ? true : dbl,
      wm: wm,
      setsToWin: _setsTo[round],
      tieBreak: round != 0,
      first: first,
      doubleIn: wm ? false : doubleIn,
      masterOut: wm ? false : masterOut,
    );
    final songList = songs.sublist(0, n);
    Navigator.push(c, fadeRoute(GamePage(g, songs: songList)));
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
                    _sec(
                      'SPIELER',
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SegmentedButton<int>(
                          segments: [for (var i = 1; i <= 6; i++) ButtonSegment(value: i, label: Text('$i'))],
                          selected: {players},
                          onSelectionChanged: (s) => setState(() => players = s.first),
                        ),
                        const SizedBox(height: 12),
                        _names(),
                      ]),
                    )
                  else
                    _sec('SPIELER', _names()),
                  if (!wm) ...[
                    _sec(
                      'SPIEL $start',
                      Column(children: [
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
                      ]),
                    ),
                  ] else ...[
                    _sec(
                      'FORMAT',
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 8, children: [
                          for (var i = 0; i < _rounds.length; i++)
                            ChoiceChip(label: Text(_rounds[i]), selected: round == i, onSelected: (_) => setState(() => round = i)),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          'First to ${_setsTo[round]} Sätze · Satz = first to 3 Legs · 501 · Double-Out\nAnwurf wechselt je Leg und Satz.\nEntscheidungssatz: 2 Legs Vorsprung.',
                          style: TextStyle(fontSize: 11, color: kDim),
                        ),
                      ]),
                    ),
                    _sec(
                      'BULL-UP: WER WIRFT ZUERST?',
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < 2; i++)
                          ChoiceChip(
                            label: Text(ctr[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctr[i].text.trim()),
                            selected: first == i,
                            onSelected: (_) => setState(() => first = i),
                          ),
                      ]),
                    ),
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

class GamePage extends StatefulWidget {
  final Game g;
  final List<Song?> songs;
  const GamePage(this.g, {super.key, this.songs = const []});
  @override
  State<GamePage> createState() => _GameState();
}

class _GameState extends State<GamePage> with TickerProviderStateMixin {
  Game get g => widget.g;
  List<int> walk = [];
  int walkIdx = 0;
  bool walkLoading = false;
  final walkUrls = <int, String>{};
  int? editPlayer;
  int? editSlot;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    walkLoading = soundOn.value && widget.songs.any((s) => s != null);
    if (walkLoading) _prepareWalkIns();
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

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _playHighlightSounds(int playerIdx, int oldTons, int oldFin, int old170) {
    if (g.count170[playerIdx] > old170) {
      sound180();
    } else if (g.tons[playerIdx] > oldTons) {
      sound180();
    } else if (g.highFin[playerIdx] > oldFin) {
      soundBigFish();
    }
  }

  void _onKeyInput(Dart d) {
    feedback();
    final ep = editPlayer;
    final es = editSlot;
    if (ep != null && es != null) {
      final oldTons = g.tons[ep];
      final oldFin = g.highFin[ep];
      final old170 = g.count170[ep];
      setState(() {
        if (ep == g.cur && g.darts.isNotEmpty && es < g.darts.length) {
          g.replace(es, d);
        } else if (g.darts.isEmpty && es < g.last[ep].length && g.hist.length >= g.last[ep].length) {
          g.replaceLastTurn(ep, es, d);
        }
        editPlayer = null;
        editSlot = null;
      });
      _playHighlightSounds(ep, oldTons, oldFin, old170);
      return;
    }

    final targetPlayer = g.cur;
    final oldTons = g.tons[targetPlayer];
    final oldFin = g.highFin[targetPlayer];
    final old170 = g.count170[targetPlayer];
    setState(() {
      g.add(d);
    });
    _playHighlightSounds(targetPlayer, oldTons, oldFin, old170);
  }

  void _undo() {
    tapTick();
    setState(() {
      editPlayer = null;
      editSlot = null;
      g.undo();
    });
  }

  bool _canEditSlot(int playerIdx, int slotIdx) {
    if (g.winner != null || g.legWinner != null) return false;
    if (playerIdx == g.cur && g.darts.isNotEmpty) {
      return slotIdx < g.darts.length;
    }
    final prevI = (g.cur - 1 + g.names.length) % g.names.length;
    if (g.darts.isEmpty && playerIdx == prevI && g.last[playerIdx].isNotEmpty && g.hist.length >= g.last[playerIdx].length) {
      return slotIdx < g.last[playerIdx].length;
    }
    return false;
  }

  void _toggleSlotSelection(int playerIdx, int slotIdx) {
    if (!_canEditSlot(playerIdx, slotIdx)) return;
    tapTick();
    setState(() {
      if (editPlayer == playerIdx && editSlot == slotIdx) {
        editPlayer = null;
        editSlot = null;
      } else {
        editPlayer = playerIdx;
        editSlot = slotIdx;
      }
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

  Widget _pill2(String t, int n, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withValues(alpha: .6))),
      child: Text('$t $n', style: TextStyle(fontSize: 10, color: kInk, fontWeight: FontWeight.bold)),
    );
  }

  Widget _dartBox(int playerIdx, int slotIdx, Color col, List<Dart> ds, {required bool compact}) {
    final hasDart = slotIdx < ds.length;
    final editable = _canEditSlot(playerIdx, slotIdx);
    final selected = editPlayer == playerIdx && editSlot == slotIdx;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editable ? () => _toggleSlotSelection(playerIdx, slotIdx) : null,
      child: Container(
        height: compact ? null : 26,
        margin: compact ? const EdgeInsets.symmetric(vertical: 2) : const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kViolet.withValues(alpha: .32) : (editable ? col.withValues(alpha: .08) : null),
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: selected ? kViolet : (editable ? col.withValues(alpha: .75) : kLine),
            width: selected ? 2.0 : 1.2,
          ),
        ),
        child: hasDart
            ? FittedBox(
                child: Text(
                  ds[slotIdx].label,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: selected || editable ? FontWeight.bold : FontWeight.normal,
                    color: kInk,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _compact(int i, Color col, List<Dart> ds) {
    return Row(children: [
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            '${g.wm && g.legStart == i ? '◆ ' : ''}${g.names[i].toUpperCase()}${g.wm ? '  S${g.sets[i]} L${g.legs[i]}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, letterSpacing: 1, color: col),
          ),
          Expanded(child: FittedBox(child: DotNum('${g.scores[i]}', kInk))),
          Text('Ø ${g.avg(i)}', style: TextStyle(fontSize: 10, color: kDim)),
        ]),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 52,
        child: Column(children: [
          for (var k = 0; k < 3; k++) Expanded(child: _dartBox(i, k, col, ds, compact: true)),
        ]),
      ),
    ]);
  }

  Widget _card(int i, {bool compact = false}) {
    final col = teamColors[i % teamColors.length];
    final cur = i == g.cur;
    final ds = (cur && g.darts.isNotEmpty) ? g.darts : g.last[i];
    final pulseActive = cur && g.winner == null && g.legWinner == null;

    return Expanded(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final double borderW = cur ? (pulseActive ? 2.0 + 1.4 * _pulse.value : 2.0) : 1.5;
          final double shadowOff = cur && pulseActive ? 3.0 + 3.0 * _pulse.value : 4.0;
          return Container(
            margin: compact ? const EdgeInsets.fromLTRB(4, 4, 8, 6) : const EdgeInsets.fromLTRB(5, 5, 9, 9),
            padding: EdgeInsets.all(compact ? 6 : 10),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cur ? col : kLine, width: borderW),
              boxShadow: cur ? [BoxShadow(color: col, offset: Offset(shadowOff, shadowOff))] : null,
            ),
            child: compact
                ? _compact(i, col, ds)
                : Column(children: [
                    Text(
                      '${g.wm && g.legStart == i ? '◆ ' : ''}${g.names[i].toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, letterSpacing: 2, color: col),
                    ),
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
                    Text(
                      'Ø ${g.avg(i)}${g.last[i].isNotEmpty ? '  ·  ZUG ${g.last[i].fold<int>(0, (a, d) => a + d.points)}' : ''}',
                      style: TextStyle(fontSize: 11, color: kDim),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (var k = 0; k < 3; k++) Expanded(child: _dartBox(i, k, col, ds, compact: false)),
                    ]),
                  ]),
          );
        },
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
      onUndo: _undo,
      onNext: () => Navigator.pushReplacement(
        c,
        fadeRoute(
          GamePage(
            Game(
              g.names,
              g.start,
              g.dbl,
              wm: g.wm,
              setsToWin: g.setsToWin,
              tieBreak: g.tieBreak,
              doubleIn: g.doubleIn,
              masterOut: g.masterOut,
            ),
            songs: widget.songs,
          ),
        ),
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
      onUndo: _undo,
      onNext: () => setState(() {
        editPlayer = null;
        editSlot = null;
        g.nextLeg();
      }),
      onMenu: () => Navigator.pop(c),
    );
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
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          if (editPlayer != null && editSlot != null)
            GestureDetector(
              onTap: () {
                tapTick();
                setState(() {
                  editPlayer = null;
                  editSlot = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kViolet.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kViolet, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'DART ${editSlot! + 1} (${g.names[editPlayer!]}) ÄNDERN',
                    style: TextStyle(color: kViolet, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.close, size: 14, color: kViolet),
                ]),
              ),
            )
          else ...[
            if (g.msg != null) const Text('BUST', style: TextStyle(color: Color(0xFFFF3D8B), letterSpacing: 2, fontSize: 14)),
            if (g.doubleIn && !g.opened) Text('DOUBLE-IN OFFEN', style: TextStyle(color: kAccent, letterSpacing: 2, fontSize: 11)),
            if (route != null) ...[
              Text('CHECKOUT', style: TextStyle(color: kDim, letterSpacing: 2, fontSize: 11)),
              Text(route.map((d) => d.label).join(' · '), style: TextStyle(color: kViolet, fontSize: 18)),
            ],
          ],
        ]),
      ),
    ]);

    final keypad = _keys(_onKeyInput, '↶', _undo);

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
            Expanded(child: keypad),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('DRAN: ${g.names[g.cur].toUpperCase()}'),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          SizedBox(
            height: g.wm ? 212 : 180,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < g.names.length; i++) _card(i)]),
          ),
          infoBox,
          Expanded(child: keypad),
        ]),
      ),
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
    c.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = kInk.withValues(alpha: .07)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
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
  const WinScreen({
    super.key,
    this.sound = false,
    required this.g,
    required this.title,
    required this.who,
    required this.lines,
    required this.nextLabel,
    required this.onUndo,
    required this.onNext,
    required this.onMenu,
  });
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
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
                          child: Text(
                            widget.who.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))],
                            ),
                          ),
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
  const WalkInScreen({
    super.key,
    required this.name,
    required this.title,
    required this.artist,
    required this.url,
    required this.color,
    required this.onDone,
  });
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
                        child: Text(
                          widget.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))],
                          ),
                        ),
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

class PixelPerson extends StatelessWidget {
  final double size;
  final Color color;
  const PixelPerson({super.key, this.size = 24, this.color = Colors.black});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(size, size), painter: _PixelPerson(color));
}

class _PixelPerson extends CustomPainter {
  final Color color;
  _PixelPerson(this.color);
  static const _grid = [
    '00111100',
    '01111110',
    '01111110',
    '01111110',
    '00111100',
    '00111100',
    '01111110',
    '11111111',
  ];
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 8;
    final p = Paint()..color = color;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (_grid[y][x] == '1') {
          c.drawRect(Rect.fromLTWH(x * u, y * u, u, u), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
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
    Navigator.pushReplacement(context, fadeRoute(const ModePage(), ms: 350));
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
