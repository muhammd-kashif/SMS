import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';
import 'export_service.dart';
import 'state.dart';
import 'theme.dart';

class GridColumn {
  const GridColumn({
    required this.key,
    required this.label,
    this.width,
    this.numeric = false,
    this.cell,
    this.align,
  });

  final String key;
  final String label;
  final double? width;
  final bool numeric;
  final Widget Function(dynamic value, Map<String, dynamic> row)? cell;
  final TextAlign? align;

  TextAlign get textAlign => align ?? (numeric ? TextAlign.end : TextAlign.start);
}

/// React-style data grid: complete data, sorting, per-column filters, search,
/// pagination, column picker, row selection and PDF / Excel / CSV / print export.
///
/// Pass an empty `columns` list to derive every field the API returned, or a
/// curated `columns` + `cells` pair to hand-pick the columns and decorate them.
class RemoteTable extends StatefulWidget {
  const RemoteTable({
    required this.title,
    required this.subtitle,
    required this.load,
    this.columns = const [],
    this.keys,
    this.cells,
    this.textCells,
    this.breadcrumb,
    this.actions = const [],
    this.rowTap,
    this.rowActions,
    this.exportName,
    this.exportMeta = const [],
    this.initialSort,
    this.pageSize = 25,
    this.compact = false,
    this.emptyTitle,
    this.emptyMessage,
    this.showSelection = true,
    this.familyLoader,
    super.key,
  });

  final String title;
  final String subtitle;
  final Future<List<Map<String, dynamic>>> Function() load;
  final List<String> columns;
  final List<String>? keys;
  final List<Widget> Function(Map<String, dynamic> row)? cells;
  final List<String> Function(Map<String, dynamic> row)? textCells;
  final List<String>? breadcrumb;
  final List<Widget> actions;
  final void Function(Map<String, dynamic> row)? rowTap;
  final Widget Function(Map<String, dynamic> row)? rowActions;
  final String? exportName;
  final List<(String, String)> exportMeta;
  final String? initialSort;
  final int pageSize;
  final bool compact;
  final String? emptyTitle;
  final String? emptyMessage;
  final bool showSelection;
  final Future<List<Map<String, dynamic>>> Function()? familyLoader;

  @override
  State<RemoteTable> createState() => _RemoteTableState();
}

class _RemoteTableState extends State<RemoteTable> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  late String? _sortKey = widget.initialSort;
  bool _ascending = true;
  String? _pendingSort;
  final Map<String, Set<String>> _filters = {};
  final Set<String> _hidden = {};
  final Set<String> _selected = {};
  late int _perPage = widget.pageSize;
  int _page = 0;
  bool _busy = false;

  final ScrollController _headScroll = ScrollController();
  final ScrollController _bodyScroll = ScrollController();
  bool _locking = false;

  static const _firstKeys = <String>['id', 'name', 'student_code', 'employee_code', 'roll_number', 'code', 'email', 'phone', 'status'];

  bool get _curated => widget.columns.isNotEmpty && widget.cells != null;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
    _headScroll.addListener(_syncHead);
    _bodyScroll.addListener(_syncBody);
  }

  @override
  void dispose() {
    _headScroll.removeListener(_syncHead);
    _bodyScroll.removeListener(_syncBody);
    _headScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  void _syncHead() {
    if (_locking) return;
    _locking = true;
    if (_bodyScroll.hasClients && (_bodyScroll.offset - _headScroll.offset).abs() > 0.5) {
      _bodyScroll.jumpTo(_headScroll.offset.clamp(0.0, math.max(0.0, _bodyScroll.position.maxScrollExtent)));
    }
    _locking = false;
  }

  void _syncBody() {
    if (_locking) return;
    _locking = true;
    if (_headScroll.hasClients && (_headScroll.offset - _bodyScroll.offset).abs() > 0.5) {
      _headScroll.jumpTo(_bodyScroll.offset.clamp(0.0, math.max(0.0, _headScroll.position.maxScrollExtent)));
    }
    _locking = false;
  }

  void reload() {
    setState(() {
      _selected.clear();
      _page = 0;
      _future = widget.load();
    });
  }

  // -- data pipeline ---------------------------------------------------------

  List<Map<String, dynamic>> _search(List<Map<String, dynamic>> rows, List<GridColumn> columns) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return rows;
    return rows.where((row) {
      for (final column in columns) {
        if (readValue(row, column.key).toLowerCase().contains(needle)) return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    if (_filters.isEmpty) return rows;
    return rows.where((row) {
      for (final entry in _filters.entries) {
        if (entry.value.isEmpty) continue;
        if (!entry.value.contains(readValue(row, entry.key))) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> rows, List<GridColumn> columns) {
    final key = _sortKey;
    if (key == null) return rows;
    final column = columns.where((item) => item.key == key).firstOrNull;
    final numeric = column?.numeric ?? false;
    final copy = [...rows]
      ..sort((a, b) {
        final left = readValue(a, key);
        final right = readValue(b, key);
        final result = numeric ? _compareNumbers(left, right) : left.toLowerCase().compareTo(right.toLowerCase());
        return _ascending ? result : -result;
      });
    return copy;
  }

  int _compareNumbers(String left, String right) {
    final a = num.tryParse(left.replaceAll(',', ''));
    final b = num.tryParse(right.replaceAll(',', ''));
    if (a == null && b == null) return left.compareTo(right);
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  // -- columns ---------------------------------------------------------------

  List<GridColumn> _columnsFor(List<Map<String, dynamic>> rows) {
    if (_curated) {
      final keys = widget.keys;
      return [
        for (var i = 0; i < widget.columns.length; i++)
          GridColumn(
            key: keys != null && i < keys.length ? keys[i] : _guessKey(widget.columns[i]),
            label: widget.columns[i],
            numeric: _columnIsNumeric(rows, keys != null && i < keys.length ? keys[i] : _guessKey(widget.columns[i])),
          ),
      ];
    }
    return deriveColumns(rows);
  }

  List<GridColumn> _visible(List<GridColumn> columns) => [for (final column in columns) if (!_hidden.contains(column.key)) column];

  static bool _columnIsNumeric(List<Map<String, dynamic>> rows, String key) {
    var seen = 0;
    var numeric = 0;
    for (final row in rows) {
      final value = readValue(row, key);
      if (value.trim().isEmpty) continue;
      seen++;
      if (num.tryParse(value.replaceAll(',', '')) != null) numeric++;
    }
    return seen > 0 && numeric == seen;
  }

  /// Flattens every response map so no field returned by the API is hidden.
  static List<GridColumn> deriveColumns(List<Map<String, dynamic>> rows) {
    final keys = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      _walk(row, '', seen, keys);
    }
    final index = <String, int>{for (var i = 0; i < keys.length; i++) keys[i]: i};
    final ordered = [...keys]..sort((a, b) {
        final rankA = _rank(a, index[a] ?? 0);
        final rankB = _rank(b, index[b] ?? 0);
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.compareTo(b);
      });
    return [
      for (final key in ordered)
        GridColumn(key: key, label: humanKey(key), width: _widthFor(key, rows), numeric: _columnIsNumeric(rows, key)),
    ];
  }

  static int _rank(String key, int index) {
    final base = _firstKeys.indexOf(key.split('.').first);
    if (base >= 0) return base;
    if (key.contains('.')) return 900 + index;
    return 40 + index;
  }

  static double _widthFor(String key, List<Map<String, dynamic>> rows) {
    var longest = humanKey(key).length;
    var counted = 0;
    for (final row in rows) {
      final value = readValue(row, key);
      if (value.length > longest) longest = value.length;
      counted++;
      if (counted >= 25 || longest > 34) break;
    }
    if (longest <= 10) return 112;
    if (longest <= 18) return 152;
    if (longest <= 30) return 205;
    return 260;
  }

  static void _walk(dynamic value, String prefix, Set<String> seen, List<String> keys) {
    if (value is! Map) return;
    for (final entry in value.entries) {
      final name = entry.key.toString();
      if (name.startsWith('_')) continue;
      final path = prefix.isEmpty ? name : '$prefix.$name';
      final child = entry.value;
      if (child is Map && child.isNotEmpty) {
        _walk(child, path, seen, keys);
      } else if (seen.add(path)) {
        keys.add(path);
      }
    }
  }

  static String _guessKey(String label) => label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  // -- exports ---------------------------------------------------------------

  ExportBundle _bundle(List<Map<String, dynamic>> rows, List<GridColumn> columns) {
    final model = AppScope.of(context);
    final headers = <String>[];
    final body = <List<String>>[];

    if (_curated) {
      headers.addAll(widget.columns);
      final text = widget.textCells;
      for (final row in rows) {
        if (text != null) {
          final values = text(row);
          body.add([for (var i = 0; i < headers.length; i++) i < values.length ? values[i] : '']);
        } else {
          body.add([for (final column in columns) readValue(row, column.key)]);
        }
      }
    } else {
      headers.addAll([for (final column in columns) column.label]);
      for (final row in rows) {
        body.add([for (final column in columns) readValue(row, column.key)]);
      }
    }

    return ExportBundle(
      title: widget.exportName ?? widget.title,
      subtitle: widget.subtitle,
      headers: headers,
      rows: body,
      sheetName: widget.title,
      meta: [
        ('Generated by', model.displayName.isEmpty ? model.role : '${model.displayName} · ${model.role}'),
        ('Search', _query.trim().isEmpty ? 'all records' : _query.trim()),
        ('Active filters', _filters.isEmpty ? 'none' : '${_filters.length} column filter(s)'),
        ('Records in file', '${rows.length}'),
        ...widget.exportMeta,
      ],
    );
  }

  Future<void> _runExport(ExportFormat format, List<Map<String, dynamic>> rows, List<GridColumn> columns) async {
    setState(() => _busy = true);
    try {
      final outcome = await runExport(_bundle(rows, columns), format);
      if (!mounted) return;
      dashToast(context, outcome.message);
    } catch (error) {
      if (!mounted) return;
      dashToast(context, 'Export failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -- interactions ----------------------------------------------------------

  void _toggleSort(GridColumn column) {
    setState(() {
      if (_sortKey == column.key) {
        _ascending = !_ascending;
      } else {
        _sortKey = column.key;
        _ascending = true;
      }
      _pendingSort = column.key;
      _page = 0;
    });
    final token = column.key;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _pendingSort == token) setState(() => _pendingSort = null);
    });
  }

  Future<void> _openFilter(GridColumn column, List<Map<String, dynamic>> all) async {
    final values = <String>{};
    for (final row in all) {
      final value = readValue(row, column.key);
      if (value.trim().isNotEmpty) values.add(value);
      if (values.length > 400) break;
    }
    final sorted = [...values]..sort();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _FilterDialog(title: 'Filter · ${column.label}', values: sorted, selected: {...?_filters[column.key]}),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.isEmpty) {
        _filters.remove(column.key);
      } else {
        _filters[column.key] = result;
      }
      _page = 0;
    });
  }

  Future<void> _openColumns(List<GridColumn> columns) async {
    final hidden = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _ColumnsDialog(columns: columns, hidden: {..._hidden}),
    );
    if (!mounted || hidden == null) return;
    setState(() {
      _hidden
        ..clear()
        ..addAll(hidden);
      if (columns.every((column) => hidden.contains(column.key))) _hidden.clear();
    });
  }

  // -- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact || MediaQuery.sizeOf(context).width < 720;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DashSkeleton(height: 26, width: 220, radius: 8),
                const SizedBox(height: 12),
                const DashSkeleton(height: 13, width: 320),
                const SizedBox(height: 20),
                Panel(padding: const EdgeInsets.symmetric(vertical: 6), child: const TableSkeleton(rows: 8, columns: 6)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(title: widget.title, subtitle: widget.subtitle, breadcrumb: widget.breadcrumb),
                Panel(child: ErrorState(message: snapshot.error.toString(), onRetry: reload)),
              ],
            ),
          );
        }

        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final columns = _visible(_columnsFor(all));
        final filtered = _sorted(_applyFilters(_search(all, columns)), columns);

        final pageCount = math.max(1, (filtered.length / _perPage).ceil());
        final safePage = _page.clamp(0, pageCount - 1);
        final start = safePage * _perPage;
        final pageRows = filtered.length <= start ? const <Map<String, dynamic>>[] : filtered.sublist(start, math.min(start + _perPage, filtered.length));

        return Padding(
          padding: pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                breadcrumb: widget.breadcrumb,
                actions: [
                  ...widget.actions,
                  DashIconButton(icon: Icons.refresh_rounded, tooltip: 'Reload data', onPressed: _busy ? null : reload),
                  if (_busy)
                    const DashButton(label: 'Working…', loading: true)
                  else
                    DashMenu(
                      label: compact ? null : 'Export',
                      icon: Icons.download_rounded,
                      variant: DashVariant.primary,
                      onPressed: () {},
                      items: [
                        for (final format in ExportFormat.values)
                          DashMenuItem(
                            label: format.label,
                            icon: format.icon,
                            tone: format.tone,
                            onSelected: () => _runExport(format, filtered, columns),
                          ),
                      ],
                    ),
                ],
              ),
              Expanded(
                child: Panel(
                  padding: EdgeInsets.zero,
                  fill: true,
                  footer: _footer(filtered.length, all.length, safePage, pageCount, start),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(all, columns, filtered),
                      if (_selected.isNotEmpty) _selectionBar(columns),
                      Expanded(child: _grid(columns, pageRows, filtered)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolbar(List<Map<String, dynamic>> all, List<GridColumn> columns, List<Map<String, dynamic>> filtered) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final search = TextField(
      onChanged: (value) => setState(() {
        _query = value;
        _page = 0;
      }),
      style: const TextStyle(fontSize: 13),
      decoration: Dash.input(
        hint: 'Search ${widget.title.toLowerCase()}…',
        prefix: const Icon(Icons.search_rounded),
        suffix: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  _query = '';
                  _page = 0;
                }),
                icon: const Icon(Icons.close_rounded, size: 16),
              ),
      ),
    );

    final controls = <Widget>[
      if (narrow) Expanded(child: search) else SizedBox(width: 280, child: search),
      const SizedBox(width: 10),
      if (_filters.isNotEmpty) ...[
        DashButton(
          label: 'Clear filters',
          icon: Icons.filter_alt_off_rounded,
          variant: DashVariant.secondary,
          size: DashSize.sm,
          onPressed: () => setState(() {
            _filters.clear();
            _page = 0;
          }),
        ),
        const SizedBox(width: 8),
      ],
      DashButton(
        label: narrow ? null : 'Columns ${columns.length}',
        icon: Icons.view_column_rounded,
        variant: DashVariant.secondary,
        size: DashSize.sm,
        onPressed: () => _openColumns(_columnsFor(all)),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Dash.border)), borderRadius: BorderRadius.vertical(top: Radius.circular(Dash.radius))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: controls),
          if (_filters.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in _filters.entries)
                  _FilterChip(
                    label: humanKey(entry.key),
                    count: entry.value.length,
                    onRemove: () => setState(() {
                      _filters.remove(entry.key);
                      _page = 0;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${filtered.length} of ${all.length} record${all.length == 1 ? '' : 's'} · ${columns.length} column${columns.length == 1 ? '' : 's'}',
            style: TextStyle(color: Dash.faint, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar(List<GridColumn> columns) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      color: Dash.brandSoft,
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Dash.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selected.length} row${_selected.length == 1 ? '' : 's'} selected',
              style: TextStyle(color: Dash.brand, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          DashButton(label: 'Clear', variant: DashVariant.ghost, size: DashSize.sm, icon: Icons.close_rounded, onPressed: () => setState(_selected.clear)),
          const SizedBox(width: 6),
          DashMenu(
            label: 'Export selected',
            icon: Icons.download_rounded,
            variant: DashVariant.primary,
            size: DashSize.sm,
            onPressed: () {},
            items: [
              for (final format in ExportFormat.values)
                DashMenuItem(
                  label: format.label,
                  icon: format.icon,
                  tone: format.tone,
                  onSelected: () {
                    final picked = _selectedRows;
                    if (picked.isEmpty) {
                      dashToast(context, 'Select at least one row first.');
                      return;
                    }
                    _runExport(format, picked, columns);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _selectedRows = const [];

  Widget _grid(List<GridColumn> columns, List<Map<String, dynamic>> pageRows, List<Map<String, dynamic>> filtered) {
    if (pageRows.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          title: widget.emptyTitle ?? 'No records found',
          message: widget.emptyMessage ?? (_query.isEmpty && _filters.isEmpty ? 'The college API returned an empty list.' : 'No row matches the current search and filters.'),
          icon: Icons.table_rows_rounded,
          action: (_query.isEmpty && _filters.isEmpty)
              ? null
              : DashButton(
                  label: 'Reset search & filters',
                  icon: Icons.restart_alt_rounded,
                  variant: DashVariant.secondary,
                  size: DashSize.sm,
                  onPressed: () => setState(() {
                    _query = '';
                    _filters.clear();
                    _page = 0;
                  }),
                ),
        ),
      );
    }

    _selectedRows = filtered.where((row) => _selected.contains(_rowKey(row))).toList();

    final widths = <double>[if (widget.showSelection) 46, for (final column in columns) column.width ?? 170];
    final total = widths.fold<double>(0, (sum, value) => sum + value);
    final viewport = MediaQuery.sizeOf(context).width;
    final width = total < viewport ? viewport : total;

    final header = _headerRow(columns, widths, filtered);
    final body = ListView.builder(
      controller: _bodyScroll,
      padding: EdgeInsets.zero,
      itemCount: pageRows.length,
      itemExtent: 46,
      itemBuilder: (context, index) {
        final row = pageRows[index];
        final key = _rowKey(row);
        return _GridRow(
          key: ValueKey('$key-$index'),
          striped: index.isOdd,
          selected: _selected.contains(key),
          onSelect: widget.showSelection
              ? () => setState(() {
                    if (!_selected.add(key)) _selected.remove(key);
                  })
              : null,
          onTap: widget.rowTap == null ? null : () => widget.rowTap!(row),
          leading: widget.showSelection
              ? SizedBox(
                  width: 46,
                  child: Center(
                    child: Checkbox(
                      value: _selected.contains(key),
                      onChanged: (_) => setState(() {
                        if (!_selected.add(key)) _selected.remove(key);
                      }),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      side: BorderSide(color: Dash.border, width: 1.4),
                    ),
                  ),
                )
              : null,
          trailing: widget.rowActions?.call(row),
          children: [
            for (var i = 0; i < columns.length; i++)
              SizedBox(width: widths[(widget.showSelection ? 1 : 0) + i], child: _cell(columns[i], row)),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(color: Dash.soft, border: Border(bottom: BorderSide(color: Dash.border))),
          child: SingleChildScrollView(
            controller: _headScroll,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(width: width, child: header),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(width: width, child: body),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(List<GridColumn> columns, List<double> widths, List<Map<String, dynamic>> filtered) {
    return Row(
      children: [
        if (widget.showSelection)
          SizedBox(
            width: widths.first,
            child: Center(
              child: Checkbox(
                value: _allSelected(filtered),
                onChanged: (_) => setState(() {
                  if (_allSelected(filtered)) {
                    _selected.clear();
                  } else {
                    _selected.addAll(filtered.map(_rowKey));
                  }
                }),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: BorderSide(color: Dash.border, width: 1.4),
              ),
            ),
          ),
        for (var i = 0; i < columns.length; i++)
          SizedBox(
            width: widths[(widget.showSelection ? 1 : 0) + i],
            child: _HeaderCell(
              column: columns[i],
              active: _sortKey == columns[i].key,
              ascending: _ascending,
              loading: _pendingSort == columns[i].key,
              filtered: _filters[columns[i].key]?.length ?? 0,
              onSort: () => _toggleSort(columns[i]),
              onFilter: () => _openFilter(columns[i], filtered),
            ),
          ),
        if (widget.rowActions != null) const SizedBox(width: 100),
      ],
    );
  }

  Widget _cell(GridColumn column, Map<String, dynamic> row) {
    if (_curated) {
      final widgets = widget.cells!(row);
      final index = _curatedIndexOf(column);
      final child = index >= 0 && index < widgets.length ? widgets[index] : const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child));
    }
    final text = readValue(row, column.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text.isEmpty ? '—' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text.isEmpty ? Dash.faint : Dash.ink, fontSize: 12.8, fontWeight: FontWeight.w500)),
      ),
    );
  }

  int _curatedIndexOf(GridColumn column) {
    final keys = widget.keys;
    for (var i = 0; i < widget.columns.length; i++) {
      final key = keys != null && i < keys.length ? keys[i] : _guessKey(widget.columns[i]);
      if (key == column.key && widget.columns[i] == column.label) return i;
    }
    return -1;
  }

  Widget _footer(int filteredCount, int totalCount, int page, int pageCount, int start) {
    final end = math.min(start + _perPage, filteredCount);
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final summary = Text(
      start >= filteredCount
          ? 'No rows on this page · $filteredCount filtered of $totalCount'
          : 'Showing ${start + 1}–$end of $filteredCount filtered row${filteredCount == 1 ? '' : 's'} · $totalCount total',
      style: TextStyle(color: Dash.muted, fontSize: 12, fontWeight: FontWeight.w600),
    );

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashButton(label: '«', size: DashSize.sm, onPressed: page == 0 ? null : () => setState(() => _page = page - 1)),
        const SizedBox(width: 5),
        DashButton(label: '‹', size: DashSize.sm, onPressed: page <= 0 ? null : () => setState(() => _page = page - 1)),
        const SizedBox(width: 9),
        Text('${page + 1} / $pageCount', style: TextStyle(color: Dash.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 9),
        DashButton(label: '›', size: DashSize.sm, onPressed: page >= pageCount - 1 ? null : () => setState(() => _page = page + 1)),
        const SizedBox(width: 5),
        DashButton(label: '»', size: DashSize.sm, onPressed: page >= pageCount - 1 ? null : () => setState(() => _page = page + 1)),
        const SizedBox(width: 14),
        SizedBox(
          width: 96,
          child: DashSelect<int>(
            value: _perPage,
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 / page')),
              DropdownMenuItem(value: 25, child: Text('25 / page')),
              DropdownMenuItem(value: 50, child: Text('50 / page')),
              DropdownMenuItem(value: 100, child: Text('100 / page')),
              DropdownMenuItem(value: 250, child: Text('250 / page')),
            ],
            onChanged: (value) => setState(() {
              _perPage = value ?? 25;
              _page = 0;
            }),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(Dash.radius))),
      child: narrow ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summary, const SizedBox(height: 10), SingleChildScrollView(scrollDirection: Axis.horizontal, child: pager)]) : Row(children: [Expanded(child: summary), pager]),
    );
  }

  bool _allSelected(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty || !widget.showSelection) return false;
    for (final row in filtered) {
      if (!_selected.contains(_rowKey(row))) return false;
    }
    return true;
  }

  static String _rowKey(Map<String, dynamic> row) {
    final id = row['id'];
    final raw = id == null ? '' : id.toString();
    return raw.isEmpty ? row.hashCode.toString() : raw;
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.active,
    required this.ascending,
    required this.loading,
    required this.filtered,
    required this.onSort,
    required this.onFilter,
  });

  final GridColumn column;
  final bool active;
  final bool ascending;
  final bool loading;
  final int filtered;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisAlignment: column.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: InkWell(
              onTap: onSort,
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        column.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: active ? Dash.brand : Dash.muted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(width: 3),
                    if (loading)
                      SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.6, color: Dash.brand))
                    else
                      Icon(active ? (ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded, size: active ? 13 : 12, color: active ? Dash.brand : Dash.faint),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: filtered > 0 ? Dash.brandSoft : Colors.transparent, borderRadius: BorderRadius.circular(5)),
              child: Icon(filtered > 0 ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, size: 13, color: filtered > 0 ? Dash.brand : Dash.faint),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridRow extends StatefulWidget {
  const _GridRow({
    required this.children,
    required this.striped,
    required this.selected,
    this.leading,
    this.trailing,
    this.onSelect,
    this.onTap,
    super.key,
  });

  final List<Widget> children;
  final bool striped;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onSelect;
  final VoidCallback? onTap;

  @override
  State<_GridRow> createState() => _GridRowState();
}

class _GridRowState extends State<_GridRow> {
  var hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? Dash.brandSoft
        : hovered
            ? Dash.hover
            : widget.striped
                ? (Dash.dark ? Colors.transparent : Dash.soft)
                : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Container(
        color: background,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              height: 46,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Dash.border.withValues(alpha: 0.7)))),
              child: Row(
                children: [
                  if (widget.leading != null) widget.leading!,
                  ...widget.children,
                  if (widget.trailing != null)
                    SizedBox(width: 100, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Align(alignment: Alignment.centerLeft, child: widget.trailing!))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.onRemove});

  final String label;
  final int count;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 4, 4),
      decoration: BoxDecoration(color: Dash.brandSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label · $count', style: TextStyle(color: Dash.brand, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 12, color: Dash.brand)),
          ),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.title, required this.values, required this.selected});

  final String title;
  final List<String> values;
  final Set<String> selected;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late final Set<String> chosen = {...widget.selected};
  String needle = '';

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 40, 470.0);
    final needleText = needle.trim().toLowerCase();
    final shown = needleText.isEmpty ? widget.values : widget.values.where((value) => value.toLowerCase().contains(needleText)).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: width,
        decoration: BoxDecoration(color: Dash.surface, borderRadius: Dash.corners, border: Border.all(color: Dash.border), boxShadow: Dash.shadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: TextStyle(color: Dash.ink, fontSize: 15, fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => Navigator.of(context).pop(<String>{}), child: const Text('Clear all')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (value) => setState(() => needle = value),
                decoration: Dash.input(hint: 'Find a value…', prefix: const Icon(Icons.search_rounded)),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border))),
              child: shown.isEmpty
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('No value matches.', style: TextStyle(color: Dash.muted, fontSize: 13)))
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final value = shown[index];
                        return InkWell(
                          onTap: () => setState(() {
                            if (!chosen.add(value)) chosen.remove(value);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 34,
                                  width: 34,
                                  child: Checkbox(
                                    value: chosen.contains(value),
                                    onChanged: (_) => setState(() {
                                      if (!chosen.add(value)) chosen.remove(value);
                                    }),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border))),
              child: Row(
                children: [
                  Expanded(child: Text('${chosen.length} value${chosen.length == 1 ? '' : 's'} selected', style: TextStyle(color: Dash.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                  DashButton(label: 'Cancel', size: DashSize.sm, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  DashButton(label: 'Apply', variant: DashVariant.primary, size: DashSize.sm, onPressed: () => Navigator.of(context).pop(chosen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnsDialog extends StatefulWidget {
  const _ColumnsDialog({required this.columns, required this.hidden});

  final List<GridColumn> columns;
  final Set<String> hidden;

  @override
  State<_ColumnsDialog> createState() => _ColumnsDialogState();
}

class _ColumnsDialogState extends State<_ColumnsDialog> {
  late final Set<String> hidden = {...widget.hidden};
  String needle = '';

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 40, 450.0);
    final needleText = needle.trim().toLowerCase();
    final shown = needleText.isEmpty ? widget.columns : widget.columns.where((column) => column.label.toLowerCase().contains(needleText)).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: width,
        decoration: BoxDecoration(color: Dash.surface, borderRadius: Dash.corners, border: Border.all(color: Dash.border), boxShadow: Dash.shadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(child: Text('Visible columns', style: TextStyle(color: Dash.ink, fontSize: 15, fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => setState(hidden.clear), child: const Text('Show all')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (value) => setState(() => needle = value),
                decoration: Dash.input(hint: 'Find a column…', prefix: const Icon(Icons.search_rounded)),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 330),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border))),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final column = shown[index];
                  return InkWell(
                    onTap: () => setState(() {
                      if (!hidden.add(column.key)) hidden.remove(column.key);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 34,
                            width: 34,
                            child: Checkbox(
                              value: !hidden.contains(column.key),
                              onChanged: (_) => setState(() {
                                if (!hidden.add(column.key)) hidden.remove(column.key);
                              }),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          Expanded(child: Text(column.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                          Text(humanKey(column.key), style: TextStyle(color: Dash.faint, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border))),
              child: Row(
                children: [
                  Expanded(child: Text('${widget.columns.length - hidden.length} of ${widget.columns.length} visible', style: TextStyle(color: Dash.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                  DashButton(label: 'Cancel', size: DashSize.sm, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  DashButton(label: 'Apply', variant: DashVariant.primary, size: DashSize.sm, onPressed: () => Navigator.of(context).pop(hidden)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads a dotted path from a row, falling back to snake_case keys.
String readValue(Map<String, dynamic> row, String path) {
  dynamic current = row;
  for (final part in path.split('.')) {
    if (current is Map) {
      if (current.containsKey(part)) {
        current = current[part];
        continue;
      }
      final alt = _snake(part);
      if (current.containsKey(alt)) {
        current = current[alt];
        continue;
      }
      return '';
    }
    if (current is List) {
      final parts = <String>[];
      for (final item in current) {
        if (item is Map && item.containsKey(part)) parts.add(cellText(item[part]));
      }
      return parts.join(', ');
    }
    return '';
  }
  return cellText(current);
}

String _snake(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code >= 65 && code <= 90) {
      if (i > 0) buffer.write('_');
      buffer.write(code + 32);
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

/// Turns any API value into a readable cell string.
String cellText(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is num) return _formatNumber(value);
  if (value is Map) return value.isEmpty ? '' : '{${value.length} field${value.length == 1 ? '' : 's'}}';
  if (value is Iterable) {
    final items = value.take(4).map(cellText).where((item) => item.isNotEmpty).toList();
    if (items.isEmpty) return '';
    final extra = value.length > 4 ? ' +${value.length - 4}' : '';
    return '${items.join(', ')}$extra';
  }
  return value.toString();
}

String _formatNumber(num value) {
  if (value is int) return value.toString();
  return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}