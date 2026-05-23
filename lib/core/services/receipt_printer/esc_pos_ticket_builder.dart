part of '../receipt_printer_service.dart';

class _EscPosTicketBuilder implements _TicketComposer {
  @override
  final int columns;
  final List<int> _data = [];

  _EscPosTicketBuilder({required this.columns});

  void init() {
    _data.addAll([
      0x1b, 0x40, // Initialize printer
      0x1b, 0x61, 0x00, // Left alignment
      0x1b, 0x45, 0x00, // Bold off
      0x1d, 0x21, 0x00, // Normal character size
    ]);
  }

  @override
  void openCashDrawer() {
    _data.addAll(ReceiptTicketBuilder.buildCashDrawerPulseBytes());
  }

  @override
  void raw(List<int> bytes) {
    _data.addAll(bytes);
  }

  @override
  void rasterImage(Uint8List bytes) {
    _data.addAll(bytes);
  }

  @override
  void brandCheckerStrip() {
    _data.addAll(
      ReceiptTicketBuilder.buildBrandCheckerStripBytes(columns: columns),
    );
  }

  @override
  void center(String text, {bool bold = false, bool doubleSize = false}) {
    _data.addAll([0x1b, 0x61, 0x01]);
    _styled(
      () {
        final width = doubleSize ? math.max(12, columns ~/ 2) : columns;
        for (final lineText in _wrapText(text, width)) {
          line(lineText);
        }
      },
      bold: bold,
      doubleSize: doubleSize,
    );
    _data.addAll([0x1b, 0x61, 0x00]);
  }

  @override
  void centerLarge(String text) {
    _data.addAll([0x1b, 0x61, 0x01]);
    _styled(
      () {
        final width = math.max(6, columns ~/ 2);
        for (final lineText in _wrapText(text, width)) {
          line(lineText);
        }
      },
      bold: true,
      scale: 2,
    );
    _data.addAll([0x1b, 0x61, 0x00]);
  }

  @override
  void wrappedCentered(String text) {
    _data.addAll([0x1b, 0x61, 0x01]);
    for (final lineText in _wrapText(text, columns)) {
      line(lineText);
    }
    _data.addAll([0x1b, 0x61, 0x00]);
  }

  @override
  void keyValue(String label, String value) {
    leftRightText(label, value);
  }

  @override
  void tableHeader() {
    final columns = _tableColumns();
    _lineWithStyle(
      '${'QTY'.padRight(columns.qty)}'
      '${_centerInColumn('ARTICLE', columns.name)}'
      '${'PRICE'.padLeft(columns.price)}',
      bold: true,
    );
  }

  @override
  void itemRow({
    required int quantity,
    required String name,
    required String price,
    bool bold = false,
  }) {
    final columns = _tableColumns();
    final nameLines = _wrapText(name, columns.name);
    final firstName = nameLines.isEmpty ? 'Item' : nameLines.first;
    _lineWithStyle(
      '${_quantityInColumn(quantity, columns.qty)}'
      '${firstName.padRight(columns.name)}'
      '${_clean(price).padLeft(columns.price)}',
      bold: bold,
    );
    for (final line in nameLines.skip(1)) {
      _lineWithStyle(
        '${''.padRight(columns.qty)}${line.padRight(columns.name)}',
        bold: bold,
      );
    }
  }

  @override
  void modifierRow(String label, {String? price}) {
    final columns = _tableColumns();
    final modifierWidth = columns.name;
    final textLines = _wrapText(label, modifierWidth);
    final cleanPrice = price == null ? '' : _clean(price);
    for (var index = 0; index < textLines.length; index++) {
      final line = textLines[index];
      _lineWithStyle(
        '${''.padRight(columns.qty)}'
        '${line.padRight(columns.name)}'
        '${(index == 0 ? cleanPrice : '').padLeft(columns.price)}',
      );
    }
  }

  @override
  void leftRightText(
    String left,
    String right, {
    bool bold = false,
    int minLeftWidth = 8,
  }) {
    _leftRightText(
      left,
      right,
      bold: bold,
      minLeftWidth: minLeftWidth,
    );
  }

  @override
  void moneyLine(
    String label,
    double value, {
    bool bold = false,
    bool doubleSize = false,
  }) {
    _leftRightText(
      label,
      _formatMoney(value),
      bold: bold,
      doubleSize: doubleSize,
    );
  }

  @override
  void wrapped(String text, {int indent = 0}) {
    final prefix = ' ' * indent;
    final width = math.max(8, columns - indent);
    for (final lineText in _wrapText(text, width)) {
      line('$prefix$lineText');
    }
  }

  @override
  void rule(String char) {
    final cleanChar = _clean(char);
    final value = cleanChar.isEmpty ? '-' : cleanChar[0];
    line(value * columns);
  }

  @override
  void divider([String char = '-']) {
    rule(char);
  }

  @override
  void line(String text, {bool bold = false}) {
    _lineWithStyle(text, bold: bold);
  }

  @override
  void blank() {
    _data.addAll([0x0d, 0x0a]);
  }

  void _leftRightText(
    String left,
    String right, {
    bool bold = false,
    bool doubleSize = false,
    int minLeftWidth = 8,
  }) {
    final cleanRight = _clean(right);
    final cleanLeft = _clean(left);
    final width = doubleSize ? math.max(12, columns ~/ 2) : columns;
    final leftWidth = math.max(minLeftWidth, width - cleanRight.length - 1);
    if (cleanRight.length + 1 >= width) {
      _lineWithStyle(cleanLeft, bold: bold, doubleSize: doubleSize);
      wrapped(cleanRight, indent: 2);
      return;
    }

    final wrappedLeft = _wrapText(cleanLeft, leftWidth);
    final firstLeft = wrappedLeft.isEmpty ? '' : wrappedLeft.first;
    _lineWithStyle(
      '${firstLeft.padRight(leftWidth)} $cleanRight',
      bold: bold,
      doubleSize: doubleSize,
    );
    for (final extraLine in wrappedLeft.skip(1)) {
      _lineWithStyle(extraLine, bold: bold, doubleSize: doubleSize);
    }
  }

  void _lineWithStyle(
    String text, {
    bool bold = false,
    bool doubleSize = false,
  }) {
    _styled(
      () {
        _data.addAll(ascii.encode(_cleanLayout(text).trimRight()));
        _data.addAll([0x0d, 0x0a]); // CR LF for maximum compatibility
      },
      bold: bold,
      doubleSize: doubleSize,
    );
  }

  _ReceiptTableColumns _tableColumns() =>
      _ReceiptTableColumns.forWidth(columns);

  @override
  void feed(int lines) {
    _data.addAll([0x1b, 0x64, lines.clamp(0, 255).toInt()]);
  }

  @override
  void cut() {
    _data.addAll([0x1d, 0x56, 0x00]); // Full cut, same family as manual test
  }

  Uint8List bytes() => Uint8List.fromList(_data);

  void _styled(
    void Function() body, {
    bool bold = false,
    bool doubleSize = false,
    int scale = 1,
  }) {
    final effectiveScale =
        math.max(scale, doubleSize ? 2 : 1).clamp(1, 8).toInt();
    if (bold) {
      _data.addAll([0x1b, 0x45, 0x01]); // Emphasized
      _data.addAll([0x1b, 0x47, 0x01]); // Double-strike
    }
    if (effectiveScale > 1) {
      final sizeByte = ((effectiveScale - 1) << 4) | (effectiveScale - 1);
      _data.addAll([0x1d, 0x21, sizeByte]);
    }
    body();
    if (effectiveScale > 1) _data.addAll([0x1d, 0x21, 0x00]);
    if (bold) {
      _data.addAll([0x1b, 0x47, 0x00]); // Reset double-strike
      _data.addAll([0x1b, 0x45, 0x00]); // Reset emphasized
    }
  }
}
