import 'package:flutter/material.dart';

import 'pages/calculator_page.dart';
import 'pages/records_page.dart';
import 'pages/scan_page.dart';
import 'services/record_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskThreeApp());
}

/// Root application widget.
class TaskThreeApp extends StatefulWidget {
  const TaskThreeApp({super.key});

  @override
  State<TaskThreeApp> createState() => _TaskThreeAppState();
}

class _TaskThreeAppState extends State<TaskThreeApp> {
  final RecordRepository _repository = RecordRepository();

  @override
  void initState() {
    super.initState();
    _repository.init();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalcScan Records',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeShell(repository: _repository),
    );
  }
}

/// Hosts the three pages behind a bottom navigation bar.
///
/// Pages are kept alive with an [IndexedStack] so calculator and scan state
/// survive tab switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Bridge that pushes captured numbers from the scan page into the
  /// calculator, even across tabs.
  final ValueNotifier<List<String>?> _captures = ValueNotifier(null);

  @override
  void dispose() {
    _captures.dispose();
    super.dispose();
  }

  void _useInCalculator(List<String> numbers) {
    if (numbers.isEmpty) return;
    _captures.value = numbers;
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inserted ${numbers.length} number(s) into the calculator'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CalculatorPage(
            repository: widget.repository,
            captures: _captures,
          ),
          ScanPage(
            repository: widget.repository,
            onUseInCalculator: _useInCalculator,
          ),
          RecordsPage(repository: widget.repository),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Records',
          ),
        ],
      ),
    );
  }
}
