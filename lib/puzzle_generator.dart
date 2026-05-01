import 'dart:math';
import 'solver.dart';

class Puzzle {
  final List<int> numbers;
  final int target;
  final int minSteps;
  final Solution solution;

  const Puzzle({
    required this.numbers,
    required this.target,
    required this.minSteps,
    required this.solution,
  });
}

// (poolSize, minTarget, maxTarget, minSteps)
const _tiers = [
  (3, 10,  50,  1),
  (3, 10,  50,  1),
  (4, 10, 100,  2),
  (4, 10, 100,  2),
  (5, 10, 200,  3),
  (5, 20, 200,  3),
  (6, 20, 300,  3),
  (6, 50, 300,  4),
  (6, 50, 500,  4),
  (6, 50, 500,  5),
];

const _pools = [
  [1, 2, 3, 4, 5, 6],
  [1, 2, 3, 4, 5, 6, 7, 8],
  [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15],
  [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20],
  [3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25],
  [4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 50],
  [5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 50, 75],
  [5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 50, 75, 100],
];

final _rng = Random();

Puzzle generatePuzzle(int level) {
  final tierIdx = (level - 1).clamp(0, _tiers.length - 1);
  final (poolSize, minTarget, maxTarget, minSteps) = _tiers[tierIdx];
  final pool = _pools[tierIdx];

  for (int attempt = 0; attempt < 200; attempt++) {
    final numbers = _sample(pool, poolSize);
    final reachable = explore(numbers);

    final candidates = reachable.keys
        .where((v) => v >= minTarget && v <= maxTarget && !numbers.contains(v))
        .toList();
    if (candidates.isEmpty) continue;

    final target = candidates[_rng.nextInt(candidates.length)];
    final solution = reachable[target]!;

    // Reject targets that only appear as intermediates — the stored path
    // must end with the target as the sole remaining number.
    if (solution.last.numbers.length != 1) continue;

    final steps = solution.where((s) => s.operation != null).length;
    if (steps < minSteps) continue;

    return Puzzle(
      numbers: numbers,
      target: target,
      minSteps: steps,
      solution: solution,
    );
  }

  return _fallback(poolSize);
}

// ── Streak dedup (main-thread state) ─────────────────────────────────────────

final Set<String> _seenThisStreak = {};

void resetSeenPuzzles() => _seenThisStreak.clear();

String _puzzleKey(List<int> numbers, int target) =>
    '${([...numbers]..sort()).join(",")}-$target';

bool isSeenPuzzle(List<int> numbers, int target) =>
    _seenThisStreak.contains(_puzzleKey(numbers, target));

void markPuzzleSeen(List<int> numbers, int target) =>
    _seenThisStreak.add(_puzzleKey(numbers, target));

/// Top-level wrapper for use with Flutter's compute().
/// [poolSize] is 3–6; maps to a fixed difficulty tier for that ball count.
(List<int>, int) generatePuzzleData(int poolSize) {
  const tierLevel = {3: 1, 4: 3, 5: 5, 6: 7};
  final p = generatePuzzle(tierLevel[poolSize] ?? 1);
  return (p.numbers, p.target);
}

Puzzle _fallback(int poolSize) {
  final size = poolSize.clamp(3, 6);
  final numbers = List.generate(size, (i) => i + 1);
  final target = numbers.reduce((a, b) => a + b);
  final sol = solve(numbers, target);
  assert(sol != null, 'Fallback puzzle must always be solvable');
  return Puzzle(
    numbers: numbers,
    target: target,
    minSteps: sol!.where((s) => s.operation != null).length,
    solution: sol,
  );
}

List<int> _sample(List<int> pool, int n) {
  final copy = [...pool]..shuffle(_rng);
  return copy.take(n).toList();
}

/// Top-level wrapper for compute() — takes [numbers, target] as a two-element list.
String? getHintIsolate(List<int> args) => getHint(args.sublist(0, args.length - 1), args.last);

String? getHint(List<int> numbers, int target) {
  // Try exact solution first
  final sol = solve(numbers, target);
  if (sol != null) {
    for (final step in sol) {
      if (step.operation != null) return step.operation;
    }
  }

  // Fall back: find the reachable value closest to target that requires
  // at least one operation (skip values already sitting in the pool).
  final reachable = explore(numbers);

  final candidates = reachable.entries
      .where((e) => e.value.any((s) => s.operation != null))
      .toList();

  if (candidates.isEmpty) return null;

  candidates.sort(
    (a, b) => (a.key - target).abs().compareTo((b.key - target).abs()),
  );

  for (final step in candidates.first.value) {
    if (step.operation != null) return step.operation;
  }
  return null;
}
