import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'game_state.dart';
import 'puzzle_generator.dart';

late SharedPreferences _prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _prefs = await SharedPreferences.getInstance();
  for (final level in [3, 4, 5, 6]) {
    _levelStreaks[level] = _prefs.getInt('streak_$level') ?? 0;
    _levelHints[level]  = _prefs.getInt('hints_$level')  ?? initHints;
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const NumForgeApp());
}

void _saveLevel(int level) {
  _prefs.setInt('streak_$level', _levelStreaks[level] ?? 0);
  _prefs.setInt('hints_$level',  _levelHints[level]  ?? initHints);
}

// Per-level streak and hint tracking (app-session scoped)
final _levelStreaks = {3: 0, 4: 0, 5: 0, 6: 0};
final _levelHints  = {3: initHints, 4: initHints, 5: initHints, 6: initHints};

// ── App ───────────────────────────────────────────────────────────────────────

class NumForgeApp extends StatelessWidget {
  const NumForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NumForge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: cBg),
      home: const SplashScreen(),
    );
  }
}

// ── Game page ─────────────────────────────────────────────────────────────────

class _LevelPage extends StatefulWidget {
  final int level; // 3, 4, 5, or 6
  const _LevelPage({required this.level});

  @override
  State<_LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<_LevelPage> {
  GameState? _gs;
  bool _loading = true;
  String _statusMsg = '';
  Color _statusColor = cText;
  bool _finished = false;

  Color get _numColor => levelColors[widget.level] ?? cNumber;
  int get _streak => _levelStreaks[widget.level] ?? 0;
  int get _hints  => _levelHints[widget.level] ?? initHints;

  @override
  void initState() {
    super.initState();
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    setState(() => _loading = true);
    late List<int> numbers;
    late int target;
    for (int attempt = 0; attempt < puzzleRetries; attempt++) {
      (numbers, target) = await compute(generatePuzzleData, widget.level);
      if (!isSeenPuzzle(numbers, target)) break;
    }
    markPuzzleSeen(numbers, target);
    if (!mounted) return;
    setState(() {
      _gs = GameState(numbers: numbers, target: target);
      _loading = false;
      _statusMsg = '';
      _statusColor = cText;
      _finished = false;
    });
  }

  void _restart() {
    resetSeenPuzzles();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _LevelPage(level: widget.level)),
    );
  }

  void _nextLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _LevelPage(level: widget.level)),
    );
  }

  void _goHome() {
    _saveLevel(widget.level);
    _levelStreaks[widget.level] = 0;
    _levelHints[widget.level] = initHints;
    resetSeenPuzzles();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  // ── interaction ────────────────────────────────────────────────────────

  void _onNumberTap(int index) {
    final gs = _gs;
    if (_finished || gs == null) return;
    setState(() {
      gs.selectIndex(index);
      _tryMerge(gs);
    });
  }

  void _onOpTap(String op) {
    final gs = _gs;
    if (_finished || gs == null) return;
    if (gs.selectedIndexA == null) return;
    setState(() {
      gs.selectOp(op);
      _tryMerge(gs);
    });
  }

  bool _isOpAvailable() => _gs?.selectedIndexA != null;

  void _tryMerge(GameState gs) {
    if (!gs.canMerge) return;
    final (ok, msg) = gs.merge();
    _statusMsg = msg;
    _statusColor = ok ? cText : cLose;
    if (ok) _checkEnd(gs);
  }

  void _checkEnd(GameState gs) {
    if (gs.isWon) {
      _statusMsg = 'Perfect match!';
      _statusColor = cWin;
      _finished = true;
      _levelStreaks[widget.level] = _streak + 1;
      _saveLevel(widget.level);
      Future.delayed(nextLevelDelay, _nextLevel);
    } else if (gs.isFinished) {
      final diff = (gs.bestResult - gs.target).abs();
      _statusMsg = 'Solved with diff $diff — streak reset';
      _statusColor = cLose;
      _finished = true;
      _levelStreaks[widget.level] = 0;
      _levelHints[widget.level] = initHints;
      _saveLevel(widget.level);
      Future.delayed(nextLevelDelay, _restart);
    }
  }

  void _onUndo() {
    final gs = _gs;
    if (gs == null) return;
    setState(() {
      if (gs.undo()) {
        _statusMsg = 'Undone';
        _statusColor = cDim;
        _finished = false;
      }
    });
  }

  Future<void> _onHint() async {
    final gs = _gs;
    if (gs == null) return;
    if (_hints <= 0) {
      setState(() {
        _statusMsg = 'No hints left';
        _statusColor = cDim;
      });
      return;
    }
    _levelHints[widget.level] = _hints - 1;
    _saveLevel(widget.level);
    final hint = await compute(getHintIsolate, [...gs.numbers, gs.target]);
    if (!mounted) return;
    setState(() {
      _statusMsg = hint != null ? 'Hint: try $hint' : 'No hint available';
      _statusColor = cText;
    });
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = _gs;
    if (_loading || gs == null) {
      return const Scaffold(
        backgroundColor: cBg,
        body: Center(child: CircularProgressIndicator(color: cTarget)),
      );
    }

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final cx = size.width / 2;
    final cy = size.height / 2;

    return Scaffold(
      backgroundColor: cBg,
      body: Stack(children: [
        // streak counter
        Positioned(
          top: padding.top + streakTopOffset,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                '$_streak',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _numColor,
                  fontSize: streakFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'streak',
                textAlign: TextAlign.center,
                style: TextStyle(color: cDim, fontSize: 12, letterSpacing: 1.5),
              ),
            ],
          ),
        ),

        // status line
        Positioned(
          bottom: size.height * statusLineFrac,
          left: 0,
          right: 0,
          child: Text(
            _statusMsg,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _statusColor,
                fontSize: 17,
                fontWeight: FontWeight.w500),
          ),
        ),

        // corner op buttons
        ..._opButtons(gs, size, padding),

        // target bubble (centre)
        Positioned(
          left: cx - targetBubbleSize / 2,
          top: cy - targetBubbleSize / 2,
          child: _Bubble(
              label: '${gs.target}',
              color: cTarget,
              size: targetBubbleSize,
              fontSize: targetFontSize),
        ),

        // number bubbles
        ..._numberBubbles(gs, cx, cy, size),

        // bottom controls
        Positioned(
          bottom: padding.bottom + bottomCtrlPad,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hints: $_hints',
                style: const TextStyle(color: cDim, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconBtn(icon: Icons.undo, onTap: _onUndo),
                  const SizedBox(width: 12),
                  _IconBtn(
                    label: '?',
                    bgColor: _hints <= 0 ? cDim.withValues(alpha: 0.15) : null,
                    onTap: _onHint,
                  ),
                  const SizedBox(width: 12),
                  _IconBtn(icon: Icons.home, onTap: _goHome),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

  List<Widget> _opButtons(GameState gs, Size size, EdgeInsets padding) {
    final top    = padding.top + opBtnTopOffset;
    final bottom = size.height - padding.bottom - opBtnSize - bottomCtrlPad;

    final positions = {
      '+': Offset(opBtnPad, bottom),
      '−': Offset(size.width - opBtnPad - opBtnSize, bottom),
      '×': Offset(opBtnPad, top),
      '÷': Offset(size.width - opBtnPad - opBtnSize, top),
    };
    final raw = {'+': '+', '−': '-', '×': '*', '÷': '/'};

    final available = _isOpAvailable();

    return positions.entries.map((e) {
      final r = raw[e.key]!;
      final selected = gs.selectedOp == r;
      final color = selected ? cOpSel : available ? cOp : cDim;

      return Positioned(
        left: e.value.dx,
        top: e.value.dy,
        child: GestureDetector(
          onTap: () => _onOpTap(r),
          child: _Bubble(label: e.key, color: color, size: opBtnSize, fontSize: opFontSize),
        ),
      );
    }).toList();
  }

  List<Widget> _numberBubbles(GameState gs, double cx, double cy, Size size) {
    final numbers = gs.numbers;
    final n = numbers.length;
    final radius = min(size.width, size.height) * orbitRadiusFrac;

    return List.generate(n, (i) {
      final angle = (pi / 2) + i * 2 * pi / n;
      final bx = cx + radius * cos(angle) - numberBubbleSize / 2;
      final by = cy + radius * sin(angle) - numberBubbleSize / 2;
      final val = numbers[i];

      final color = gs.selectedIndexA == i
          ? cSelA
          : gs.selectedIndexB == i
              ? cSelB
              : _numColor;

      return Positioned(
        left: bx,
        top: by,
        child: GestureDetector(
          onTap: () => _onNumberTap(i),
          child: _Bubble(label: '$val', color: color, size: numberBubbleSize, fontSize: numberFontSize),
        ),
      );
    });
  }
}

// ── Level select screen ───────────────────────────────────────────────────────

class _LevelSelectScreen extends StatelessWidget {
  const _LevelSelectScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SELECT LEVEL',
              style: TextStyle(
                color: cDim,
                fontSize: 13,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: levelSelectHPad),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: levelSelectHPad),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: levelSelectSpacing,
                crossAxisSpacing: levelSelectSpacing,
                children: [3, 4, 5, 6].map((level) {
                  final color = levelColors[level]!;
                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _LevelPage(level: level)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(levelSelectRadius),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: levelNumFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'balls',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: levelLabelFontSize,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final double fontSize;

  const _Bubble({
    required this.label,
    required this.color,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              color: cText, fontSize: fontSize, fontWeight: FontWeight.bold)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color? bgColor;
  final VoidCallback onTap;
  const _IconBtn({this.label, this.icon, this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: iconBtnSize,
        height: iconBtnSize,
        decoration: BoxDecoration(
            color: bgColor ?? cDim.withValues(alpha: 0.4),
            shape: BoxShape.circle),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: cText, size: iconIconSize)
            : Text(label!,
                style: const TextStyle(color: cText, fontSize: iconFontSize)),
      ),
    );
  }
}

// ── Splash screen ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: splashFadeDuration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _play() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const _LevelSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: cBg,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(children: [
          ..._decorBubbles(cx, cy, size),

          Positioned(
            left: 0,
            right: 0,
            top: cy - titleCenterOffset,
            child: Column(children: [
              _ColorfulTitle(),
              const SizedBox(height: 12),
              const Text(
                'NUMBER MERGE PUZZLE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cDim,
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),

          Positioned(
            bottom: bottomPad + menuBtnPadBot,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuBtn(label: 'PLAY', color: cWin, onTap: _play),
                const SizedBox(height: 16),
                _MenuBtn(
                  label: 'STREAKS',
                  color: cDim.withValues(alpha: 0.3),
                  fontSize: 18,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const _StreaksScreen()),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _decorBubbles(double cx, double cy, Size size) {
    final bubbles = [
      (-cx * 0.55, -cy * 0.55, 58.0, cSelA,   '7'),
      ( cx * 0.55, -cy * 0.55, 52.0, cNumber,  '×'),
      (-cx * 0.70, -cy * 0.10, 44.0, cOpSel,   '+'),
      ( cx * 0.65, -cy * 0.15, 62.0, cSelB,    '25'),
      (-cx * 0.50,  cy * 0.35, 50.0, cOp,      '÷'),
      ( cx * 0.55,  cy * 0.38, 46.0, cTarget,  '12'),
      (-cx * 0.30, -cy * 0.75, 40.0, cWin,     '−'),
      ( cx * 0.20, -cy * 0.72, 54.0, cNumber,  '3'),
      (-cx * 0.75,  cy * 0.62, 48.0, cSelA,    '100'),
      ( cx * 0.70,  cy * 0.60, 42.0, cOpSel,   '5'),
      ( cx * 0.05,  cy * 0.68, 56.0, cSelB,    '×'),
      (-cx * 0.15,  cy * 0.50, 38.0, cWin,     '9'),
    ];

    return bubbles.map((b) {
      final (dx, dy, sz, color, label) = b;
      return Positioned(
        left: cx + dx - sz / 2,
        top:  cy + dy - sz / 2,
        child: _Bubble(label: label, color: color, size: sz, fontSize: sz * 0.38),
      );
    }).toList();
  }
}

// ── Reusable menu button ──────────────────────────────────────────────────────

class _MenuBtn extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final VoidCallback onTap;

  const _MenuBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: menuBtnWidth,
          height: menuBtnHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(menuBtnRadius),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Streaks screen ────────────────────────────────────────────────────────────

class _StreaksScreen extends StatelessWidget {
  const _StreaksScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: cText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'STREAKS',
          style: TextStyle(
            color: cDim,
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [3, 4, 5, 6].map((level) {
            final color = levelColors[level]!;
            final streak = _levelStreaks[level] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: streakDotSize,
                    height: streakDotSize,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$level balls',
                    style: const TextStyle(color: cDim, fontSize: streakLabelFont),
                  ),
                  const SizedBox(width: 32),
                  Text(
                    '$streak',
                    style: TextStyle(
                      color: color,
                      fontSize: streakScreenFont,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ColorfulTitle extends StatelessWidget {
  static const _letters = [
    ('N', Color(0xFFE5831A)),
    ('U', Color(0xFF9933CC)),
    ('M', Color(0xFF3470CC)),
    ('F', Color(0xFF33CC66)),
    ('O', Color(0xFFF2C14E)),
    ('R', Color(0xFFCC4444)),
    ('G', Color(0xFF3DCCAA)),
    ('E', Color(0xFFE5831A)),
  ];

  const _ColorfulTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _letters
          .map((e) => Text(
                e.$1,
                style: TextStyle(
                  color: e.$2,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ))
          .toList(),
    );
  }
}
