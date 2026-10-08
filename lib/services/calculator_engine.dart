import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

/// Result of evaluating an expression.
class EvalResult {
  const EvalResult({required this.value, this.error});

  final double? value;
  final String? error;

  bool get isSuccess => error == null && value != null;
}

/// A [GrammarParser] with calculator-friendly extras.
///
/// `math_expressions` only implements radian trig, so in degree mode we wrap
/// the argument of `sin`, `cos` and `tan` with a conversion to radians. We also
/// add `log10` and `exp` helpers.
class _CalculatorGrammarParser extends GrammarParser {
  _CalculatorGrammarParser({required this.degrees}) {
    if (degrees) {
      const factor = math.pi / 180;
      functions1['sin'] = (arg) => Sin(arg * Number(factor));
      functions1['cos'] = (arg) => Cos(arg * Number(factor));
      functions1['tan'] = (arg) => Tan(arg * Number(factor));
    }
    // `math_expressions` treats `log` as a two-argument function and has no
    // `log10`; expose a convenient single-argument base-10 log.
    functions1['log10'] = (arg) => Log(Number(10), arg);
  }

  final bool degrees;
}

/// Evaluates calculator expressions safely using `math_expressions`.
///
/// The engine is intentionally permissive about display-level syntax:
///  * `×` / `÷` are converted to `*` / `/`
///  * trailing operators are tolerated
///  * `π`, `e`, `√`, `^`, `sin`, `cos`, ... are understood
class CalculatorEngine {
  CalculatorEngine({this.useRadians = false});

  /// When true, trig functions interpret arguments as radians.
  bool useRadians;

  final GrammarParser _radianParser = _CalculatorGrammarParser(degrees: false);
  final GrammarParser _degreeParser = _CalculatorGrammarParser(degrees: true);

  /// Evaluates a display [expression], returning a numeric value or an error.
  EvalResult evaluate(String expression) {
    final normalized = _normalize(expression);
    if (normalized.trim().isEmpty) {
      return const EvalResult(value: null, error: 'Empty expression');
    }
    try {
      final parser = useRadians ? _radianParser : _degreeParser;
      final parsed = parser.parse(normalized);
      final evaluator = RealEvaluator(ContextModel());
      final value = evaluator.evaluate(parsed).toDouble();

      if (value.isNaN) {
        return const EvalResult(value: null, error: 'Not a number');
      }
      if (value.isInfinite) {
        return const EvalResult(value: null, error: 'Cannot divide by zero');
      }
      return EvalResult(value: value);
    } catch (_) {
      return const EvalResult(value: null, error: 'Invalid expression');
    }
  }

  String _normalize(String expression) {
    var text = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('√', 'sqrt')
        .replaceAll('π', 'pi')
        .replaceAll('exp(', 'e^(');
    // Treat `%` as a postfix operator meaning "per hundred".
    text = text.replaceAll('%', '/100');
    // Strip trailing binary operators so a half-typed expression still works.
    text = text.replaceAll(RegExp(r'[+\-*/^]+$'), '');
    return text;
  }

  /// Formats a double for display without trailing zeros / exponent noise.
  static String format(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    var text = value.toStringAsPrecision(12);
    if (text.contains('e')) {
      return value.toString();
    }
    // Remove trailing zeros introduced by precision formatting.
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }
}
