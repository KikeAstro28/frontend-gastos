import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'services/expense_service.dart';


class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _loading = true;
  List<String> _cats = [];

  // mismas default que en backend (para bloquear borrado)
  final Set<String> _defaultLower = {
    'desayuno/fuera',
    'compra/supermercado',
    'alcohol/cervezas',
    'regalos',
    'transporte',
    'ropa/complementos',
    'suscripciones',
    'tabaco',
  };

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await ExpenseService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _cats = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando categorías: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _add() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ej: Gym, Gasolina, Salud...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    try {
      await ExpenseService.addCategory(trimmed);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría añadida')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error añadiendo: $e')),
      );
    }
  }

  Future<void> _hide(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar categoría'),
        content: Text('¿Seguro que quieres borrar "$name"?'),
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
      await ExpenseService.hideCategory(name);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría borrada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error borrando: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Añadir',
            onPressed: _add,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _cats.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = _cats[i];
                final isDefault = _defaultLower.contains(c.toLowerCase());

                return ListTile(
                  title: Text(c),
                 trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Ocultar',
                    onPressed: () => _hide(c),
),

                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }
}
