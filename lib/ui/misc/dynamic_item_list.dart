import 'package:flutter/material.dart';

class DynamicItemList extends StatefulWidget {
  final Widget Function(int index, String enteredString, [void Function()? removeItem]) itemBuilder;
  final void Function(List<String> items)? onSubmitted;

  const DynamicItemList({super.key, required this.itemBuilder, this.onSubmitted});

  @override
  State<DynamicItemList> createState() => _DynamicItemListState();
}

class _DynamicItemListState extends State<DynamicItemList> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _items = [];

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(text);
      _controller.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Enter Name', border: OutlineInputBorder()),
                onSubmitted: (_) => _addItem(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addItem, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 12),

        _items.isEmpty
            ? const Text('No items added yet')
            : Column(
                children: List.generate(_items.length, (index) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.itemBuilder(index, _items[index], () => _removeItem(index)),
                      IconButton(onPressed: () => _removeItem(index), icon: const Icon(Icons.delete)),
                    ],
                  );
                }),
              ),

        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            children: [
              if (_items.isNotEmpty) const SizedBox(height: 16),
              if (_items.isNotEmpty) ElevatedButton(onPressed: () => widget.onSubmitted?.call(_items), child: const Text('Submit')),
            ],
          ),
        ),
      ],
    );
  }
}
