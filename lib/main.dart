import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:fl_chart/fl_chart.dart';

import 'package:app_gastos/services/auth_service.dart';
import 'package:app_gastos/services/expense_service.dart';
import 'pages/auth_page.dart';
import 'categories_page.dart';
import 'expenses_list_page.dart';
import 'pages/account_page.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../services/api_config.dart';
import '../services/auth_service.dart';



void main() => runApp(const GastosApp());

class GastosApp extends StatelessWidget {
  const GastosApp({super.key});

  @override
  Widget build(BuildContext context) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mis Gastos',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
            primary: Colors.blueAccent,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const AuthGate(),
      );

  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return const AuthPage(); // LOGIN
        }

        return const HomePage(); // APP
      },
    );
  }
}


class Expense {
  final int? id;
  final DateTime date;
  final String description;
  final double amount;
  final String category;
  final String extra;

  Expense({
    this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    required this.extra,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'description': description,
        'amount': amount,
        'category': category,
        'extra': extra,
      };

  static Expense fromJson(Map<String, dynamic> json) => Expense(
        date: DateTime.parse(json['date'] as String),
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num).toDouble(),
        category: (json['category'] as String?) ?? '',
        extra: (json['extra'] as String?) ?? '',
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _expenses = [];
  bool _loading = true;

  final List<String> _defaultCategories = const [
    'Desayuno/Fuera',
    'Compra/Supermercado',
    'Alcohol/Cervezas',
    'Regalos',
    'Transporte',
    'Ropa/Complementos',
    'Suscripciones',
    'Tabaco',
  ];

  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List<String>.from(_defaultCategories);
    _init();
  }

  Future<void> _loadCategoriesFromServer() async {
    try {
      final cats = await ExpenseService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
      });
    } catch (_) {
      // si falla, nos quedamos con las default
    }
  }

  Future<void> _init() async {
    await _loadCategoriesFromServer();
    await _loadFromServer();
  }

Future<void> _loadFromServer() async {
  setState(() => _loading = true);

  try {
    // ⬇️ Backend devuelve List<dynamic>
    final raw = await ExpenseService.fetchExpenses();

    // ⬇️ Convertimos JSON → Expense
    final items = raw
        .map((j) => Expense.fromJson(j as Map<String, dynamic>))
        .toList();

    // ⬇️ Ordenar por fecha descendente
    items.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;

    setState(() {
      _expenses
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
  }
}


  Future<void> _addExpense(Expense e) async {
    setState(() => _expenses.insert(0, e));
    await ExpenseService.addExpenseMap(e.toJson());

  }

  Future<void> _addExpenses(List<Expense> list) async {
    setState(() {
      for (final e in list.reversed) {
        _expenses.insert(0, e);
      }
    });
    await ExpenseService.addExpensesBulk(list.map((e) => e.toJson()).toList());
  }

  Future<void> _deleteExpense(int index) async {
    setState(() => _expenses.removeAt(index));
    // opcional: backend delete más adelante
  }

  Map<String, double> _sumByCategory() {
    final map = <String, double>{for (final c in _categories) c: 0.0};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  // ✅ Botón tipo "card" para dashboard 2x2
  Widget _dashboardButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final border = BorderRadius.circular(18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: border,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: border,
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            color: filled ? Colors.blueAccent.withOpacity(0.25) : Colors.white.withOpacity(0.03),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // ✅ responsive: en web grande -> 4 columnas, en normal -> 2
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 1100 ? 4 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Gastos'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _loadFromServer,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthPage()),
                (_) => false,
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ GRID 2x2 (o 4 en pantallas grandes)
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                _dashboardButton(
                  icon: Icons.add_circle_outline,
                  label: 'Añadir gasto',
                  filled: true,
                  onTap: () async {
                    final newExpenses = await Navigator.push<List<Expense>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddExpenseChoicePage(categories: _categories),
                      ),
                    );

                    if (newExpenses != null && newExpenses.isNotEmpty) {
                      await _addExpenses(newExpenses);
                      if (!mounted) return;
                      await _loadFromServer(); // para que se refresque todo consistente
                    }
                  },
                ),
                _dashboardButton(
                  icon: Icons.tune,
                  label: 'Modificar categorías',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesPage()),
                    );

                    await _loadCategoriesFromServer();

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Categorías actualizadas')),
                    );
                  },
                ),
                _dashboardButton(
                  icon: Icons.list_alt,
                  label: 'Lista de todos los gastos',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpensesListPage()),
                    );

                    if (!mounted) return;
                    await _loadFromServer();
                  },
                ),
                _dashboardButton(
                  icon: Icons.bar_chart,
                  label: 'Estadísticas',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatsPage(
                          expenses: _expenses,
                          categories: _categories,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'Total registrado: ${total.toStringAsFixed(2)} €',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            const Text(
              'Últimos gastos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _expenses.isEmpty
                      ? const Center(child: Text('Aún no hay gastos.'))
                      : ListView.separated(
                          itemCount: _expenses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _expenses[i];
                            final date =
                                '${e.date.day.toString().padLeft(2, '0')}/'
                                '${e.date.month.toString().padLeft(2, '0')}/'
                                '${e.date.year}';
                            return Dismissible(
                              key: ValueKey(
                                '${e.date.toIso8601String()}_${e.description}_${e.amount}_$i',
                              ),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Colors.red.withOpacity(0.8),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Borrar gasto'),
                                        content: const Text('¿Seguro que quieres borrar este gasto?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Borrar'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              },
                              onDismissed: (_) => _deleteExpense(i),
                              child: ListTile(
                                title: Text('${e.description} — ${e.amount.toStringAsFixed(2)} €'),
                                subtitle: Text('$date · ${e.category}${e.extra.isNotEmpty ? " · ${e.extra}" : ""}'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ver por categorías (rápido)',
        onPressed: () {
          final byCat = _sumByCategory();
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text(
                    'Gasto por categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...byCat.entries.map(
                    (e) => ListTile(
                      title: Text(e.key),
                      trailing: Text('${e.value.toStringAsFixed(2)} €'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.pie_chart),
      ),
    );
  }
}

// TODO: el resto de tus clases (AddExpensePage, StatsPage, AddExpenseChoicePage, AddExpenseAIPage, ReviewExpensesPage...)
// pueden quedarse exactamente como estaban.


class AddExpensePage extends StatefulWidget {
  final List<String> categories;
  const AddExpensePage({super.key, required this.categories});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late String _category;

@override
void initState() {
  super.initState();
  _category = widget.categories.isNotEmpty ? widget.categories.first : 'Otros';
}

  final _extraCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

    final expense = Expense(
      date: _date,
      description: _descCtrl.text.trim(),
      amount: amount,
      category: _category,
      extra: _extraCtrl.text.trim(),
    );

    Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
  final dateText =
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/'
      '${_date.year}';

  // 🔑 Asegura que la categoría actual existe
  final effectiveCategory =
      widget.categories.contains(_category) && widget.categories.isNotEmpty
          ? _category
          : (widget.categories.isNotEmpty ? widget.categories.first : null);

  return Scaffold(
    appBar: AppBar(title: const Text('Añadir gasto')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Fecha: $dateText'),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Pon una descripción'
                      : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto (€)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Pon un monto';
                final cleaned = v.replaceAll(',', '.');
                final parsed = double.tryParse(cleaned);
                if (parsed == null) return 'Monto inválido';
                if (parsed <= 0) return 'Tiene que ser > 0';
                return null;
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: effectiveCategory,
              items: widget.categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _category = v);
              },
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty)
                      ? 'Selecciona una categoría'
                      : null,
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _extraCtrl,
              decoration: const InputDecoration(
                labelText: 'Información extra (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    ),
  );
}

}

class StatsPage extends StatefulWidget {
  final List<Expense> expenses;
  final List<String> categories;

  const StatsPage({super.key, required this.expenses, required this.categories});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

// ✅ PON ESTO FUERA DE LA CLASE (arriba del archivo, antes de StatsPage)
enum StatsRange { all, last30, month }

class _StatsPageState extends State<StatsPage> {
  int? _touchedIndex;

  StatsRange _range = StatsRange.all;

  // Mes seleccionado cuando _range == month
  int? _selectedYear;
  int? _selectedMonth;

  // Colores fijos por categoría (mismo orden que widget.categories)
  final List<Color> _catColors = const [
    Color(0xFF4FC3F7), // Desayuno/Fuera
    Color(0xFF81C784), // Compra/Supermercado
    Color(0xFFFFB74D), // Alcohol/Cervezas
    Color(0xFFE57373), // Regalos
    Color(0xFFBA68C8), // Transporte
    Color(0xFFA1887F), // Ropa/Complementos
    Color(0xFF64B5F6), // Suscripciones
    Color(0xFF90A4AE), // Tabaco
  ];

  // =========================
  // 2.1 Meses disponibles (a partir de gastos)
  // =========================
  List<Map<String, int>> _availableMonths(List<Expense> expenses) {
    final set = <String>{};
    final out = <Map<String, int>>[];

    for (final e in expenses) {
      final d = e.date;
      final key = '${d.year}-${d.month}';
      if (set.add(key)) {
        out.add({'year': d.year, 'month': d.month});
      }
    }

    // ordenar desc (más reciente primero)
    out.sort((a, b) {
      final ay = a['year']!, am = a['month']!;
      final by = b['year']!, bm = b['month']!;
      if (ay != by) return by.compareTo(ay);
      return bm.compareTo(am);
    });

    return out;
  }

  // =========================
  // 2.2 Filtrar gastos según el rango seleccionado
  // =========================
  List<Expense> _applyRangeFilter(List<Expense> expenses) {
    if (_range == StatsRange.all) return expenses;

    final now = DateTime.now();

    if (_range == StatsRange.last30) {
      final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      return expenses.where((e) {
        final d = e.date;
        return d.isAfter(from) || d.isAtSameMomentAs(from);
      }).toList();
    }

    // mes concreto
    final y = _selectedYear;
    final m = _selectedMonth;
    if (y == null || m == null) return expenses;

    return expenses.where((e) => e.date.year == y && e.date.month == m).toList();
  }

  String _monthLabel(int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return '$mm/$year';
  }

  // =========================
  // UI PARTS
  // =========================
  Widget _buildChart(List<PieChartSectionData> Function() sectionsBuilder) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1.1,
          child: PieChart(
            PieChartData(
              sections: sectionsBuilder(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(List<MapEntry<String, double>> entries, double total) {
    final hasData = total > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(entries.length, (i) {
            final name = entries[i].key;
            final value = entries[i].value;
            final pct = hasData ? (value / total) : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _catColors[i % _catColors.length],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${(pct * 100).toStringAsFixed(0)}%  '),
                  Text('${value.toStringAsFixed(2)} €'),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _rangeSelector(List<Map<String, int>> months) {
    // inicializar selección de mes (si el usuario elige "Mes")
    if (months.isNotEmpty && (_selectedYear == null || _selectedMonth == null)) {
      _selectedYear = months.first['year'];
      _selectedMonth = months.first['month'];
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<StatsRange>(
              segments: const [
                ButtonSegment(value: StatsRange.all, label: Text('Todo')),
                ButtonSegment(value: StatsRange.last30, label: Text('Últimos 30 días')),
                ButtonSegment(value: StatsRange.month, label: Text('Mes')),
              ],
              selected: {_range},
              onSelectionChanged: (s) {
                setState(() {
                  _range = s.first;
                  // al cambiar a mes, asegúrate de tener uno seleccionado
                  if (_range == StatsRange.month && months.isNotEmpty) {
                    _selectedYear ??= months.first['year'];
                    _selectedMonth ??= months.first['month'];
                  }
                });
              },
            ),

            if (_range == StatsRange.month)
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: (_selectedYear != null && _selectedMonth != null)
                      ? '${_selectedYear!}-${_selectedMonth!}'
                      : null,
                  items: months.map((mm) {
                    final y = mm['year']!;
                    final m = mm['month']!;
                    return DropdownMenuItem(
                      value: '$y-$m',
                      child: Text(_monthLabel(y, m)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final parts = v.split('-');
                    setState(() {
                      _selectedYear = int.parse(parts[0]);
                      _selectedMonth = int.parse(parts[1]);
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Mes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ meses disponibles según lo que tengas en BD
    final months = _availableMonths(widget.expenses);

    // ✅ lista filtrada según selector
    final filteredExpenses = _applyRangeFilter(widget.expenses);

    // ✅ total y breakdown hechos con "filteredExpenses"
    final total = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    final byCat = <String, double>{for (final c in widget.categories) c: 0.0};
    for (final e in filteredExpenses) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }

    // Mantener el orden de widget.categories
    final entries = widget.categories.map((c) => MapEntry(c, byCat[c] ?? 0.0)).toList();

    final hasData = total > 0;

    List<PieChartSectionData> sections() {
      if (!hasData) {
        return [
          PieChartSectionData(
            value: 1,
            title: '0%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            color: Colors.black12,
          ),
        ];
      }

      return List.generate(entries.length, (i) {
        final value = entries[i].value;
        final isTouched = i == _touchedIndex;
        final radius = isTouched ? 82.0 : 70.0;

        final pct = total == 0 ? 0 : (value / total) * 100.0;

        // Si el gajo es muy pequeño, no metemos texto para que no se solape
        final showTitle = pct >= 6;

        final titleText = showTitle
            ? '${pct.toStringAsFixed(0)}%\n${value.toStringAsFixed(2)} €'
            : '';

        return PieChartSectionData(
          value: value <= 0 ? 0.0001 : value,
          color: _catColors[i % _catColors.length],
          radius: radius,
          title: titleText,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        );
      });
    }

    final chart = _buildChart(sections);
    final legend = _buildLegend(entries, total);

    // texto de rango arriba (bonito)
    String rangeText() {
      switch (_range) {
        case StatsRange.all:
          return 'Mostrando: Todo';
        case StatsRange.last30:
          return 'Mostrando: Últimos 30 días';
        case StatsRange.month:
          final y = _selectedYear;
          final m = _selectedMonth;
          if (y == null || m == null) return 'Mostrando: Mes';
          return 'Mostrando: ${_monthLabel(y, m)}';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: chart),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rangeSelector(months),
                        const SizedBox(height: 12),
                        Text(
                          rangeText(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Total registrado: ${total.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                legend,
                                const SizedBox(height: 18),
                                const Text(
                                  'Siguiente: gráfico por mes + exportar CSV + IA.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              children: [
                _rangeSelector(months),
                const SizedBox(height: 12),
                Text(
                  rangeText(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(
                  'Total registrado: ${total.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                chart,
                const SizedBox(height: 16),
                legend,
                const SizedBox(height: 18),
                const Text(
                  'Siguiente: gráfico por mes + exportar CSV + IA.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}



// CAMBIA esto cuando montes tu backend:

class ParsedExpense {
  DateTime date;
  String description;
  double amount;
  String category;
  String extra;
  double confidence;

  ParsedExpense({
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    required this.extra,
    required this.confidence,
  });

  factory ParsedExpense.fromJson(Map<String, dynamic> j) => ParsedExpense(
        date: DateTime.parse(j['date'] as String),
        description: (j['description'] as String?) ?? '',
        amount: (j['amount'] as num).toDouble(),
        category: (j['category'] as String?) ?? 'Desayuno/Fuera',
        extra: (j['extra'] as String?) ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 1) Pantalla de elección: Manual vs IA
class AddExpenseChoicePage extends StatelessWidget {
  final List<String> categories;
  const AddExpenseChoicePage({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Ponerlo manualmente'),
              onPressed: () async {
                final manual = await Navigator.push<Expense>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpensePage(categories: categories),
                  ),
                );
                if (manual != null) Navigator.pop(context, [manual]);

              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Usar IA (foto o audio)'),
              onPressed: () async {
                final created = await Navigator.push<List<Expense>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseAIPage(categories: categories),
                  ),
                );

                if (created != null && created.isNotEmpty) {
                  Navigator.pop(context, created); // 🔥 DEVUELVE TODOS
                }
              },
            ),

          ],
        ),
      ),
    );
  }
}

/// 2) Pantalla IA: subir foto o audio → parsear → revisar
class AddExpenseAIPage extends StatefulWidget {
  final List<String> categories;
  const AddExpenseAIPage({super.key, required this.categories});



  @override
  State<AddExpenseAIPage> createState() => _AddExpenseAIPageState();
}

class _AddExpenseAIPageState extends State<AddExpenseAIPage> {
  static const List<String> _defaultCategories = [
  'Desayuno/Fuera',
  'Compra/Supermercado',
  'Alcohol/Cervezas',
  'Regalos',
  'Transporte',
  'Ropa/Complementos',
  'Suscripciones',
  'Tabaco',
];

  
  bool _loading = false;
  String? _error;

  // ===== Dictado (voz -> texto) =====
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _dictatedText = '';

  // ================================
  // FOTO: enviar archivo al backend
  // ================================

  Future<List<ParsedExpense>> _sendFileToBackend({
    required String endpoint,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final req = http.MultipartRequest('POST', uri);

    // Token
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    // (Opcional) debug para ver en consola
    print("UPLOAD URL => $uri");
    print("UPLOAD HEADERS => ${req.headers}");

    // Archivo
    if (file.bytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
    } else if (file.path != null) {
      req.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else {
      throw Exception('No se pudo leer el archivo.');
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Backend error ${streamed.statusCode}: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ParsedExpense.fromJson).toList();
  }


  Future<void> _pickAndParseImage() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final file = result.files.first;

    // ✅ AQUÍ faltaba esto:
    final parsed = await _sendFileToBackend(
      endpoint: '/parse/image',
      file: file,
    );

    if (!mounted) return;

    if (parsed.isEmpty) {
      setState(() {
        _error =
            'No se detectaron gastos en la imagen. Prueba con otra foto (más nítida) o recorta la zona de importes.';
      });
      return;
    }

    final confirmed = await Navigator.push<List<Expense>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewExpensesPage(
          categories: widget.categories.isNotEmpty
              ? widget.categories
              : _defaultCategories, // esto lo arreglamos abajo
          parsed: parsed,
        ),
      ),
    );

    if (confirmed != null && mounted) {
      Navigator.pop(context, confirmed);
    }
  } catch (e) {
    if (!mounted) return;
    setState(() => _error = e.toString());
  } finally {
    if (!mounted) return;
    setState(() => _loading = false);
  }
}

  // ================================
  // AUDIO: dictado real (voz -> texto)
  // ================================
  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (e) => setState(() => _error = 'Speech error: ${e.errorMsg}'),
    );

    if (!_speechReady) {
      setState(() => _error = 'No se pudo iniciar el dictado (permiso micrófono?).');
    }
  }

  Future<void> _startDictation() async {
    setState(() {
      _error = null;
      _dictatedText = '';
      _listening = true;
    });

    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        setState(() => _listening = false);
        return;
      }
    }

    await _speech.listen(
      localeId: 'es-ES',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        setState(() {
          _dictatedText = result.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopDictation() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  // ================================
  // Enviar texto dictado al backend
  // ================================
  Future<List<ParsedExpense>> _sendTextToBackend(String text) async {
    final uri = Uri.parse('$baseUrl/parse/text');
    final token = await AuthService.getToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

final resp = await http.post(
  uri,
  headers: headers,
  body: jsonEncode({'text': text}),
);


    if (resp.statusCode != 200) {
      throw Exception('Backend error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ParsedExpense.fromJson).toList();
  }

  Future<void> _processDictation() async {
    if (_dictatedText.trim().isEmpty) {
      setState(() => _error = 'No hay texto dictado todavía.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parsed = await _sendTextToBackend(_dictatedText.trim());

      if (!mounted) return;

      final confirmed = await Navigator.push<List<Expense>>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewExpensesPage(
            categories: widget.categories,
            parsed: parsed,
          ),
        ),
      );

      if (confirmed != null && mounted) {
        Navigator.pop(context, confirmed);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================================
  // UI
  // ================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IA: Foto o Audio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],

            // FOTO (archivo)
            FilledButton.icon(
              icon: const Icon(Icons.image),
              label: const Text('Subir foto (ticket / captura)'),
              onPressed: (_loading || _listening) ? null : _pickAndParseImage,
            ),

            const SizedBox(height: 16),

            // AUDIO (dictado real)
            OutlinedButton.icon(
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? 'Parar dictado' : 'Dictar (audio)'),
              onPressed: _loading
                  ? null
                  : () => _listening ? _stopDictation() : _startDictation(),
            ),

            const SizedBox(height: 12),

            TextField(
              readOnly: true,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Texto dictado',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _dictatedText),
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Procesar dictado con IA'),
              onPressed: (_loading || _listening) ? null : _processDictation,
            ),

            const SizedBox(height: 18),
            if (_loading) const Center(child: CircularProgressIndicator()),

            const SizedBox(height: 8),
            const Text(
              'En Chrome el dictado pide permiso de micrófono. '
              'Luego el backend /parse/text debe devolver items[].',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3) Revisión: editar y confirmar lista → devuelve List<Expense>
class ReviewExpensesPage extends StatefulWidget {
  final List<String> categories;
  final List<ParsedExpense> parsed;

  const ReviewExpensesPage({
    super.key,
    required this.categories,
    required this.parsed,
  });

  @override
  State<ReviewExpensesPage> createState() => _ReviewExpensesPageState();
}

class _ReviewExpensesPageState extends State<ReviewExpensesPage> {
  late List<ParsedExpense> items;

@override
void initState() {
  super.initState();

  items = widget.parsed.map((e) => ParsedExpense(
    date: e.date,
    description: e.description,
    amount: e.amount,
    category: e.category,
    extra: e.extra,
    confidence: e.confidence,
  )).toList();
}


  void _confirm() {
    final result = items.map((p) => Expense(
      date: p.date,
      description: p.description,
      amount: p.amount,
      category: p.category,
      extra: p.extra,
    )).toList();

    Navigator.pop(context, result);
  }

@override
@override
Widget build(BuildContext context) {
  final safeCategories = widget.categories.isNotEmpty
      ? widget.categories
      : const [
          'Desayuno/Fuera',
          'Compra/Supermercado',
          'Alcohol/Cervezas',
          'Regalos',
          'Transporte',
          'Ropa/Complementos',
          'Suscripciones',
          'Tabaco',
        ];

  return Scaffold(
    appBar: AppBar(
      title: const Text('Revisar antes de guardar'),
    ),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final e = items[i];

        // ✅ texto de fecha bonito (por item)
        final dateText =
            '${e.date.day.toString().padLeft(2, '0')}/'
            '${e.date.month.toString().padLeft(2, '0')}/'
            '${e.date.year}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confianza: ${(e.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),

            // ✅ botón para ver/cambiar fecha
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: e.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => e.date = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text('Fecha: $dateText'),
            ),
            const SizedBox(height: 10),

            TextFormField(
              initialValue: e.description,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => e.description = v,
            ),
            const SizedBox(height: 10),

            TextFormField(
              initialValue: e.amount.toStringAsFixed(2),
              decoration: const InputDecoration(
                labelText: 'Monto (€)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed != null) e.amount = parsed;
              },
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: safeCategories.contains(e.category)
                  ? e.category
                  : safeCategories.first,
              items: safeCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => e.category = v ?? e.category),
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              initialValue: e.extra,
              decoration: const InputDecoration(
                labelText: 'Extra (opcional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => e.extra = v,
            ),
          ],
        );
      },
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        icon: const Icon(Icons.check),
        label: const Text('Confirmar y guardar'),
        onPressed: items.isEmpty ? null : _confirm,
      ),
    ),
  );
}
}