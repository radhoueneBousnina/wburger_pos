part of '../receipt_printer_service.dart';

class ReceiptTicketBuilder {
  const ReceiptTicketBuilder();

  static Uint8List buildSmokeTestBytes(
    ReceiptPrinterConfig config, {
    DateTime? printedAt,
  }) {
    final composer = _RawTextTicketBuilder(columns: config.charsPerLine);
    _composeSmokeTest(composer, printedAt ?? DateTime.now());
    return composer.bytes();
  }

  static String buildSmokeTestPreview(
    ReceiptPrinterConfig config, {
    DateTime? printedAt,
  }) {
    final composer = _PlainTextTicketBuilder(columns: config.charsPerLine);
    _composeSmokeTest(composer, printedAt ?? DateTime.now());
    return composer.text();
  }

  static Uint8List buildCashDrawerPulseBytes({
    int pin = 0,
    int onTime = 25,
    int offTime = 250,
  }) {
    // Shotgun approach: Send both Pin 2 and Pin 5 pulses, and try both numeric and ASCII modes.
    // We use 100ms (0x32) as it proved more reliable in recent hardware tests.
    // We also include BEL and FS g commands for maximum compatibility with Chinese printers.
    return Uint8List.fromList([
      0x1b, 0x40, // Initialize
      0x1b, 0x70, 0x00, 0x32, 0xfa, // Pin 2 (0) - 100ms on, 500ms off
      0x1b, 0x70, 0x01, 0x32, 0xfa, // Pin 5 (1)
      0x1b, 0x70, 0x30, 0x32, 0xfa, // Pin 2 ('0')
      0x1b, 0x70, 0x31, 0x32, 0xfa, // Pin 5 ('1')
      0x07, // BEL command (works on some SPRT/Xprinter models)
      0x1c, 0x67, 0x00, // FS g command (Chinese printers variant)
    ]);
  }

  static Uint8List buildBrandCheckerStripBytes({
    required int columns,
  }) {
    final squareDots = columns >= 48 ? 16 : 12;
    final width = columns >= 48 ? 576 : 384;
    final height = squareDots * 3;
    final widthBytes = (width + 7) ~/ 8;
    final payload = <int>[
      0x1b, 0x61, 0x00, // Left alignment
      0x1d, 0x76, 0x30, 0x00, // GS v 0, normal raster mode
      widthBytes & 0xff,
      (widthBytes >> 8) & 0xff,
      height & 0xff,
      (height >> 8) & 0xff,
    ];

    for (var y = 0; y < height; y++) {
      final row = y ~/ squareDots;
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = (xByte * 8) + bit;
          if (x >= width) continue;
          final column = x ~/ squareDots;
          if ((row + column).isEven) {
            byte |= 0x80 >> bit;
          }
        }
        payload.add(byte);
      }
    }

    payload.addAll([
      0x1b, 0x61, 0x00, // Reset to left alignment
    ]);
    return Uint8List.fromList(payload);
  }

  static List<String> buildBrandCheckerStripTextRows({
    required int columns,
  }) {
    String rowFor(int row) {
      final buffer = StringBuffer();
      for (var column = 0; buffer.length < columns; column++) {
        buffer.write((row + column).isEven ? '[]' : '  ');
      }
      return buffer.toString().substring(0, columns);
    }

    return [rowFor(0), rowFor(1), rowFor(2)];
  }

  static void _composeSmokeTest(
    _TicketComposer builder,
    DateTime printedAt,
  ) {
    builder.line('W BURGER PRINTER TEST');
    builder.divider();
    builder.line('TEXT OK');
    builder.line('If you can read this,');
    builder.line('raw ESC/POS text works.');
    builder.leftRightText('Printed:', _formatDateTime(printedAt));
    builder.divider();
    builder.feed(4);
    builder.cut();
  }

  Future<Uint8List> buildBytes(
    ReceiptData data, {
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
    DateTime? printedAt,
    bool includeLogo = true,
    bool openDrawer = false,
  }) async {
    final composer = _byteComposer(config);
    final logoBytes = includeLogo && config.useEscPosFormatting
        ? await _buildLogoBytes(config)
        : null;
    final ticketNumberImageBytes = config.useEscPosFormatting
        ? await _buildTextImageBytes(
            _ticketDisplayNumber(data.ticketNumber),
            fontSize: 90,
            bold: true,
            maxWidth: 300,
          )
        : null;
    _composeReceipt(
      composer,
      data,
      config: config,
      printedAt: printedAt ?? DateTime.now(),
      logoBytes: logoBytes,
      ticketNumberImageBytes: ticketNumberImageBytes,
      openDrawer: openDrawer,
    );
    return _composerBytes(composer);
  }

  Uint8List buildBytesSync(
    ReceiptData data, {
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
    DateTime? printedAt,
  }) {
    final composer = _byteComposer(config);
    _composeReceipt(
      composer,
      data,
      config: config,
      printedAt: printedAt ?? DateTime.now(),
    );
    return _composerBytes(composer);
  }

  String buildPreviewText(
    ReceiptData data, {
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
    DateTime? printedAt,
  }) {
    final composer = _PlainTextTicketBuilder(columns: config.charsPerLine);
    _composeReceipt(
      composer,
      data,
      config: config,
      printedAt: printedAt ?? DateTime.now(),
    );
    return composer.text();
  }

  void _composeReceipt(
    _TicketComposer builder,
    ReceiptData data, {
    required ReceiptPrinterConfig config,
    required DateTime printedAt,
    Uint8List? logoBytes,
    Uint8List? ticketNumberImageBytes,
    bool openDrawer = false,
  }) {
    _buildLogoSection(builder, data, config, logoBytes);
    _buildOrderInfoSection(builder, data, ticketNumberImageBytes);
    _buildItemsSection(builder, data.lines);
    _buildTotalsSection(builder, data, config);
    _buildNotesSection(builder, data);
    _buildFooterSection(builder);
    if (openDrawer) {
      builder.openCashDrawer();
    }
  }

  void _buildLogoSection(
    _TicketComposer builder,
    ReceiptData data,
    ReceiptPrinterConfig config,
    Uint8List? logoBytes,
  ) {
    if (logoBytes != null && logoBytes.isNotEmpty) {
      builder.raw(logoBytes);
      builder.blank();
    } else {
      final storeName = _clean(config.storeName).toUpperCase();
      if (storeName == 'W BURGER' || storeName == 'WBURGER') {
        builder.center('W', bold: true, doubleSize: true);
        builder.center('BURGER', bold: true);
      } else {
        builder.center(config.storeName, bold: true, doubleSize: true);
      }
    }

    if (_hasText(config.subtitle)) {
      builder.center(config.subtitle!.trim());
    }
    builder.blank();
    builder.brandCheckerStrip();
    if (_hasText(config.address)) {
      builder.wrappedCentered(config.address!.trim());
    }
    if (_hasText(config.phone)) {
      builder.center('Tel: ${config.phone!.trim()}');
    }
    if (_hasText(config.taxId)) {
      builder.center('MF: ${config.taxId!.trim()}');
    }
    if (data.isReprint) {
      builder.center('REPRINT', bold: true);
    }
    builder.blank();
  }

  void _buildOrderInfoSection(
    _TicketComposer builder,
    ReceiptData data, [
    Uint8List? ticketNumberImageBytes,
  ]) {
    final ticket = _ticketDisplayNumber(
      data.ticketNumber.trim().isNotEmpty
          ? data.ticketNumber.trim()
          : 'ORDER-${data.orderId ?? '-'}',
    );
    if (ticketNumberImageBytes != null && ticketNumberImageBytes.isNotEmpty) {
      builder.rasterImage(ticketNumberImageBytes);
    } else {
      builder.centerLarge(ticket);
    }
    _detailRow(builder, 'Date:', _formatDateTime(data.soldAt));
    if (_hasText(data.cashierName)) {
      _detailRow(builder, 'Cashier:', data.cashierName!.trim());
    }
    _detailRow(
      builder,
      'Type:',
      data.orderTypeLabel ?? _orderTypeLabel(data.orderType),
    );
    if (data.orderType == OrderType.dineIn && _hasText(data.tableNumber)) {
      _detailRow(builder, 'Table:', data.tableNumber!.trim());
    }
    if (_hasText(data.customerName)) {
      _detailRow(builder, 'Customer:', data.customerName!.trim());
    }
    if (_hasText(data.customerPhone)) {
      _detailRow(builder, 'Phone:', data.customerPhone!.trim());
    }
    builder.divider();
  }

  void _detailRow(_TicketComposer builder, String label, String value) {
    final valueColumn = builder.columns <= 32 ? 11 : 16;
    final cleanLabel = _clean(label);
    final prefix = cleanLabel.length >= valueColumn
        ? '$cleanLabel '
        : cleanLabel.padRight(valueColumn);
    final valueWidth = math.max(8, builder.columns - prefix.length);
    final valueLines = _wrapText(value, valueWidth);
    if (valueLines.isEmpty) {
      builder.line(prefix.trimRight());
      return;
    }

    builder.line('$prefix${valueLines.first}');
    for (final line in valueLines.skip(1)) {
      builder.line('${' ' * prefix.length}$line');
    }
  }

  void _buildItemsSection(_TicketComposer builder, List<ReceiptLine> lines) {
    builder.tableHeader();
    builder.divider();

    if (lines.isEmpty) {
      builder.line('No items');
      builder.divider();
      return;
    }

    for (final line in lines) {
      _writeItem(builder, line);
    }
    builder.divider();
  }

  void _writeItem(_TicketComposer builder, ReceiptLine line) {
    final quantity = math.max(1, line.quantity);
    builder.itemRow(
      quantity: quantity,
      name: line.name,
      price: line.isDealComponent ? '' : _formatMoney(line.total),
      bold: true,
    );

    if (line.isDealComponent && _hasText(line.parentDealName)) {
      builder.modifierRow('- From ${line.parentDealName!.trim()}');
    }
    for (final modifier in line.modifiers) {
      _writeModifier(builder, modifier);
    }
    if (_hasText(line.note)) {
      builder.modifierRow('- Note: ${line.note!.trim()}');
    }
  }

  void _writeModifier(_TicketComposer builder, ReceiptModifier modifier) {
    final label = '- ${modifier.label.trim()}';
    final price = modifier.price;
    if (price == null) {
      builder.modifierRow(label);
      return;
    }
    builder.modifierRow(label, price: _formatMoney(price));
  }

  void _buildTotalsSection(
    _TicketComposer builder,
    ReceiptData data,
    ReceiptPrinterConfig config,
  ) {
    builder.moneyLine('Subtotal:', data.subtotal);
    if (data.discountAmount > 0) {
      builder.moneyLine('Remise:', -data.discountAmount);
    }
    if (data.taxAmount != null) {
      builder.moneyLine('TVA:', data.taxAmount!);
    }
    if (data.deliveryFee != null) {
      builder.moneyLine('Delivery:', data.deliveryFee!);
    }
    if (data.serviceFee != null) {
      builder.moneyLine('Service:', data.serviceFee!);
    }
    builder.moneyLine(
      'Total:',
      data.totalAmount,
      bold: true,
      doubleSize: true,
    );
    if (data.amountGiven != null) {
      builder.moneyLine('Paid:', data.amountGiven!);
    }
    if (data.changeReturned != null) {
      builder.moneyLine('Change:', data.changeReturned!);
    }
    builder.divider();
  }

  void _buildNotesSection(_TicketComposer builder, ReceiptData data) {
    if (!_hasText(data.customerNote)) return;

    builder.line('SPECIAL NOTE', bold: true);
    builder.wrapped(data.customerNote!.trim());
    builder.divider();
  }

  void _buildFooterSection(_TicketComposer builder) {
    builder.center('THANK YOU!', bold: true);
    builder.center('See you soon');
    builder.feed(5);
    builder.cut();
  }

  Future<Uint8List?> _buildLogoBytes(ReceiptPrinterConfig config) async {
    final assetPath = config.logoAssetPath;
    if (!config.printLogo || !_hasText(assetPath)) return null;

    try {
      final data = await rootBundle.load(assetPath!);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: config.paperSize.logoWidthDots,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final bytes = _rasterizeLogo(
        byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
      if (kDebugMode) {
        debugPrint('[Printer] Receipt logo loaded from $assetPath');
      }
      return bytes;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Printer] Receipt logo skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Uint8List _rasterizeLogo(
    Uint8List rgba, {
    required int width,
    required int height,
  }) {
    // ESC/POS raster bit image. Transparent brand assets are treated as an
    // alpha mask so the yellow logo prints as solid black thermal ink.
    final widthBytes = (width + 7) ~/ 8;
    final usesAlphaMask = _hasMeaningfulTransparency(rgba);
    var inkPixels = 0;
    final payload = <int>[
      0x1b, 0x61, 0x01, // Center alignment
      0x1d, 0x76, 0x30, 0x00, // GS v 0, normal raster mode
      widthBytes & 0xff,
      (widthBytes >> 8) & 0xff,
      height & 0xff,
      (height >> 8) & 0xff,
    ];

    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = (xByte * 8) + bit;
          if (x >= width) continue;
          final offset = (y * width + x) * 4;
          final red = rgba[offset];
          final green = rgba[offset + 1];
          final blue = rgba[offset + 2];
          final alpha = rgba[offset + 3];
          final luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue);

          final shouldPrint =
              usesAlphaMask ? alpha > 48 : alpha > 64 && luminance < 180;
          if (shouldPrint) {
            byte |= 0x80 >> bit;
            inkPixels++;
          }
        }
        payload.add(byte);
      }
    }

    payload.addAll([
      0x1b, 0x61, 0x00, // Reset to left alignment
    ]);

    if (kDebugMode) {
      debugPrint(
        '[Printer] Rasterized logo: ${width}x$height, '
        '$widthBytes bytes/row, inkPixels=$inkPixels, alphaMask=$usesAlphaMask',
      );
    }
    return Uint8List.fromList(payload);
  }

  bool _hasMeaningfulTransparency(Uint8List rgba) {
    var transparentPixels = 0;
    final totalPixels = rgba.length ~/ 4;
    for (var offset = 3; offset < rgba.length; offset += 4) {
      if (rgba[offset] < 250) transparentPixels++;
    }
    return transparentPixels > totalPixels * 0.02;
  }

  Future<Uint8List?> _buildTextImageBytes(
    String text, {
    required double fontSize,
    required bool bold,
    required int maxWidth,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
        fontFamily: 'BalooBhaijaan2',
      ));
      pb.addText(text);

      final paragraph = pb.build()
        ..layout(ui.ParagraphConstraints(width: maxWidth.toDouble()));

      canvas.drawParagraph(paragraph, ui.Offset.zero);

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        maxWidth,
        paragraph.height.toInt().clamp(1, 1000),
      );

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final bytes = _rasterizeLogo(
        byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
      return bytes;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Printer] Text-to-image rendering skipped: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  _TicketComposer _byteComposer(ReceiptPrinterConfig config) {
    if (config.useEscPosFormatting) {
      return _EscPosTicketBuilder(columns: config.charsPerLine)..init();
    }
    return _RawTextTicketBuilder(columns: config.charsPerLine);
  }

  Uint8List _composerBytes(_TicketComposer composer) {
    if (composer is _EscPosTicketBuilder) return composer.bytes();
    if (composer is _RawTextTicketBuilder) return composer.bytes();
    throw StateError('Unsupported ticket byte composer.');
  }
}

abstract interface class _TicketComposer {
  int get columns;
  void openCashDrawer();
  void raw(List<int> bytes);
  void rasterImage(Uint8List bytes);
  void brandCheckerStrip();
  void center(String text, {bool bold = false, bool doubleSize = false});
  void centerLarge(String text);
  void wrappedCentered(String text);
  void keyValue(String label, String value);
  void tableHeader();
  void itemRow({
    required int quantity,
    required String name,
    required String price,
    bool bold = false,
  });
  void modifierRow(String label, {String? price});
  void leftRightText(
    String left,
    String right, {
    bool bold = false,
    int minLeftWidth = 8,
  });
  void moneyLine(
    String label,
    double value, {
    bool bold = false,
    bool doubleSize = false,
  });
  void wrapped(String text, {int indent = 0});
  void divider([String char = '-']);
  void rule(String char);
  void line(String text, {bool bold = false});
  void blank();
  void feed(int lines);
  void cut();
}
