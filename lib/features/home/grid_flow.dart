library;

import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';

/// FEAT-01: the free-form home canvas flow.
///
/// Widgets claim rectangular spans at explicit (row, col) anchors — or the
/// first free slot when they carry no anchor (legacy placements, fresh
/// drops). App and folder cells then flow into every cell the widgets left
/// free, row-major. Collisions resolve by sliding a widget down (column
/// held) to the first rect that fits, so nothing ever overlaps and apps
/// simply re-flow around the result.
///
/// One unit row is `canvasRowPitch` tall and `columns` cells wide; the
/// renderer maps slots to pixels.

const double canvasRowPitch = 98;
const double canvasGutter = 12;

@immutable
class GridSlot {
  const GridSlot(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridSlot && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'GridSlot($row, $col)';
}

@immutable
class GridCellSlot {
  const GridCellSlot(this.cell, this.row, this.col);

  final HomeCell cell;
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridCellSlot &&
      other.row == row &&
      other.col == col &&
      other.cell == cell;

  @override
  int get hashCode => Object.hash(cell, row, col);
}

@immutable
class GridFlowResult {
  const GridFlowResult({
    required this.rows,
    required this.widgetSlots,
    required this.cellSlots,
  });

  final int rows;
  final Map<String, GridSlot> widgetSlots;
  final List<GridCellSlot> cellSlots;

  GridSlot? slotOf(String widgetId) => widgetSlots[widgetId];
}

class _Occupancy {
  final Set<String> _taken = <String>{};

  bool fits(int row, int col, int w, int h) {
    for (var r = row; r < row + h; r++) {
      for (var c = col; c < col + w; c++) {
        if (_taken.contains('$r:$c')) return false;
      }
    }
    return true;
  }

  void claim(int row, int col, int w, int h) {
    for (var r = row; r < row + h; r++) {
      for (var c = col; c < col + w; c++) {
        _taken.add('$r:$c');
      }
    }
  }

  void release(int row, int col, int w, int h) {
    for (var r = row; r < row + h; r++) {
      for (var c = col; c < col + w; c++) {
        _taken.remove('$r:$c');
      }
    }
  }
}

GridFlowResult computeGridFlow({
  required List<HomeCell> cells,
  required List<PlacedWidget> widgets,
  required int columns,
}) {
  final occupancy = _Occupancy();
  final slots = <String, GridSlot>{};
  var maxRow = -1;

  final anchored = <PlacedWidget>[];
  final floating = <PlacedWidget>[];
  for (final w in widgets) {
    (w.needsPosition ? floating : anchored).add(w);
  }

  void settle(PlacedWidget widget) {
    final w = widget.w.clamp(1, columns);
    final h = widget.h.clamp(1, 8);
    final startCol = (widget.col ?? 0).clamp(0, columns - w);
    var row = (widget.row ?? 0).clamp(0, 1 << 20);
    while (!occupancy.fits(row, startCol, w, h)) {
      row++;
    }
    occupancy.claim(row, startCol, w, h);
    slots[widget.id] = GridSlot(row, startCol);
    if (row + h - 1 > maxRow) maxRow = row + h - 1;
  }

  for (final w in anchored) {
    settle(w);
  }
  for (final w in floating) {
    settle(w);
  }

  final cellSlots = <GridCellSlot>[];
  var cursorRow = 0;
  var cursorCol = 0;
  for (final cell in cells) {
    var guard = 0;
    while (guard++ < 10000) {
      if (cursorCol >= columns) {
        cursorCol = 0;
        cursorRow++;
        continue;
      }
      if (!occupancy.fits(cursorRow, cursorCol, 1, 1)) {
        cursorCol++;
        continue;
      }
      break;
    }
    occupancy.claim(cursorRow, cursorCol, 1, 1);
    cellSlots.add(GridCellSlot(cell, cursorRow, cursorCol));
    if (cursorRow > maxRow) maxRow = cursorRow;
    cursorCol++;
  }

  return GridFlowResult(
    rows: maxRow + 1,
    widgetSlots: Map.unmodifiable(slots),
    cellSlots: List.unmodifiable(cellSlots),
  );
}

/// First anchor for a new widget of span [w]×[h] dropped with its top-left
/// near (row, col): slides down from the requested anchor like settle().
GridSlot resolveDropAnchor({
  required List<PlacedWidget> existing,
  required int row,
  required int col,
  required int w,
  required int h,
  required int columns,
}) {
  final occupancy = _Occupancy();
  for (final widget in existing) {
    final slot = widget.row != null && widget.col != null
        ? GridSlot(widget.row!, widget.col!)
        : null;
    if (slot == null) continue;
    occupancy.claim(
      slot.row,
      slot.col,
      widget.w.clamp(1, columns),
      widget.h.clamp(1, 8),
    );
  }
  final safeW = w.clamp(1, columns);
  final startCol = col.clamp(0, columns - safeW);
  var r = row.clamp(0, 1 << 20);
  while (!occupancy.fits(r, startCol, safeW, h)) {
    r++;
  }
  return GridSlot(r, startCol);
}
