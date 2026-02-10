import 'package:flutter/material.dart';
import 'services/expense_service.dart';

class ExpensesListPage extends StatefulWidget {
  const ExpensesListPage({super.key});

  @override
  State<ExpensesListPage> createState() => _ExpensesListPageState();
}

class _ExpensesListPageState extends State<ExpensesListPage> {
  bool _loading = true;

  // 👇 No tipamos como Expense para no depender del modelo/archivo donde esté definido
  List<dynamic> _items = [];
  List<String> _categories = [];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await ExpenseService.fetchCategories();
      final exps = await ExpenseService.fetchExpenses();

      if (!mounted) return;
      setState(() {
        _categories = cats;
        _items = List<dynamic>.from(exps);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando gastos: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Helpers para leer campos de "expense" sin romper por nulls
  int? _getId(dynamic e) {
    try {
      final v = (e as dynamic).id;
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime _getDate(dynamic e) {
    try {
      final v = (e as dynamic).date;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _getDescription(dynamic e) {
    try {
      final v = (e as dynamic).description;
      return (v ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  double _getAmount(dynamic e) {
    try {
      final v = (e as dynamic).amount;
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _getCategory(dynamic e) {
    try {
      final v = (e as dynamic).category;
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? 'Sin categoría' : s;
    } catch (_) {
      return 'Sin categoría';
    }
  }

  String _getExtra(dynamic e) {
    try {
      final v = (e as dynamic).extra;
      return (v ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Map<String, List<dynamic>> _groupByCategory() {
    final Map<String, List<dynamic>> grouped = {};

    for (final e in _items) {
      if (e == null) continue;
      final c = _getCategory(e);
      grouped.putIfAbsent(c, () => []).add(e);
    }

    // ordenar por fecha desc dentro de cada categoría
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => _getDate(b).compareTo(_getDate(a)));
    }

    return grouped;
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
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
    );

    if (ok != true) return;

    try {
      await ExpenseService.deleteExpense(id);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto borrado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error borrando: $e')),
      );
    }
  }

  Future<void> _editExpense(dynamic e) async {
    final id = _getId(e);
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: este gasto no tiene id')),
      );
      return;
    }

    final descCtrl = TextEditingController(text: _getDescription(e));
    final amountCtrl = TextEditingController(text: _getAmount(e).toString());
    final extraCtrl = TextEditingController(text: _getExtra(e));

    DateTime date = _getDate(e);
    String category = _getCategory(e);

    if (_categories.isNotEmpty && !_categories.contains(category)) {
      category = _categories.first;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar gasto'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setLocal(() => date = DateTime(picked.year, picked.month, picked.day));
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Fecha: ${_fmtDate(date)}'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto (€)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _categories.isNotEmpty
                      ? (_categories.contains(category) ? category : _categories.first)
                      : category,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v ?? category),
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: extraCtrl,
                  decoration: const InputDecoration(labelText: 'Info extra'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final cleaned = amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(cleaned);
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto inválido')),
      );
      return;
    }

    try {
      await ExpenseService.updateExpense(
        id,
        date: date,
        description: descCtrl.text.trim(),
        amount: amount,
        category: category,
        extra: extraCtrl.text.trim(),
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto actualizado')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory();
    final allCats = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de todos los gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : allCats.isEmpty
              ? const Center(child: Text('No hay gastos aún'))
              : ListView.builder(
                  itemCount: allCats.length,
                  itemBuilder: (_, i) {
                    final cat = allCats[i];
                    final list = grouped[cat] ?? [];

                    final total = list.fold<double>(0, (sum, x) => sum + _getAmount(x));

                    return ExpansionTile(
                      title: Text(cat),
                      subtitle: Text(
                        'Total: ${total.toStringAsFixed(2)} €  ·  ${list.length} gastos',
                      ),
                      children: list.map((e) {
                        final title = _getDescription(e);
                        final amount = _getAmount(e);
                        final date = _fmtDate(_getDate(e));
                        final id = _getId(e);

                        return ListTile(
                          title: Text(title),
                          subtitle: Text(date),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${amount.toStringAsFixed(2)} €'),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Editar',
                                onPressed: () => _editExpense(e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Borrar',
                                onPressed: id == null ? null : () => _confirmDelete(id),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }
}
