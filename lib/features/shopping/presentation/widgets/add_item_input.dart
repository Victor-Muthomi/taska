import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddItemInput extends StatefulWidget {
  const AddItemInput({
    super.key,
    required this.onAdd,
    required this.categoryOptions,
    this.currencySymbol = '\$',
    this.enabled = true,
  });

  final Future<void> Function(
    String name,
    String category,
    int quantity,
    double? pricePerItem,
  ) onAdd;
  final List<String> categoryOptions;
  final String currencySymbol;
  final bool enabled;

  @override
  State<AddItemInput> createState() => _AddItemInputState();
}

class _AddItemInputState extends State<AddItemInput> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{'General', ...widget.categoryOptions}
      ..removeWhere((value) => value.trim().isEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add item details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture name, quantity, and price per item in one step.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: widget.enabled && !_isSubmitting,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Item',
                hintText: 'Milk, eggs, coffee...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    enabled: widget.enabled && !_isSubmitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    enabled: widget.enabled && !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Price / item',
                      hintText: '0.00',
                      prefixText: widget.currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                PopupMenuButton<String>(
                  enabled: widget.enabled && !_isSubmitting,
                  initialValue: _selectedCategory,
                  tooltip: 'Category',
                  onSelected: (value) {
                    setState(() => _selectedCategory = value);
                  },
                  itemBuilder: (context) {
                    return categories
                        .map(
                          (category) => PopupMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList();
                  },
                  child: InputChip(
                    label: Text(_selectedCategory),
                    avatar: const Icon(Icons.category_outlined, size: 18),
                    onPressed: null,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: widget.enabled && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Prices use ${widget.currencySymbol.trim()} as selected in Settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) {
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final parsedPrice = double.tryParse(_priceController.text.trim());
    final pricePerItem =
        (parsedPrice != null && parsedPrice >= 0) ? parsedPrice : null;

    setState(() => _isSubmitting = true);
    try {
      await widget.onAdd(
        name,
        _selectedCategory,
        quantity < 1 ? 1 : quantity,
        pricePerItem,
      );
      _nameController.clear();
      _quantityController.text = '1';
      _priceController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
