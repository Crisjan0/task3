import 'package:flutter/material.dart';

import '../models/app_record.dart';
import '../services/calculator_engine.dart';
import '../services/record_repository.dart';

/// Page 1: a calculator that shows a basic keypad in portrait and
/// automatically switches to a scientific keypad when the device is tilted
/// into landscape.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.repository, this.captures});

  final RecordRepository repository;

  /// Fires with a comma separated list of numbers captured on the scan page.
  /// The calculator inserts them so the user can continue calculating.
  final ValueNotifier<List<String>?>? captures;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final CalculatorEngine _engine = CalculatorEngine();

  @override
  void initState() {
    super.initState();
    widget.captures?.addListener(_onCapture);
  }

  @override
  void dispose() {
    widget.captures?.removeListener(_onCapture);
    super.dispose();
  }

  void _onCapture() {
    final numbers = widget.captures?.value;
    if (numbers == null || numbers.isEmpty) return;
    // Consume the request so it is only applied once.
    widget.captures!.value = null;
    _insert(numbers.join('+'));
  }

  String _expression = '';
  String _preview = '0';
  bool _useRadians = false;
  String? _lastError;

  /// Set after `=` so the next digit starts a fresh expression.
  bool _justEvaluated = false;

  void _insert(String token) {
    setState(() {
      _lastError = null;
      if (_justEvaluated && !_isOperatorToken(token)) {
        _expression = '';
      }
      _justEvaluated = false;
      _expression += token;
      _updatePreview();
    });
  }

  bool _isOperatorToken(String token) {
    const operators = {'+', '−', '×', '÷', '^', '(', ')'};
    return operators.contains(token);
  }

  void _updatePreview() {
    if (_expression.trim().isEmpty) {
      _preview = '0';
      return;
    }
    _engine.useRadians = _useRadians;
    final result = _engine.evaluate(_expression);
    if (result.isSuccess) {
      _preview = CalculatorEngine.format(result.value!);
    } else {
      _preview = '…';
    }
  }

  void _evaluate({bool record = false}) {
    if (_expression.trim().isEmpty) return;
    _engine.useRadians = _useRadians;
    final result = _engine.evaluate(_expression);
    setState(() {
      if (result.isSuccess) {
        final formatted = CalculatorEngine.format(result.value!);
        _lastError = null;
        _preview = formatted;
        if (record) {
          widget.repository.add(
            AppRecord(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              type: RecordType.calculation,
              input: _expression,
              output: formatted,
              timestamp: DateTime.now(),
            ),
          );
        }
        _expression = formatted;
        _justEvaluated = true;
      } else {
        _lastError = result.error;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
      _justEvaluated = false;
      _updatePreview();
    });
  }

  void _clear() {
    setState(() {
      _expression = '';
      _preview = '0';
      _lastError = null;
      _justEvaluated = false;
    });
  }

  void _toggleAngleMode() {
    setState(() {
      _useRadians = !_useRadians;
      _updatePreview();
    });
  }

  void _negate() {
    setState(() {
      if (_expression.startsWith('-')) {
        _expression = _expression.substring(1);
      } else {
        _expression = '-$_expression';
      }
      _updatePreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          IconButton(
            tooltip: _useRadians ? 'Radians' : 'Degrees',
            onPressed: _toggleAngleMode,
            icon: Text(
              _useRadians ? 'RAD' : 'DEG',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDisplay(context),
            Expanded(
              child: isLandscape
                  ? _buildScientificKeypad()
                  : _buildBasicKeypad(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: Text(
              _expression.isEmpty ? '0' : _expression,
              key: ValueKey(_expression),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_lastError != null)
            Text(
              _lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _preview,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Keypads
  // ---------------------------------------------------------------------------

  Widget _buildBasicKeypad() {
    final rows = <List<_Key>>[
      [
        _Key('C', _clear, type: _KeyType.function),
        _Key('( )', () => _toggleParenthesis(), type: _KeyType.function),
        _Key('%', () => _insert('%'), type: _KeyType.function),
        _Key('÷', () => _insert('÷'), type: _KeyType.operator),
      ],
      [
        _Key('7', () => _insert('7')),
        _Key('8', () => _insert('8')),
        _Key('9', () => _insert('9')),
        _Key('×', () => _insert('×'), type: _KeyType.operator),
      ],
      [
        _Key('4', () => _insert('4')),
        _Key('5', () => _insert('5')),
        _Key('6', () => _insert('6')),
        _Key('−', () => _insert('-'), type: _KeyType.operator),
      ],
      [
        _Key('1', () => _insert('1')),
        _Key('2', () => _insert('2')),
        _Key('3', () => _insert('3')),
        _Key('+', () => _insert('+'), type: _KeyType.operator),
      ],
      [
        _Key('±', _negate, type: _KeyType.function),
        _Key('0', () => _insert('0')),
        _Key('.', () => _insert('.')),
        _Key('=', () => _evaluate(record: true), type: _KeyType.equals),
      ],
    ];
    return _KeypadGrid(rows: rows);
  }

  Widget _buildScientificKeypad() {
    final rows = <List<_Key>>[
      [
        _Key(_useRadians ? 'RAD' : 'DEG',
            _toggleAngleMode,
            type: _KeyType.function),
        _Key('sin', () => _insert('sin('), type: _KeyType.function),
        _Key('cos', () => _insert('cos('), type: _KeyType.function),
        _Key('tan', () => _insert('tan('), type: _KeyType.function),
        _Key('π', () => _insert('π'), type: _KeyType.function),
        _Key('e', () => _insert('e'), type: _KeyType.function),
      ],
      [
        _Key('C', _clear, type: _KeyType.function),
        _Key('( )', _toggleParenthesis, type: _KeyType.function),
        _Key('√', () => _insert('√('), type: _KeyType.function),
        _Key('^', () => _insert('^'), type: _KeyType.operator),
        _Key('%', () => _insert('%'), type: _KeyType.function),
        _Key('⌫', _backspace, type: _KeyType.function),
      ],
      [
        _Key('7', () => _insert('7')),
        _Key('8', () => _insert('8')),
        _Key('9', () => _insert('9')),
        _Key('÷', () => _insert('÷'), type: _KeyType.operator),
        _Key('ln', () => _insert('ln('), type: _KeyType.function),
        _Key('log', () => _insert('log10('), type: _KeyType.function),
      ],
      [
        _Key('4', () => _insert('4')),
        _Key('5', () => _insert('5')),
        _Key('6', () => _insert('6')),
        _Key('×', () => _insert('×'), type: _KeyType.operator),
        _Key('abs', () => _insert('abs('), type: _KeyType.function),
        _Key('exp', () => _insert('exp('), type: _KeyType.function),
      ],
      [
        _Key('1', () => _insert('1')),
        _Key('2', () => _insert('2')),
        _Key('3', () => _insert('3')),
        _Key('−', () => _insert('-'), type: _KeyType.operator),
        _Key('±', _negate, type: _KeyType.function),
        _Key('⌫', _backspace, type: _KeyType.function),
      ],
      [
        _Key('0', () => _insert('0'), flex: 2),
        _Key('.', () => _insert('.')),
        _Key('=', () => _evaluate(record: true), type: _KeyType.equals, flex: 3),
      ],
    ];
    return _KeypadGrid(rows: rows);
  }

  /// Inserts a matching parenthesis depending on the current balance.
  void _toggleParenthesis() {
    final opens = '('.allMatches(_expression).length;
    final closes = ')'.allMatches(_expression).length;
    final endsWithOpen = _expression.endsWith('(');
    if (opens > closes && !endsWithOpen) {
      _insert(')');
    } else {
      _insert('(');
    }
  }
}

enum _KeyType { digit, operator, function, equals }

class _Key {
  const _Key(this.label, this.onTap, {this.type = _KeyType.digit, this.flex = 1});

  final String label;
  final VoidCallback onTap;
  final _KeyType type;
  final int flex;
}

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({required this.rows});

  final List<List<_Key>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final row in rows)
            Expanded(
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      flex: key.flex,
                      child: _KeyButton(keyDef: key),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.keyDef});

  final _Key keyDef;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;
    switch (keyDef.type) {
      case _KeyType.operator:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
      case _KeyType.function:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
      case _KeyType.equals:
        background = scheme.primary;
        foreground = scheme.onPrimary;
      case _KeyType.digit:
        background = scheme.surfaceContainerHigh;
        foreground = scheme.onSurface;
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: keyDef.onTap,
          child: Center(
            child: Text(
              keyDef.label,
              style: TextStyle(
                color: foreground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
