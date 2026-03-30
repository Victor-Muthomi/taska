import 'package:flutter/material.dart';

class AddItemInput extends StatefulWidget {
  const AddItemInput({
    super.key,
    required this.onAdd,
    required this.categoryOptions,
    this.enabled = true,
  });

  final Future<void> Function(String name, String category) onAdd;
  final List<String> categoryOptions;
  final bool enabled;

  @override
  State<AddItemInput> createState() => _AddItemInputState();
}

class _AddItemInputState extends State<AddItemInput> {
  final TextEditingController _controller = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
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
              'Quick add',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Type an item and press add. Category defaults to General.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: widget.enabled && !_isSubmitting,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Item',
                      hintText: 'Milk, eggs, coffee...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 12),
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
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: widget.enabled && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onAdd(name, _selectedCategory);
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}