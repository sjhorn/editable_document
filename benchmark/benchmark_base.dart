/// Minimal benchmark harness — zero external dependencies.
///
/// Provides a [BenchmarkBase] that is API-compatible with
/// `package:benchmark_harness` so existing benchmarks need only
/// change their import.
library;

/// A simple benchmark base class.
///
/// Subclasses override [run] (the code under test) and optionally
/// [setup] and [teardown]. Call [report] to execute the benchmark
/// and print the result.
class BenchmarkBase {
  const BenchmarkBase(this.name);

  final String name;

  /// Called once before the benchmark loop.
  void setup() {}

  /// Called once after the benchmark loop.
  void teardown() {}

  /// The code being benchmarked. Override this.
  void run() {}

  /// Runs the benchmark for ~2 seconds and prints µs/iteration.
  void report() {
    setup();
    // Warm up.
    for (var i = 0; i < 10; i++) {
      run();
    }
    // Measure.
    final watch = Stopwatch()..start();
    var iterations = 0;
    while (watch.elapsedMilliseconds < 2000) {
      run();
      iterations++;
    }
    watch.stop();
    teardown();
    final usPerIteration = watch.elapsedMicroseconds / iterations;
    // Match benchmark_harness output format.
    // ignore: avoid_print
    print('$name(RunTime): $usPerIteration us.');
  }
}
