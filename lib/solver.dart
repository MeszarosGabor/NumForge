// BFS over all arithmetic combinations, mirrors nyt_digits_solver behaviour.

class Step {
  final List<int> numbers;
  final String? operation; // null for initial state

  const Step({required this.numbers, this.operation});
}

typedef Solution = List<Step>;

/// Returns every value reachable from [numbers] mapped to the shortest
/// sequence of Steps that produces it.
Map<int, Solution> explore(List<int> numbers) {
  final results = <int, Solution>{};
  final visited = <String>{};
  final initial = Step(numbers: List.unmodifiable(numbers), operation: null);
  _dfs([...numbers], [initial], results, visited);
  return results;
}

void _dfs(List<int> pool, List<Step> path, Map<int, Solution> results, Set<String> visited) {
  // Skip pools we have already explored (order-independent dedup)
  final key = ([...pool]..sort()).join(',');
  if (!visited.add(key)) return;

  // Record every number currently in the pool.
  // Callers that need terminal-only reachability must check
  // whether solution.last.numbers.length == 1.
  for (final n in pool) {
    results[n] ??= List.unmodifiable(path);
  }

  if (pool.length == 1) return;

  for (int i = 0; i < pool.length; i++) {
    for (int j = 0; j < pool.length; j++) {
      if (i == j) continue;
      final a = pool[i];
      final b = pool[j];

      for (final op in const ['+', '-', '*', '/']) {
        final result = _compute(a, b, op);
        if (result == null) continue;

        final next = [...pool]
          ..removeAt(i > j ? i : i)
          ..removeAt(i > j ? j : j - 1)
          ..add(result);

        final step = Step(
          numbers: List.unmodifiable(next),
          operation: '$a$op$b',
        );
        _dfs(next, [...path, step], results, visited);
      }
    }
  }
}

int? _compute(int a, int b, String op) {
  switch (op) {
    case '+':
      return a + b;
    case '-':
      final r = a - b;
      return r > 0 ? r : null;
    case '*':
      return a * b;
    case '/':
      if (b != 0 && a % b == 0) return a ~/ b;
      return null;
    default:
      return null;
  }
}

/// Returns the first solution path to [target], or null if unreachable.
Solution? solve(List<int> numbers, int target) {
  return explore(numbers)[target];
}
