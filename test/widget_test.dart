import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task3/main.dart';
import 'package:task3/services/calculator_engine.dart';
import 'package:task3/services/ocr_service.dart';

void main() {
  group('CalculatorEngine', () {
    test('evaluates basic arithmetic', () {
      final engine = CalculatorEngine();
      expect(engine.evaluate('2+3*4').value, 14);
      expect(engine.evaluate('10÷2').value, 5);
      expect(engine.evaluate('2×3').value, 6);
    });

    test('handles percent and powers', () {
      final engine = CalculatorEngine();
      expect(engine.evaluate('50%').value, 0.5);
      expect(engine.evaluate('2^10').value, 1024);
    });

    test('trig respects degree and radian modes', () {
      final engine = CalculatorEngine();
      expect(engine.evaluate('sin(90)').value, closeTo(1, 1e-9));
      expect(engine.evaluate('cos(0)').value, closeTo(1, 1e-9));
      engine.useRadians = true;
      expect(engine.evaluate('sin(pi/2)').value, closeTo(1, 1e-9));
    });

    test('supports logs, exp and constants', () {
      final engine = CalculatorEngine();
      expect(engine.evaluate('log10(100)').value, closeTo(2, 1e-9));
      expect(engine.evaluate('ln(e)').value, closeTo(1, 1e-9));
      expect(engine.evaluate('exp(2)').value, closeTo(7.389056, 1e-5));
    });

    test('reports errors for invalid input', () {
      final engine = CalculatorEngine();
      expect(engine.evaluate('1/0').isSuccess, isFalse);
      expect(engine.evaluate('abc').isSuccess, isFalse);
    });

    test('formats numbers without trailing zeros', () {
      expect(CalculatorEngine.format(4.0), '4');
      expect(CalculatorEngine.format(4.5), '4.5');
    });
  });

  group('OcrService.extractNumbers', () {
    test('extracts integers and decimals', () {
      expect(OcrService.extractNumbers('Total 12 and 3.5'), ['12', '3.5']);
    });

    test('normalizes thousands separators', () {
      expect(OcrService.extractNumbers('1,234'), ['1234']);
    });

    test('handles negative numbers', () {
      expect(OcrService.extractNumbers('temp -8 degrees'), ['-8']);
    });
  });

  testWidgets('app boots with three navigation destinations', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TaskThreeApp());
    await tester.pumpAndSettle();

    expect(find.text('Calculator'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Records'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
