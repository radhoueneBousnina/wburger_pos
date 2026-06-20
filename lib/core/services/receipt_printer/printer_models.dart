part of '../receipt_printer_service.dart';

const ReceiptPrinterConfig defaultReceiptPrinterConfig =
    ReceiptPrinterConfig.mm80(
  printLogo: true,
  useEscPosFormatting: true,
);

enum ReceiptPaperSize {
  mm58(widthMm: 58, charsPerLine: 32, logoWidthDots: 120),
  mm80(widthMm: 80, charsPerLine: 48, logoWidthDots: 150);

  final int widthMm;
  final int charsPerLine;
  final int logoWidthDots;

  const ReceiptPaperSize({
    required this.widthMm,
    required this.charsPerLine,
    required this.logoWidthDots,
  });
}

class ReceiptPrinterConfig {
  final ReceiptPaperSize paperSize;
  final int charsPerLine;
  final String storeName;
  final String? subtitle;
  final String? address;
  final String? phone;
  final String? taxId;
  final String? logoAssetPath;
  final bool printLogo;
  final bool showZeroDiscount;
  final bool useEscPosFormatting;

  ReceiptPrinterConfig({
    this.paperSize = ReceiptPaperSize.mm80,
    int? charsPerLine,
    this.storeName = 'W BURGER',
    this.subtitle = 'A win in every bite',
    this.address,
    this.phone,
    this.taxId,
    this.logoAssetPath = 'assets/logos/logo_yellow.png',
    this.printLogo = false,
    this.showZeroDiscount = false,
    this.useEscPosFormatting = false,
  }) : charsPerLine = charsPerLine ?? paperSize.charsPerLine;

  const ReceiptPrinterConfig.mm58({
    this.storeName = 'W BURGER',
    this.subtitle = 'A win in every bite',
    this.address,
    this.phone,
    this.taxId,
    this.logoAssetPath = 'assets/logos/logo_yellow.png',
    this.printLogo = false,
    this.showZeroDiscount = false,
    this.useEscPosFormatting = false,
  })  : paperSize = ReceiptPaperSize.mm58,
        charsPerLine = 32;

  const ReceiptPrinterConfig.mm80({
    this.storeName = 'W BURGER',
    this.subtitle = 'A win in every bite',
    this.address,
    this.phone,
    this.taxId,
    this.logoAssetPath = 'assets/logos/logo_yellow.png',
    this.printLogo = false,
    this.showZeroDiscount = false,
    this.useEscPosFormatting = false,
  })  : paperSize = ReceiptPaperSize.mm80,
        charsPerLine = 48;

  ReceiptPrinterConfig copyWith({
    ReceiptPaperSize? paperSize,
    int? charsPerLine,
    String? storeName,
    String? subtitle,
    String? address,
    String? phone,
    String? taxId,
    String? logoAssetPath,
    bool? printLogo,
    bool? showZeroDiscount,
    bool? useEscPosFormatting,
  }) {
    final nextPaperSize = paperSize ?? this.paperSize;
    final nextCharsPerLine = charsPerLine ??
        (paperSize == null ? this.charsPerLine : nextPaperSize.charsPerLine);
    return ReceiptPrinterConfig(
      paperSize: nextPaperSize,
      charsPerLine: nextCharsPerLine,
      storeName: storeName ?? this.storeName,
      subtitle: subtitle ?? this.subtitle,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      logoAssetPath: logoAssetPath ?? this.logoAssetPath,
      printLogo: printLogo ?? this.printLogo,
      showZeroDiscount: showZeroDiscount ?? this.showZeroDiscount,
      useEscPosFormatting: useEscPosFormatting ?? this.useEscPosFormatting,
    );
  }
}

class ReceiptModifier {
  final String label;
  final double? price;

  const ReceiptModifier({
    required this.label,
    this.price,
  });
}

class ReceiptLineComponent {
  final String name;
  final int quantity;
  final String? note;
  final List<String> sauceLines;

  const ReceiptLineComponent({
    required this.name,
    required this.quantity,
    this.note,
    this.sauceLines = const [],
  });

  factory ReceiptLineComponent.fromCartItem(CartItem item) {
    return ReceiptLineComponent(
      name: item.displayName,
      quantity: item.quantity,
      note: item.note,
      sauceLines: item.sauceDisplayLines,
    );
  }
}

class ReceiptLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final List<ReceiptModifier> modifiers;
  final String? note;
  final bool isDealComponent;
  final String? parentDealName;
  final List<ReceiptLineComponent> components;
  final List<String> sauceLines;

  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.modifiers = const [],
    this.note,
    this.isDealComponent = false,
    this.parentDealName,
    this.components = const [],
    this.sauceLines = const [],
  });

  factory ReceiptLine.fromCartItem(
    CartItem item, {
    List<CartItem> components = const [],
  }) {
    final discountAmount = item.discountAmount;
    final discountPercent = item.discountPercent;
    return ReceiptLine(
      name: item.displayName,
      quantity: item.quantity,
      unitPrice: item.isDealComponent
          ? 0
          : discountAmount > 0
              ? item.product.price
              : item.unitPrice,
      modifiers: [
        if (discountAmount > 0)
          ReceiptModifier(
            label: discountPercent == null
                ? 'Discount'
                : 'Discount ${discountPercent.toStringAsFixed(0)}%',
            price: -discountAmount,
          ),
      ],
      note: item.note,
      isDealComponent: item.isDealComponent,
      parentDealName: item.parentDealName,
      components: components.map(ReceiptLineComponent.fromCartItem).toList(),
      sauceLines: item.sauceDisplayLines,
    );
  }

  static List<ReceiptLine> fromCartItems(List<CartItem> items) {
    return groupCartItemsForDisplay(items)
        .map(
          (group) => ReceiptLine.fromCartItem(
            group.item,
            components: group.components,
          ),
        )
        .toList();
  }

  double get total => isDealComponent ? 0 : unitPrice * quantity;
}

class ReceiptData {
  final String ticketNumber;
  final String? orderId;
  final DateTime soldAt;
  final List<ReceiptLine> lines;
  final OrderType orderType;
  final String? orderTypeLabel;
  final PaymentType? paymentType;
  final String sourceLabel;
  final String? customerName;
  final String? customerPhone;
  final String? customerNote;
  final String? cashierName;
  final String? tableNumber;
  final double subtotal;
  final double discountAmount;
  final double? taxAmount;
  final double? deliveryFee;
  final double? serviceFee;
  final double totalAmount;
  final double? amountGiven;
  final double? changeReturned;
  final bool isReprint;

  const ReceiptData({
    required this.ticketNumber,
    required this.soldAt,
    required this.lines,
    required this.orderType,
    required this.sourceLabel,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    this.orderTypeLabel,
    this.orderId,
    this.paymentType,
    this.customerName,
    this.customerPhone,
    this.customerNote,
    this.cashierName,
    this.tableNumber,
    this.taxAmount,
    this.deliveryFee,
    this.serviceFee,
    this.amountGiven,
    this.changeReturned,
    this.isReprint = false,
  });

  factory ReceiptData.fromOrder(
    Order order, {
    String? cashierName,
    bool isReprint = false,
  }) {
    final subtotal =
        order.items.fold<double>(0, (sum, item) => sum + item.originalTotal);
    return ReceiptData(
      ticketNumber: order.ticketNumber.isNotEmpty
          ? order.ticketNumber
          : 'ORDER-${order.id}',
      orderId: order.id,
      soldAt: order.createdAt,
      lines: ReceiptLine.fromCartItems(order.items),
      orderType: order.orderType,
      paymentType: order.paymentType,
      sourceLabel: order.isQrOrder ? 'Mobile QR order' : 'POS sale',
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerNote: order.customerNote,
      cashierName: cashierName,
      subtotal: subtotal,
      discountAmount: order.discountAmount,
      totalAmount: order.total,
      amountGiven: order.amountGiven > 0 ? order.amountGiven : null,
      changeReturned: order.changeReturned > 0 ? order.changeReturned : null,
      isReprint: isReprint,
    );
  }

  factory ReceiptData.sampleTestReceipt() {
    return ReceiptData(
      ticketNumber: '101',
      soldAt: DateTime(DateTime.now().year, 5, 2, 19, 5),
      lines: const [
        ReceiptLine(
          name: 'Double Cheeseburger',
          quantity: 2,
          unitPrice: 12,
        ),
        ReceiptLine(name: 'Crispy Chicken Burger', quantity: 1, unitPrice: 13),
        ReceiptLine(name: 'Fries Large', quantity: 1, unitPrice: 6),
        ReceiptLine(name: 'Coca Cola 33cl', quantity: 2, unitPrice: 2.5),
      ],
      orderType: OrderType.dineIn,
      sourceLabel: 'POS sale',
      cashierName: 'Sami',
      subtotal: 48,
      discountAmount: 0,
      totalAmount: 48,
      amountGiven: 50,
      changeReturned: 2,
    );
  }
}

class ReceiptPrintResult {
  final int printerCount;
  final int printedCount;
  final List<String> failedPrinters;
  final bool unsupportedPlatform;
  final String? error;
  final String? successMessage;

  const ReceiptPrintResult({
    required this.printerCount,
    required this.printedCount,
    this.failedPrinters = const [],
    this.unsupportedPlatform = false,
    this.error,
    this.successMessage,
  });

  bool get sentToAnyPrinter => printerCount > 0 && printedCount > 0;

  bool get isSuccess =>
      error == null && printerCount > 0 && printedCount == printerCount;

  String get message {
    if (error != null) return error!;
    if (successMessage != null) return successMessage!;
    if (unsupportedPlatform) {
      return 'Direct thermal ticket printing is available on Windows, Linux, and macOS desktop apps.';
    }
    if (printerCount == 0) return 'No connected thermal printers were found.';
    if (failedPrinters.isEmpty) {
      return 'Ticket queued on $printedCount printer${printedCount == 1 ? '' : 's'}.';
    }
    return 'Ticket queued on $printedCount of $printerCount printers. Failed: ${failedPrinters.join(', ')}.';
  }
}

class CashDrawerStatusResult {
  final bool supported;
  final bool? isOpen;
  final bool? pin3High;
  final String? source;
  final String? error;

  const CashDrawerStatusResult({
    required this.supported,
    this.isOpen,
    this.pin3High,
    this.source,
    this.error,
  });

  bool get isReliable => supported && isOpen != null && error == null;

  String get message {
    if (error != null && error!.isNotEmpty) return error!;
    if (!supported) return 'Cash drawer status detection is not available.';
    if (isOpen == null) return 'Cash drawer status is unknown.';
    return isOpen! ? 'Cash drawer is open.' : 'Cash drawer is closed.';
  }
}
