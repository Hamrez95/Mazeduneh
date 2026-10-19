import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'formatters.dart';

/// Search and pagination controls that remain available when a data list is
/// rendered as cards instead of a wide table.
class AdminMobileListControls extends StatefulWidget {
  const AdminMobileListControls({
    super.key,
    required this.totalItems,
    required this.page,
    required this.pageSize,
    required this.searchText,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int totalItems;
  final int page;
  final int pageSize;
  final String searchText;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  State<AdminMobileListControls> createState() =>
      _AdminMobileListControlsState();
}

class _AdminMobileListControlsState extends State<AdminMobileListControls> {
  late final TextEditingController _search = TextEditingController(
    text: widget.searchText,
  );

  @override
  void didUpdateWidget(covariant AdminMobileListControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchText != widget.searchText &&
        _search.text != widget.searchText) {
      _search.value = TextEditingValue(
        text: widget.searchText,
        selection: TextSelection.collapsed(offset: widget.searchText.length),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = math.max(
      1,
      (widget.totalItems + widget.pageSize - 1) ~/ widget.pageSize,
    );
    final page = widget.page.clamp(0, pageCount - 1);
    final start = widget.totalItems == 0 ? 0 : page * widget.pageSize + 1;
    final end = math.min(widget.totalItems, (page + 1) * widget.pageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: widget.onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: widget.searchHint,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'پاک‌کردن جست‌وجو',
                    onPressed: () {
                      _search.clear();
                      widget.onSearchChanged('');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              widget.totalItems == 0
                  ? '۰ مورد'
                  : 'نمایش ${formatPersianInteger(start)} تا ${formatPersianInteger(end)} از ${formatPersianInteger(widget.totalItems)} مورد',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                const Text('در هر صفحه', style: TextStyle(fontSize: 11)),
                SizedBox(
                  width: 76,
                  child: DropdownButtonFormField<int>(
                    initialValue: widget.pageSize,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                    ),
                    items: [5, 10, 25]
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text(formatPersianInteger(size)),
                          ),
                        )
                        .toList(),
                    onChanged: (size) {
                      if (size != null) widget.onPageSizeChanged(size);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'صفحهٔ قبل',
                  visualDensity: VisualDensity.compact,
                  onPressed: page == 0
                      ? null
                      : () => widget.onPageChanged(page - 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Text(
                  '${formatPersianInteger(page + 1)} / ${formatPersianInteger(pageCount)}',
                  semanticsLabel: 'صفحه ${page + 1} از $pageCount',
                  style: const TextStyle(fontSize: 11),
                ),
                IconButton(
                  tooltip: 'صفحهٔ بعد',
                  visualDensity: VisualDensity.compact,
                  onPressed: page >= pageCount - 1
                      ? null
                      : () => widget.onPageChanged(page + 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
