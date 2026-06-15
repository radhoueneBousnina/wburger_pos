part of '../receipt_printer_service.dart';

String _formatMoney(double value) => value.toStringAsFixed(3);

String _formatDateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm').format(value);

String _orderTypeLabel(OrderType type) {
  switch (type) {
    case OrderType.dineIn:
      return 'Dine-in';
    case OrderType.takeaway:
      return 'Takeaway';
    case OrderType.glovo:
      return 'Glovo';
  }
}

String _ticketDisplayNumber(String ticketNumber) {
  final clean = _clean(ticketNumber);
  final parts = clean.split('-').where((part) => part.trim().isNotEmpty);
  if (parts.isEmpty) return clean;
  return parts.last.trim();
}

String _centerInColumn(String value, int width) {
  final clean = _clean(value);
  if (clean.length >= width) return clean.substring(0, width);
  final leftPadding = ((width - clean.length) / 2).floor();
  final rightPadding = width - clean.length - leftPadding;
  return '${' ' * leftPadding}$clean${' ' * rightPadding}';
}

String _quantityInColumn(int quantity, int width) {
  if (quantity <= 0) return ''.padRight(width);
  final clean = math.max(1, quantity).toString();
  final leftWidth = math.min(3, math.max(1, width));
  return clean.padLeft(leftWidth).padRight(width);
}

List<String> _wrapText(String value, int width) {
  final text = _clean(value);
  if (text.isEmpty) return const [];
  final safeWidth = math.max(1, width);
  final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  final lines = <String>[];
  var current = '';

  for (final word in words) {
    if (word.length > safeWidth) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      for (var i = 0; i < word.length; i += safeWidth) {
        lines.add(word.substring(i, math.min(i + safeWidth, word.length)));
      }
      continue;
    }

    if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= safeWidth) {
      current = '$current $word';
    } else {
      lines.add(current);
      current = word;
    }
  }

  if (current.isNotEmpty) lines.add(current);
  return lines;
}

String _clean(String value) {
  // This raw ESC/POS path uses PC437/ASCII-safe text. French accents are
  // transliterated; Arabic needs printer-specific code pages or image text.
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return _asciiSafe(normalized);
}

String _cleanLayout(String value) {
  // Same ASCII transliteration as _clean, but preserves column padding.
  return _asciiSafe(value);
}

String _asciiSafe(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 32 && rune <= 126) {
      buffer.writeCharCode(rune);
      continue;
    }
    buffer.write(_asciiReplacement(rune));
  }
  return buffer.toString();
}

String _asciiReplacement(int rune) {
  switch (rune) {
    case 0x00a0:
      return ' ';
    case 0x00c0:
    case 0x00c1:
    case 0x00c2:
    case 0x00c3:
    case 0x00c4:
    case 0x00c5:
    case 0x00e0:
    case 0x00e1:
    case 0x00e2:
    case 0x00e3:
    case 0x00e4:
    case 0x00e5:
      return 'a';
    case 0x00c7:
    case 0x00e7:
      return 'c';
    case 0x00c8:
    case 0x00c9:
    case 0x00ca:
    case 0x00cb:
    case 0x00e8:
    case 0x00e9:
    case 0x00ea:
    case 0x00eb:
      return 'e';
    case 0x00cc:
    case 0x00cd:
    case 0x00ce:
    case 0x00cf:
    case 0x00ec:
    case 0x00ed:
    case 0x00ee:
    case 0x00ef:
      return 'i';
    case 0x00d1:
    case 0x00f1:
      return 'n';
    case 0x00d2:
    case 0x00d3:
    case 0x00d4:
    case 0x00d5:
    case 0x00d6:
    case 0x00f2:
    case 0x00f3:
    case 0x00f4:
    case 0x00f5:
    case 0x00f6:
      return 'o';
    case 0x00d9:
    case 0x00da:
    case 0x00db:
    case 0x00dc:
    case 0x00f9:
    case 0x00fa:
    case 0x00fb:
    case 0x00fc:
      return 'u';
    case 0x00dd:
    case 0x00fd:
    case 0x00ff:
      return 'y';
    case 0x2013:
    case 0x2014:
    case 0x2212:
      return '-';
    case 0x2018:
    case 0x2019:
      return "'";
    case 0x201c:
    case 0x201d:
      return '"';
    case 0x00d7:
      return 'x';
    default:
      return '?';
  }
}
