import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'formatters.dart';

class AdminColumn<T> {
  const AdminColumn(
    this.label,
    this.cell, {
    this.compare,
    this.numeric = false,
  });
  final String label;
  final Widget Function(T) cell;
  final Comparator<T>? compare;
  final bool numeric;
}

/// A live record table: local search, sorting and pagination share one visual
/// contract across the catalog, orders and access-management screens.
class AdminRecordTable<T> extends StatefulWidget {
  const AdminRecordTable({
    super.key,
    required this.records,
    required this.columns,
    this.searchText,
    this.searchHint = 'جست‌وجو…',
    this.actions = const [],
    this.onOpen,
    this.isSelected,
    this.onSelectionChanged,
  });
  final List<T> records;
  final List<AdminColumn<T>> columns;
  final String Function(T)? searchText;
  final String searchHint;
  final List<Widget> actions;
  final ValueChanged<T>? onOpen;
  final bool Function(T)? isSelected;
  final void Function(T, bool)? onSelectionChanged;
  @override
  State<AdminRecordTable<T>> createState() => _AdminRecordTableState<T>();
}

class _AdminRecordTableState<T> extends State<AdminRecordTable<T>> {
  final search = TextEditingController();
  int page = 0, pageSize = 10;
  int? sortColumn;
  bool ascending = true;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeNumberDigits(search.text.trim().toLowerCase());
    final rows = widget.records
        .where(
          (item) =>
              query.isEmpty ||
              widget.searchText == null ||
              normalizeNumberDigits(
                widget.searchText!(item).toLowerCase(),
              ).contains(query),
        )
        .toList();
    if (sortColumn != null && widget.columns[sortColumn!].compare != null) {
      rows.sort(
        (a, b) =>
            widget.columns[sortColumn!].compare!(a, b) * (ascending ? 1 : -1),
      );
    }
    final lastPage = rows.isEmpty ? 0 : (rows.length - 1) ~/ pageSize;
    final current = page.clamp(0, lastPage);
    final from = current * pageSize;
    final shown = rows.skip(from).take(pageSize).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('نمایش'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 104,
                      child: DropdownButtonFormField<int>(
                        initialValue: pageSize,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        items: [10, 25, 50]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(formatPersianInteger(n)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          pageSize = value ?? 10;
                          page = 0;
                        }),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.searchText != null)
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width < 600
                            ? 210
                            : 260,
                        child: TextField(
                          controller: search,
                          onChanged: (_) => setState(() => page = 0),
                          decoration: InputDecoration(
                            hintText: widget.searchHint,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ...widget.actions,
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('رکوردی با این جست‌وجو پیدا نشد.'),
            )
          else
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: DataTable(
                    sortColumnIndex: sortColumn,
                    sortAscending: ascending,
                    showCheckboxColumn: widget.onSelectionChanged != null,
                    columns: [
                      for (var i = 0; i < widget.columns.length; i++)
                        DataColumn(
                          label: Text(widget.columns[i].label),
                          numeric: widget.columns[i].numeric,
                          onSort: widget.columns[i].compare == null
                              ? null
                              : (column, order) => setState(() {
                                  sortColumn = column;
                                  ascending = order;
                                  page = 0;
                                }),
                        ),
                    ],
                    rows: [
                      for (final item in shown)
                        DataRow(
                          selected: widget.isSelected?.call(item) ?? false,
                          color: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.hovered)
                                ? AdminColors.surfaceRaised
                                : null,
                          ),
                          onSelectChanged: widget.onSelectionChanged != null
                              ? (value) => widget.onSelectionChanged!(
                                  item,
                                  value ?? false,
                                )
                              : widget.onOpen == null
                              ? null
                              : (_) => widget.onOpen!(item),
                          cells: [
                            for (final column in widget.columns)
                              DataCell(
                                column.cell(item),
                                onTap: widget.onOpen == null
                                    ? null
                                    : () => widget.onOpen!(item),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'نمایش ${formatPersianInteger(rows.isEmpty ? 0 : from + 1)} تا ${formatPersianInteger(from + shown.length)} از ${formatPersianInteger(rows.length)} مورد',
                  style: const TextStyle(
                    color: AdminColors.subtle,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'صفحهٔ اول',
                      onPressed: current == 0
                          ? null
                          : () => setState(() => page = 0),
                      icon: const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'صفحهٔ قبل',
                      onPressed: current == 0
                          ? null
                          : () => setState(() => page = current - 1),
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AdminColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        formatPersianInteger(current + 1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      tooltip: 'صفحهٔ بعد',
                      onPressed: current == lastPage
                          ? null
                          : () => setState(() => page = current + 1),
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: 'صفحهٔ آخر',
                      onPressed: current == lastPage
                          ? null
                          : () => setState(() => page = lastPage),
                      icon: const Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge(
    this.label, {
    super.key,
    this.color = AdminColors.primaryLight,
    this.background = AdminColors.primarySoft,
  });
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
    ),
  );
}

class AdminIdentityCell extends StatelessWidget {
  const AdminIdentityCell({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Row(
      children: [
        leading ??
            CircleAvatar(
              radius: 17,
              backgroundColor: AdminColors.primarySoft,
              foregroundColor: AdminColors.primaryLight,
              child: Text(title.isEmpty ? '؟' : title.substring(0, 1)),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AdminColors.heading,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.subtle,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
