part of '../receipt_printer_service.dart';

class _PlainTextTicketBuilder implements _TicketComposer {
  @override
  final int columns;
  final List<String> _lines = [];

  _PlainTextTicketBuilder({required this.columns});

  @override
  void openCashDrawer() {}

  @override
  void raw(List<int> bytes) {}

  @override
  void rasterImage(Uint8List bytes) {}

  @override
  void brandCheckerStrip() {
    for (final row in ReceiptTicketBuilder.buildBrandCheckerStripTextRows(
      columns: columns,
    )) {
      _lines.add(row);
    }
  }

  @override
  void center(String text, {bool bold = false, bool doubleSize = false}) {
    final width = doubleSize ? math.max(12, columns ~/ 2) : columns;
    for (final lineText in _wrapText(text, width)) {
      _lines.add(_centerLine(lineText));
    }
  }

  @override
  void centerLarge(String text) {
    for (final lineText in _wrapText(text, math.max(6, columns ~/ 4))) {
      _lines.add(_centerLine(lineText));
    }
  }

  @override
  void wrappedCentered(String text) {
    for (final lineText in _wrapText(text, columns)) {
      _lines.add(_centerLine(lineText));
    }
  }

  @override
  void keyValue(String label, String value) {
    leftRightText(label, value);
  }

  @override
  void tableHeader() {
    final columns = _tableColumns();
    line(
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
    line(
      '${_quantityInColumn(quantity, columns.qty)}'
      '${firstName.padRight(columns.name)}'
      '${_clean(price).padLeft(columns.price)}',
      bold: bold,
    );
    for (final lineText in nameLines.skip(1)) {
      line(
        '${''.padRight(columns.qty)}${lineText.padRight(columns.name)}',
        bold: bold,
      );
    }
  }

  @override
  void modifierRow(String label, {String? price}) {
    final columns = _tableColumns();
    final textLines = _wrapText(label, columns.name);
    final cleanPrice = price == null ? '' : _clean(price);
    for (var index = 0; index < textLines.length; index++) {
      final lineText = textLines[index];
      line(
        '${''.padRight(columns.qty)}'
        '${lineText.padRight(columns.name)}'
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
    final cleanRight = _clean(right);
    final cleanLeft = _clean(left);
    final leftWidth = math.max(minLeftWidth, columns - cleanRight.length - 1);
    if (cleanRight.length + 1 >= columns) {
      line(cleanLeft, bold: bold);
      wrapped(cleanRight, indent: 2);
      return;
    }
    final wrappedLeft = _wrapText(cleanLeft, leftWidth);
    final firstLeft = wrappedLeft.isEmpty ? '' : wrappedLeft.first;
    line('${firstLeft.padRight(leftWidth)} $cleanRight', bold: bold);
    for (final extraLine in wrappedLeft.skip(1)) {
      line(extraLine, bold: bold);
    }
  }

  @override
  void moneyLine(
    String label,
    double value, {
    bool bold = false,
    bool doubleSize = false,
  }) {
    leftRightText(label, _formatMoney(value), bold: bold);
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
    _lines.add(_cleanLayout(text).trimRight());
  }

  @override
  void blank() {
    _lines.add('');
  }

  @override
  void feed(int lines) {
    _lines.addAll(List<String>.filled(lines.clamp(0, 255).toInt(), ''));
  }

  @override
  void cut() {}

  String text() => _lines.join('\n').trimRight();

  String _centerLine(String value) {
    final clean = _clean(value);
    if (clean.length >= columns) return clean;
    final leftPadding = ((columns - clean.length) / 2).floor();
    return '${' ' * leftPadding}$clean';
  }

  _ReceiptTableColumns _tableColumns() =>
      _ReceiptTableColumns.forWidth(columns);
}

class _RawTextTicketBuilder extends _PlainTextTicketBuilder {
  final List<int> _finalCommands = [];
  final List<int> _initialCommands = [];

  _RawTextTicketBuilder({required super.columns}) {
    _initialCommands.addAll([0x1b, 0x40]);
  }

  @override
  void openCashDrawer() {
    _initialCommands
      ..clear()
      ..addAll(ReceiptTicketBuilder.buildCashDrawerPulseBytes());
  }

  @override
  void raw(List<int> bytes) {
    // Safe mode ignores hardware-specific blobs to prevent blank prints
  }

  @override
  void cut() {
    _finalCommands.addAll([0x1d, 0x56, 0x00]);
  }

  Uint8List bytes() {
    // Use CRLF for maximum compatibility with both old and new printers
    final text = _lines.join('\r\n');
    final payload = <int>[
      ..._initialCommands,
      ...ascii.encode(text),
      0x0d,
      0x0a,
      ..._finalCommands,
    ];
    return Uint8List.fromList(payload);
  }
}

class _ReceiptTableColumns {
  final int qty;
  final int name;
  final int price;

  const _ReceiptTableColumns({
    required this.qty,
    required this.name,
    required this.price,
  });

  factory _ReceiptTableColumns.forWidth(int columns) {
    final qty = columns <= 32 ? 4 : 8;
    final price = columns <= 32 ? 8 : 10;
    return _ReceiptTableColumns(
      qty: qty,
      name: math.max(10, columns - qty - price),
      price: price,
    );
  }
}
