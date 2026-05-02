class MergeStep {
  final int a;
  final int b;
  final String op;
  final int result;

  const MergeStep({
    required this.a,
    required this.b,
    required this.op,
    required this.result,
  });

  @override
  String toString() => '$a $op $b = $result';
}

class GameState {
  final int target;
  List<int> numbers;
  int? selectedIndexA;  // index into numbers, not value
  int? selectedIndexB;
  String? selectedOp;
  final List<MergeStep> steps = [];
  final List<List<int>> _history;

  GameState({required List<int> numbers, required this.target})
      : numbers = [...numbers],
        _history = [[...numbers]];

  GameState.fromHistory({required List<List<int>> history, required this.target})
      : numbers = [...history.last],
        _history = history.map((e) => [...e]).toList();

  List<List<int>> get history => _history;

  // ── selection ────────────────────────────────────────────────────────

  int? get selectedA => selectedIndexA == null ? null : numbers[selectedIndexA!];
  int? get selectedB => selectedIndexB == null ? null : numbers[selectedIndexB!];

  bool selectIndex(int index) {
    // Deselect takes priority — check before trying to select
    if (selectedIndexA == index) {
      selectedIndexA = null;
      return true;
    }
    if (selectedIndexB == index) {
      selectedIndexB = null;
      return true;
    }
    if (selectedIndexA == null) {
      selectedIndexA = index;
      return true;
    }
    if (selectedIndexB == null) {
      selectedIndexB = index;
      return true;
    }
    return false;
  }

  void selectOp(String op) => selectedOp = op;

  void deselect() {
    selectedIndexA = null;
    selectedIndexB = null;
    selectedOp = null;
  }

  // ── merge ─────────────────────────────────────────────────────────────

  bool get canMerge =>
      selectedIndexA != null && selectedIndexB != null && selectedOp != null;

  /// Returns (success, message).
  (bool, String) merge() {
    if (!canMerge) return (false, 'Select two numbers and an operation.');

    final idxA = selectedIndexA!;
    final idxB = selectedIndexB!;
    final op = selectedOp!;
    final a = numbers[idxA];
    final b = numbers[idxB];
    final result = _compute(a, b, op);

    if (result == null) {
      deselect();
      return (false, 'Division must be exact.');
    }

    final pool = [...numbers];
    // Remove higher index first to not invalidate the lower index
    final hi = idxA > idxB ? idxA : idxB;
    final lo = idxA > idxB ? idxB : idxA;
    pool.removeAt(hi);
    pool.removeAt(lo);
    pool.add(result);

    numbers = pool;
    steps.add(MergeStep(a: a, b: b, op: op, result: result));
    _history.add([...pool]);
    deselect();
    return (true, '$a $op $b = $result');
  }

  // ── state ─────────────────────────────────────────────────────────────

  bool get isWon => numbers.length == 1 && numbers.first == target;

  bool get isFinished => numbers.length == 1;

  int get stepCount => steps.length;

  int get bestResult =>
      numbers.reduce((a, b) => (a - target).abs() < (b - target).abs() ? a : b);

  // ── undo ──────────────────────────────────────────────────────────────

  bool undo() {
    if (_history.length <= 1) return false;
    _history.removeLast();
    numbers = [..._history.last];
    if (steps.isNotEmpty) steps.removeLast();
    deselect();
    return true;
  }

  // ── helpers ───────────────────────────────────────────────────────────

  static int? _compute(int a, int b, String op) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '*': return a * b;
      case '/':
        if (b != 0 && a % b == 0) return a ~/ b;
        return null;
      default: return null;
    }
  }
}
