import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

final darkMode = ValueNotifier<bool>(true), vibOn = ValueNotifier<bool>(true), soundOn = ValueNotifier<bool>(true);
final diagOn = ValueNotifier<bool>(false), autoFit = ValueNotifier<bool>(true);
String diagWhy = '';
Color kBg = const Color(0xFF09080F), kCard = const Color(0xFF14121C), kLine = const Color(0xFF2B2838);
Color kInk = const Color(0xFFF4F2FA), kDim = const Color(0xFF9A97A8), kOnAccent = Colors.black;
Color kAccent = const Color(0xFF1AE5D0), kViolet = const Color(0xFF9A6BFF);
List<Color> teamColors = [kAccent, kViolet, const Color(0xFFFF5FA2), const Color(0xFFFFD23F)];

void applyTheme(bool d) {
  if (d) {
    kBg = const Color(0xFF09080F); kCard = const Color(0xFF14121C); kLine = const Color(0xFF2B2838);
    kInk = const Color(0xFFF4F2FA); kDim = const Color(0xFF9A97A8); kOnAccent = Colors.black;
    kAccent = const Color(0xFF1AE5D0); kViolet = const Color(0xFF9A6BFF);
    teamColors = [kAccent, kViolet, const Color(0xFFFF5FA2), const Color(0xFFFFD23F)];
  } else {
    kBg = const Color(0xFFF1E7D3); kCard = const Color(0xFFFBF5E6); kLine = const Color(0xFFC9BB9C);
    kInk = const Color(0xFF1B1A22); kDim = const Color(0xFF6B6558); kOnAccent = Colors.white;
    kAccent = const Color(0xFF2563EB); kViolet = const Color(0xFFE63B2E);
    teamColors = [kAccent, kViolet, const Color(0xFFFF8A00), const Color(0xFFE0A800)];
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

const order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

class Dart {
  final int n, m;
  const Dart(this.n, this.m);
  int get points => n * m;
  String get label => n == 0
      ? 'OUT'
      : n == 25
          ? (m == 2 ? 'D-Bull' : 'S-Bull')
          : '${m == 3 ? 'T' : m == 2 ? 'D' : ''}$n';
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

class Game {
  final List<String> names;
  final int start;
  final bool dbl;
  late List<int> scores, thrown;
  late List<List<Dart>> last;
  int cur = 0, turnStart;
  List<Dart> darts = [];
  String? winner, msg;
  bool hold = false, held = false;
  final bool wm, tieBreak;
  final int setsToWin;
  late List<int> legs, sets, done;
  int legStart = 0, setStart = 0;
  int? legWinner, setWinner;
  Game(this.names, this.start, this.dbl, {this.wm = false, this.setsToWin = 3, this.tieBreak = true, int first = 0})
      : turnStart = start {
    cur = first;
    legStart = first;
    setStart = first;
    legs = List.filled(names.length, 0);
    sets = List.filled(names.length, 0);
    done = List.filled(names.length, 0);
    scores = List.filled(names.length, start);
    thrown = List.filled(names.length, 0);
    last = List.generate(names.length, (_) => <Dart>[]);
    turnStart = scores[cur];
  }
  String avg(int i) => thrown[i] == 0 ? '–' : ((done[i] + start - scores[i]) / thrown[i] * 3).toStringAsFixed(1);
  int _sum() => darts.fold<int>(0, (s, d) => s + d.points);
  void add(Dart d) {
    if (winner != null || held || legWinner != null) return;
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
      if (wm) {
        _legWon();
      } else {
        winner = names[cur];
      }
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
    final won = deciding && tieBreak ? (legs[w] >= 3 && legs[w] - o >= 2) : legs[w] >= 3;
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
    msg = null;
    held = false;
    hist.clear();
    cur = legStart;
    turnStart = start;
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
        held,
        List<int>.of(legs),
        List<int>.of(sets),
        List<int>.of(done),
        legStart,
        setStart,
        legWinner,
        setWinner
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
      c += d.m == 1 ? 0 : d.m == 2 ? 1 : 3;
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

void showSettings(BuildContext c) => showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => SafeArea(
                  child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                    title: Text(darkMode.value ? 'Dunkles Design' : 'Helles Design'),
                    value: darkMode.value,
                    onChanged: (v) async {
                      darkMode.value = v;
                      set(() {});
                      (await SharedPreferences.getInstance()).setBool('dark', v);
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
              ])))));

class Song {
  final int id;
  final String title, artist;
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

Future<Song?> pickSong(BuildContext c) =>
    showModalBottomSheet<Song>(context: c, isScrollControlled: true, builder: (_) => const _SongPicker());

class _SongPicker extends StatefulWidget {
  const _SongPicker();
  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  final q = TextEditingController();
  final ap = AudioPlayer();
  List<Map<String, dynamic>> res = [];
  bool busy = false;
  String? err;
  int? playing;

  @override
  void initState() {
    super.initState();
    ap.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = null);
    });
  }

  @override
  void dispose() {
    ap.stop();
    ap.dispose();
    q.dispose();
    super.dispose();
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
      final list = [
        for (final e in (j['data'] as List? ?? []))
          if (e is Map<String, dynamic> && '${e['preview'] ?? ''}'.isNotEmpty) e
      ];
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
          err = 'Suche fehlgeschlagen – ist das Internet an?';
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => SafeArea(
      child: Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.of(c).viewInsets.bottom),
          child: SizedBox(
              height: MediaQuery.of(c).size.height * .75,
              child: Column(children: [
                TextField(
                    controller: q,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                    decoration: InputDecoration(
                        labelText: 'Song oder Interpret suchen (Deezer)',
                        suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 8),
                if (busy) const LinearProgressIndicator(),
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
                            }),
                        onTap: () => Navigator.pop(
                            c, Song(e['id'] as int, '${e['title']}', '${(e['artist'] as Map?)?['name'] ?? ''}'))),
                ])),
              ]))));

class ModePage extends StatelessWidget {
  const ModePage({super.key});
  Widget tile(BuildContext c, String big, String small, Color col, VoidCallback f) {
    final txt = col.computeLuminance() > .35 ? Colors.black : Colors.white;
    return GestureDetector(
        onTap: f,
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: kInk.withValues(alpha: .3), offset: const Offset(6, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(small, style: TextStyle(color: txt, fontSize: 11, letterSpacing: 2)),
              const Spacer(),
              FittedBox(child: Text(big, style: TextStyle(color: txt, fontSize: 60, fontWeight: FontWeight.w900))),
            ])));
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (c, _, __) {
        void go(int? pts, bool wm) =>
            Navigator.push(c, MaterialPageRoute(builder: (_) => SetupPage(startPts: pts, wm: wm)));
        return Scaffold(
            appBar: AppBar(title: const Text('MODUS WÄHLEN'), actions: [
              IconButton(icon: const Icon(Icons.settings), onPressed: () => showSettings(c))
            ]),
            body: GridView.count(
                crossAxisCount: MediaQuery.of(c).size.width > MediaQuery.of(c).size.height ? 4 : 2,
                mainAxisSpacing: 22,
                crossAxisSpacing: 22,
                padding: const EdgeInsets.all(24),
                children: [
                  tile(c, '501', 'FREIES SPIEL', teamColors[0], () => go(501, false)),
                  tile(c, '301', 'FREIES SPIEL', teamColors[1], () => go(301, false)),
                  tile(c, '701', 'FREIES SPIEL', teamColors[2], () => go(701, false)),
                  tile(c, 'WM', 'SÄTZE & LEGS', teamColors[3], () => go(null, true)),
                ]));
      });
}

class SetupPage extends StatefulWidget {
  final int? startPts;
  final bool wm;
  const SetupPage({super.key, this.startPts, this.wm = false});
  @override
  State<SetupPage> createState() => _SetupState();
}

class _SetupState extends State<SetupPage> {
  int players = 2, start = 501, round = 1, first = 0;
  bool dbl = true, wm = false;
  static const _rounds = ['Runde 1 (kein Tie-Break)', 'Runde 2', 'Runde 3/4', 'Viertelfinale', 'Halbfinale', 'Finale'];
  static const _setsTo = [3, 3, 4, 5, 6, 7];
  int get n => wm ? 2 : players;
  final ctr = [for (var i = 1; i <= 4; i++) TextEditingController(text: 'Spieler $i')];
  final songs = List<Song?>.filled(4, null);

  Widget _sec(String t, Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(letterSpacing: 2, color: kDim, fontSize: 12)),
        const SizedBox(height: 10),
        child
      ]));

  Widget _songRow(int i) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () async {
                  final s = await pickSong(context);
                  if (s != null) setState(() => songs[i] = s);
                },
                icon: const Icon(Icons.music_note, size: 18),
                label: Text(songs[i] == null ? 'EINLAUFSONG WÄHLEN' : '${songs[i]!.title} – ${songs[i]!.artist}',
                    maxLines: 1, overflow: TextOverflow.ellipsis))),
        if (songs[i] != null)
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => songs[i] = null)),
      ]));

  Widget _names() => Column(children: [
        for (var i = 0; i < n; i++) ...[
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                  controller: ctr[i],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Name ${i + 1}',
                      prefixIcon: Icon(Icons.circle, color: teamColors[i], size: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))))),
          if (wm) _songRow(i),
        ]
      ]);

  @override
  void initState() {
    super.initState();
    wm = widget.wm;
    if (widget.startPts != null) start = widget.startPts!;
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final n = p.getStringList('names');
      setState(() {
        players = p.getInt('players') ?? players;
        start = widget.startPts ?? p.getInt('start') ?? start;
        dbl = p.getBool('dbl') ?? dbl;
        for (var i = 0; i < 4; i++) {
          songs[i] = Song.from(p.getString('song$i'));
        }
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
    for (var i = 0; i < 4; i++) {
      if (songs[i] == null) {
        await p.remove('song$i');
      } else {
        await p.setString('song$i', songs[i]!.toJson());
      }
    }
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (c, _, __) => Scaffold(
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
                          segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))],
                          selected: {players},
                          onSelectionChanged: (s) => setState(() => players = s.first)),
                      const SizedBox(height: 12),
                      _names(),
                    ]))
              else
                _sec('SPIELER', _names()),
              if (!wm)
                _sec(
                    'SPIEL $start',
                    Column(children: [
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Double-Out'),
                          value: dbl,
                          onChanged: (v) => setState(() => dbl = v)),
                    ]))
              else ...[
                _sec(
                    'FORMAT',
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, children: [
                        for (var i = 0; i < _rounds.length; i++)
                          ChoiceChip(label: Text(_rounds[i]), selected: round == i, onSelected: (_) => setState(() => round = i))
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          'First to ${_setsTo[round]} Sätze · Satz = first to 3 Legs · 501 · Double-Out\nAnwurf wechselt je Leg und Satz.\nEntscheidungssatz: 2 Legs Vorsprung.',
                          style: TextStyle(fontSize: 11, color: kDim)),
                    ])),
                _sec(
                    'BULL-UP: WER WIRFT ZUERST?',
                    Wrap(spacing: 8, children: [
                      for (var i = 0; i < 2; i++)
                        ChoiceChip(
                            label: Text(ctr[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctr[i].text.trim()),
                            selected: first == i,
                            onSelected: (_) => setState(() => first = i))
                    ])),
              ],
            ])),
            FilledButton(
                onPressed: () {
                  _saveSetup();
                  Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => GamePage(Game([
                              for (var i = 0; i < n; i++)
                                ctr[i].text.trim().isEmpty ? 'Spieler ${i + 1}' : ctr[i].text.trim()
                            ], wm ? 501 : start, wm ? true : dbl,
                            wm: wm, setsToWin: _setsTo[round], tieBreak: round != 0, first: first), songs: wm ? songs.sublist(0, 2) : const <Song?>[])));
                },
                child: const Text('Spiel starten')),
          ]),
        ),
      ));
}

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
  final Offset tip, board;
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
  bool armed = false, auto = true, busy = false;
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
  int mult = 1;
  final pc = PageController(initialPage: 0);
  int? drag;
  int seen = 0;
  Gray? refG;
  List<Offset>? refCalib;
  bool calDirty = true;
  String info = '';
  Timer? timer;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    info = calib.length < 4
        ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an'
        : '${g.names[g.cur]} antippen, um zu starten';
    g.hold = false;
    walkLoading = g.wm && soundOn.value && widget.songs.any((s) => s != null);
    if (walkLoading) _prepareWalkIns();
    timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
  }

  Future<void> _prepareWalkIns() async {
    final list = <int>[];
    for (var i = 0; i < widget.songs.length; i++) {
      final sg = widget.songs[i];
      if (sg == null) continue;
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
      setState(() => camErr = t.toLowerCase().contains('permission') || t.contains('Access')
          ? 'Kamera-Berechtigung fehlt.\nAndroid-Einstellungen → Apps → StanDart → Berechtigungen → Kamera erlauben.\n\n$t'
          : 'Kamera konnte nicht starten:\n$t');
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
        refG = cur;
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
    Widget big(String t, VoidCallback f) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: f,
                child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: kInk.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kLine, width: 1.5)),
                    child: FittedBox(child: Text(t, style: TextStyle(fontSize: 18, color: kInk)))))));
    Widget cell(int n) => Expanded(
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: kInk.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kLine, width: 1.5)),
                child: Column(children: [
                  Expanded(
                      flex: 3,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onPick(Dart(n, 1)),
                          child: Center(
                              child: FittedBox(
                                  child: Text('$n',
                                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: kInk)))))),
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
                                      color: (m == 2 ? kViolet : teamColors[2]).withValues(alpha: .28),
                                      child: Text(m == 2 ? 'D' : 'T',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kInk))))),
                      ])),
                ]))));
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
                ])),
            for (var r = 0; r < rows; r++)
              Expanded(
                  flex: 4,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var c = 0; c < cols; c++) cell(r * cols + c + 1)
                  ])),
          ]));
    });
  }

  void _edit(int k) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => SizedBox(
              height: min(430.0, MediaQuery.of(c).size.height * .9),
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

  Widget _pill2(String t, int n, Color col) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withValues(alpha: .6))),
      child: Text('$t $n', style: TextStyle(fontSize: 10, color: kInk, fontWeight: FontWeight.bold)));

  Widget _compact(int i, Color col, bool cur, List<Dart> ds, bool canEdit) => Row(children: [
        Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${g.wm && g.legStart == i ? '◆ ' : ''}${cur && armed ? '● ' : ''}${g.names[i].toUpperCase()}${g.wm ? '  S${g.sets[i]} L${g.legs[i]}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, letterSpacing: 1, color: col)),
          Expanded(child: FittedBox(child: DotNum('${g.scores[i]}', kInk))),
          Text('Ø ${g.avg(i)}', style: TextStyle(fontSize: 10, color: kDim)),
        ])),
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
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: canEdit && k < ds.length ? col : kLine)),
                            child: k < ds.length
                                ? FittedBox(child: Text(ds[k].label, style: TextStyle(fontSize: 11, color: kInk)))
                                : null)))
            ])),
      ]);

  Widget _card(int i, {bool compact = false}) {
    final col = teamColors[i % teamColors.length];
    final cur = i == g.cur;
    final ds = cur ? g.darts : g.last[i];
    final nextI = (g.cur + 1) % g.names.length;
    final canEdit = cur && g.held && !manual;
    final pulseActive = cur && g.winner == null && g.legWinner == null;

    final Widget content = compact ? _compact(i, col, cur, ds, canEdit) : Column(children: [
      Text('${g.wm && g.legStart == i ? '◆ ' : ''}${cur && armed ? '● ' : ''}${g.names[i].toUpperCase()}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, letterSpacing: 2, color: col)),
      if (g.wm)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _pill2('SÄTZE', g.sets[i], col),
              const SizedBox(width: 6),
              _pill2('LEGS', g.legs[i], col),
            ])),
      const SizedBox(height: 4),
      FittedBox(child: DotNum('${g.scores[i]}', kInk)),
      Text('Ø ${g.avg(i)}${g.last[i].isNotEmpty ? '  ·  ZUG ${g.last[i].fold<int>(0, (a, d) => a + d.points)}' : ''}',
          style: TextStyle(fontSize: 11, color: kDim)),
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
    ]);

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
                final pv = pulseActive ? (0.35 + 0.65 * _pulse.value) : 1.0;
                return Container(
                    margin: compact ? const EdgeInsets.fromLTRB(4, 4, 8, 6) : const EdgeInsets.fromLTRB(5, 5, 9, 9),
                    padding: EdgeInsets.all(compact ? 6 : 10),
                    decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: cur
                                ? col.withValues(alpha: pv)
                                : (g.held && i == nextI ? col : kLine),
                            width: cur ? 2 : 1.5),
                        boxShadow: cur
                            ? [BoxShadow(color: col.withValues(alpha: 0.45 * pv), offset: const Offset(4, 4))]
                            : null),
                    child: child);
              },
              child: content,
            )));
  }

  List<String> _lines() => [
        for (var i = 0; i < g.names.length; i++)
          '${g.names[i]}${g.wm ? '\nSÄTZE ${g.sets[i]} · LEGS ${g.legs[i]}' : ''}\nØ ${g.avg(i)} · ${g.thrown[i]} Darts'
      ];

  Widget _win(BuildContext c) => WinScreen(
      g: g,
      title: 'GEWINNER',
      sound: true,
      who: g.winner!,
      lines: _lines(),
      nextLabel: 'REVANCHE',
      onUndo: () => setState(g.undo),
      onNext: () => Navigator.pushReplacement(
          c,
          MaterialPageRoute(
              builder: (_) => GamePage(Game(g.names, g.start, g.dbl, wm: g.wm, setsToWin: g.setsToWin, tieBreak: g.tieBreak), songs: widget.songs))),
      onMenu: () => Navigator.pop(c));

  Widget _legScreen(BuildContext c) => WinScreen(
      g: g,
      title: g.setWinner != null ? 'SATZ GEWONNEN' : 'LEG GEWONNEN',
      who: g.names[g.legWinner!],
      lines: [
        for (var i = 0; i < g.names.length; i++) '${g.names[i]}\nSÄTZE ${g.sets[i]} · LEGS ${g.legs[i]} · Ø ${g.avg(i)}'
      ],
      nextLabel: 'NÄCHSTES LEG',
      onUndo: () => setState(g.undo),
      onNext: () => setState(() {
            g.nextLeg();
            armed = false;
            base = null;
            info = manual ? '' : '${g.names[g.cur]} antippen für Referenzbild';
          }),
      onMenu: () => Navigator.pop(c));

  Widget _cameraPage(CameraController? cc) => Column(children: [
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
                                  child: const Text('Erneut versuchen')),
                            ])))
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
                                        CustomPaint(
                                            painter: _Overlay(
                                                List.of(calib),
                                                tip,
                                                diagOn.value ? blob : const [],
                                                _pulse.value,
                                                calib.length < 4)),
                                      ])));
                            })));
                  })),
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
                    label: const Text('Undo'))),
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
    if (walkLoading) {
      return Scaffold(
          body: Center(child: Text('EINLAUF WIRD GELADEN …', style: TextStyle(color: kDim, letterSpacing: 2))));
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
          onDone: () => setState(() => walkIdx++));
    }
    if (g.winner != null) return _win(c);
    if (g.legWinner != null) return _legScreen(c);
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
                  color: on ? kAccent.withValues(alpha: .15) : null,
                  border: Border.all(color: on ? kAccent : kLine)),
              child: Text(t, style: const TextStyle(fontSize: 11, letterSpacing: 2))));
    }

    final infoBox = Column(mainAxisSize: MainAxisSize.min, children: [
      if (g.wm)
        Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
                'SATZ ${g.sets[0]}:${g.sets[1]}  ·  LEG ${g.legs[0]}:${g.legs[1]}   |   FIRST TO ${g.setsToWin}'
                '${g.sets[0] == g.setsToWin - 1 && g.sets[1] == g.setsToWin - 1 ? '   |   ENTSCHEIDUNG' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, letterSpacing: 2, color: kDim))),
      Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (g.msg != null)
              const Text('BUST   ', style: TextStyle(color: Color(0xFFFF6B8A), letterSpacing: 2, fontSize: 14)),
            if (route != null) ...[
              Text('CHECKOUT  ', style: TextStyle(color: kDim, letterSpacing: 2, fontSize: 11)),
              Text(route.map((d) => d.label).join(' · '), style: TextStyle(color: kViolet, fontSize: 18)),
            ],
          ])),
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
          info = calib.length < 4
              ? 'Kalibrieren: tippe im Bild ${calibNames[calib.length]} am Außenrand des Doppelrings an'
              : '${g.names[g.cur]} antippen für Referenzbild';
          if (ctrl == null) _initCam();
        }
      }),
      children: [
        _keys((d) {
          mult = 1;
          _add(d);
        }, setState, '↶', () => setState(g.undo)),
        _cameraPage(ctrl)
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
            ])),
        Expanded(
            child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            pill(0, 'MANUELL'),
            pill(1, 'KAMERA'),
            if (!manual) ...[
              const SizedBox(width: 8),
              const Text('Auto'),
              Switch(value: auto, onChanged: (v) => setState(() => auto = v))
            ],
          ]),
          Expanded(child: pager),
        ])),
      ])));
    }
    return Scaffold(
      appBar: AppBar(title: Text('DRAN: ${g.names[g.cur].toUpperCase()}'), actions: [
        if (!manual) const Text('Auto'),
        if (!manual) Switch(value: auto, onChanged: (v) => setState(() => auto = v)),
      ]),
      body: Column(children: [
        SizedBox(
            height: g.wm ? 212 : 180,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < g.names.length; i++) _card(i)
            ])),
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
        for (var x = 10.0; x < s.width; x += 16) Offset(x, y)
    ];
    c.drawPoints(PointMode.points, pts,
        Paint()..color = kInk.withValues(alpha: .07)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
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
      final on = Paint()..color = col, off = Paint()..color = col.withValues(alpha: .10);
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
  final String title, who, nextLabel;
  final List<String> lines;
  final VoidCallback onUndo, onNext, onMenu;
  final bool sound;
  const WinScreen(
      {super.key,
      this.sound = false,
      required this.g,
      required this.title,
      required this.who,
      required this.lines,
      required this.nextLabel,
      required this.onUndo,
      required this.onNext,
      required this.onMenu});
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
                            child: Text('★ ${widget.title} ★',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black, letterSpacing: 6, fontSize: 18)))),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: FittedBox(
                            child: Text(widget.who.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))])))),
                    const SizedBox(height: 28),
                    for (final l in widget.lines)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(l,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4))),
                    const Spacer(),
                    Row(children: [btn('ZURÜCK', widget.onUndo), btn(widget.nextLabel, widget.onNext), btn('MENÜ', widget.onMenu)]),
                  ]))))))),
        ]));
  }
}

class WalkInScreen extends StatefulWidget {
  final String name, title, artist, url;
  final Color color;
  final VoidCallback onDone;
  const WalkInScreen(
      {super.key,
      required this.name,
      required this.title,
      required this.artist,
      required this.url,
      required this.color,
      required this.onDone});
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
    _ap.play(UrlSource(widget.url)).catchError((_) {
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
  Widget build(BuildContext c) => Scaffold(
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
                                const Text('★ EINLAUF ★',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54, letterSpacing: 6, fontSize: 16)),
                                const SizedBox(height: 16),
                                TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1000),
                                    curve: Curves.elasticOut,
                                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                                    child: FittedBox(
                                        child: Text(widget.name.toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 80,
                                                fontWeight: FontWeight.bold,
                                                shadows: [Shadow(color: Colors.white, offset: Offset(5, 5))])))),
                                const SizedBox(height: 28),
                                Text(widget.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(widget.artist,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.black87, fontSize: 15)),
                                const Spacer(),
                                SizedBox(
                                    height: 56,
                                    child: AnimatedBuilder(
                                        animation: ac, builder: (_, __) => CustomPaint(painter: _Eq(ac.value)))),
                                const SizedBox(height: 16),
                                FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                                    onPressed: _finish,
                                    child: const Text('ÜBERSPRINGEN')),
                              ]))))))));
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
    final cols = [Colors.white, Colors.black, kViolet, kAccent, const Color(0xFFFF5FA2), const Color(0xFFFFD23F)];
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
    final ink = fixed ? const Color(0xFFF4F2FA) : kInk, acc = fixed ? const Color(0xFF1AE5D0) : kAccent;
    final vio = fixed ? const Color(0xFF9A6BFF) : kViolet, pk = fixed ? const Color(0xFFFF5FA2) : teamColors[2];
    for (var pass = 0; pass < 2; pass++) {
      final off = pass == 0 ? u * .035 : 0.0;
      c.save();
      c.translate(u / 2 + off, u / 2 + off);
      c.rotate(-pi / 4);
      Paint p(Color col) => Paint()..color = pass == 0 ? ink.withValues(alpha: .3) : col;
      c.drawPath(Path()..moveTo(-.46 * u, 0)..lineTo(-.34 * u, -.03 * u)..lineTo(-.34 * u, .03 * u)..close(), p(ink));
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(-.34 * u, -.055 * u, -.08 * u, .055 * u), Radius.circular(.02 * u)), p(acc));
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
    _timer = Timer(const Duration(seconds: 4), _go);
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
        backgroundColor: const Color(0xFF09080F),
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (_, cons) {
                    final shortest = MediaQuery.of(c).size.shortestSide;
                    final size = (shortest * 0.42).clamp(90.0, 200.0);
                    return LogoMark(size, fixed: true);
                  },
                ),
                const SizedBox(height: 32),
                const FittedBox(
                  child: Text(
                    'StanDart',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Color(0xFF1AE5D0), offset: Offset(4, 4)),
                        Shadow(color: Color(0xFF9A6BFF), offset: Offset(8, 8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    final thick = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final thin = Paint()
      ..color = kAccent.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    Offset sc(Offset o) => Offset(o.dx * s.width, o.dy * s.height);

    final pulsePaint = Paint()
      ..color = kAccent.withValues(alpha: pulseActive ? 0.35 + 0.65 * pulse : 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var i = 0; i < pts.length; i++) {
      final isNext = pulseActive && i == pts.length - 1;
      c.drawCircle(sc(pts[i]), 7, isNext ? pulsePaint : thick);
      if (isNext) {
        c.drawCircle(sc(pts[i]), 12 + 6 * pulse, Paint()
          ..color = kAccent.withValues(alpha: 0.4 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
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
