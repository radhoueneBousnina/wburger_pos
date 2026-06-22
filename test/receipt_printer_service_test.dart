import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/services/receipt_printer_service.dart';
import 'package:wburger_pos/data/models/order_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a bounded raw text order ticket with the receipt layout', () {
    final receipt = ReceiptData(
      ticketNumber: 'W-020526-101',
      orderId: '42',
      soldAt: DateTime(2026, 5, 2, 12, 7),
      lines: const [
        ReceiptLine(name: 'Classic Burger', quantity: 2, unitPrice: 12.5),
        ReceiptLine(
          name: 'Fries',
          quantity: 1,
          unitPrice: 4.5,
          note: 'No salt',
        ),
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      sourceLabel: 'POS sale',
      cashierName: 'staff',
      subtotal: 29.5,
      discountAmount: 0,
      totalAmount: 29.5,
      amountGiven: 30,
      changeReturned: 0.5,
    );

    final bytes = ReceiptPrinterService.instance.buildTicketBytes(receipt);
    final printableText = String.fromCharCodes(
      bytes.where((byte) => byte >= 32 && byte <= 126),
    );

    expect(bytes, isNotEmpty);
    expect(bytes.take(2).toList(), equals([0x1b, 0x40]));
    expect(printableText, contains('BURGER'));
    expect(printableText, contains('A win in every bite'));
    expect(printableText, contains('[]  []  []'));
    expect(printableText, contains('101'));
    expect(printableText, isNot(contains('W-020526-101')));
    expect(printableText, contains('QTY'));
    expect(printableText, contains('ARTICLE'));
    expect(printableText, contains('PRICE'));
    expect(printableText, contains('Classic Burger'));
    expect(printableText, contains('25.000'));
    expect(printableText, contains('Total:'));
    expect(printableText, contains('THANK YOU'));
    expect(_containsBytes(bytes, const [0x0d, 0x0a]), isTrue);
    expect(bytes.skip(bytes.length - 3).toList(), [0x1d, 0x56, 0x00]);
  });

  test('builds a browser preview version of the sample ticket', () {
    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData.sampleTestReceipt(),
      config: const ReceiptPrinterConfig.mm80(
        phone: '+216 XX XXX XXX',
        taxId: '1234567/A/M/000',
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(preview, contains('BURGER'));
    expect(preview, contains('A win in every bite'));
    expect(preview, contains('Tel: +216 XX XXX XXX'));
    expect(preview, contains('101'));
    expect(preview, contains('QTY'));
    expect(preview, contains('ARTICLE'));
    expect(preview, contains('PRICE'));
    expect(
        preview, contains('QTY                ARTICLE                 PRICE'));
    expect(
      preview,
      contains('  2     Double Cheeseburger               24.000'),
    );
    expect(preview, contains('Double Cheeseburger'));
    expect(preview, contains('Crispy Chicken Burger'));
    expect(preview, contains('Total:'));
    expect(preview, contains('48.000'));
    expect(preview, isNot(contains('Remise:')));
    expect(preview, isNot(contains('TVA:')));
    expect(preview, isNot(contains('Payment pending')));
    expect(preview, contains('THANK YOU!'));
    expect(preview, contains('See you soon'));
    expect(preview, isNot(contains('Printed:')));
  });

  test('wraps cleanly for 58mm paper', () {
    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData(
        ticketNumber: 'T-58',
        orderId: 'ORD-58',
        soldAt: DateTime(2026, 5, 2, 18, 42),
        lines: const [
          ReceiptLine(
            name: 'Very Long Signature Double Cheeseburger With Loaded Fries',
            quantity: 2,
            unitPrice: 12.5,
            modifiers: [
              ReceiptModifier(label: 'No onions'),
              ReceiptModifier(label: 'Extra cheddar', price: 2),
            ],
            note: 'Cut in half and sauce on side',
          ),
        ],
        orderType: OrderType.takeaway,
        paymentType: PaymentType.cash,
        sourceLabel: 'POS sale',
        subtotal: 27,
        discountAmount: 0,
        totalAmount: 27,
      ),
      config: const ReceiptPrinterConfig.mm58(printLogo: false),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    final lines = preview.split('\n');
    expect(lines.every((line) => line.length <= 32), isTrue);
    expect(preview, contains('Very Long Signature'));
    expect(preview, contains('Loaded Fries'));
  });

  test('can include the configured logo as ESC/POS raster bytes', () async {
    final bytes = await ReceiptPrinterService.instance.buildReceiptTicketBytes(
      ReceiptData.sampleTestReceipt(),
      config: const ReceiptPrinterConfig.mm58(
        printLogo: true,
        useEscPosFormatting: true,
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(bytes, isNotEmpty);
    expect(_containsBytes(bytes, const [0x1d, 0x76, 0x30, 0x00]), isTrue);
    expect(_countBytes(bytes, const [0x1d, 0x76, 0x30, 0x00]),
        greaterThanOrEqualTo(3));
    expect(bytes.skip(bytes.length - 3).toList(), [0x1d, 0x56, 0x00]);
  });

  test('places the brand checker strip directly below the subtitle', () {
    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData.sampleTestReceipt(),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );
    final lines = preview.split('\n');
    final subtitleIndex =
        lines.indexWhere((line) => line.trim() == 'A win in every bite');

    expect(subtitleIndex, greaterThanOrEqualTo(0));
    expect(lines[subtitleIndex + 1], isEmpty);
    expect(lines[subtitleIndex + 2].trimLeft(), startsWith('[]'));
    expect(lines[subtitleIndex + 3], contains('[]'));
    expect(lines[subtitleIndex + 4].trimLeft(), startsWith('[]'));
    expect(lines[subtitleIndex + 2].length, 48);
    expect(lines[subtitleIndex + 3].length, 48);
    expect(lines[subtitleIndex + 4].length, 48);
    expect(lines[subtitleIndex + 2], isNot(contains('---')));
  });

  test('prints remise only when a discount exists', () {
    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData(
        ticketNumber: 'W-020526-102',
        soldAt: DateTime(2026, 5, 2, 18, 42),
        lines: const [
          ReceiptLine(name: 'Classic Burger', quantity: 1, unitPrice: 12),
        ],
        orderType: OrderType.takeaway,
        sourceLabel: 'POS sale',
        subtotal: 12,
        discountAmount: 2,
        totalAmount: 10,
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(preview, contains('102'));
    expect(preview, isNot(contains('W-020526-102')));
    expect(preview, contains('Remise:'));
    expect(preview, contains('-2.000'));
    expect(preview, isNot(contains('Discount:')));
  });

  test('prints cart item discounts on the receipt', () {
    final product = Product(
      id: 'burger-1',
      categoryId: 'burgers',
      name: 'Classic Burger',
      description: '',
      price: 12,
    );
    final item = CartItem(
      product: product,
      quantity: 2,
      discountPercent: 25,
    );

    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData(
        ticketNumber: 'W-020526-103',
        soldAt: DateTime(2026, 5, 2, 18, 42),
        lines: [ReceiptLine.fromCartItem(item)],
        orderType: OrderType.takeaway,
        sourceLabel: 'POS sale',
        subtotal: item.originalTotal,
        discountAmount: item.discountAmount,
        totalAmount: item.total,
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(preview, contains('Classic Burger'));
    expect(preview, contains('24.000'));
    expect(preview, contains('- Discount 25%'));
    expect(preview, contains('-6.000'));
    expect(preview, contains('Remise:'));
    expect(preview, contains('18.000'));
  });

  test('cart item json can preserve original price for order-level discount',
      () {
    final item = CartItem(
      product: Product(
        id: 'burger-1',
        categoryId: 'burgers',
        name: 'Classic Burger',
        description: '',
        price: 12,
      ),
      quantity: 2,
      discountPercent: 25,
    );

    expect(item.originalTotal, 24);
    expect(item.discountAmount, 6);
    expect(item.total, 18);
    expect(item.toJson('1')['unit_price'], '9.000');
    expect(
      item.toJson('1', includeItemDiscount: false)['unit_price'],
      '12.000',
    );
  });

  test('prints selected sauces one per receipt line', () {
    final item = CartItem(
      product: Product(
        id: 'burger-1',
        categoryId: 'burgers',
        name: 'Classic Burger',
        description: '',
        price: 12,
      ),
      sauces: const [
        CartSauceSelection(stockItemId: '11', name: 'Ketchup'),
        CartSauceSelection(stockItemId: '12', name: 'Mayo'),
      ],
    );

    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData(
        ticketNumber: 'W-020526-104',
        soldAt: DateTime(2026, 5, 2, 18, 42),
        lines: [ReceiptLine.fromCartItem(item)],
        orderType: OrderType.takeaway,
        sourceLabel: 'POS sale',
        subtotal: item.originalTotal,
        discountAmount: 0,
        totalAmount: item.total,
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(preview, contains('- Sauce: Ketchup'));
    expect(preview, contains('- Sauce: Mayo'));
  });

  test('prints cashier note newlines as separate receipt lines', () {
    final item = CartItem(
      product: Product(
        id: 'burger-1',
        categoryId: 'burgers',
        name: 'Classic Burger',
        description: '',
        price: 12,
      ),
      note: 'No onions\nExtra crispy\r\nSauce on side',
    );

    final preview = ReceiptPrinterService.instance.buildPreviewText(
      ReceiptData(
        ticketNumber: 'W-020526-105',
        soldAt: DateTime(2026, 5, 2, 18, 42),
        lines: [ReceiptLine.fromCartItem(item)],
        orderType: OrderType.takeaway,
        sourceLabel: 'POS sale',
        subtotal: item.originalTotal,
        discountAmount: 0,
        totalAmount: item.total,
      ),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );

    expect(preview, contains('- No onions'));
    expect(preview, contains('- Extra crispy'));
    expect(preview, contains('- Sauce on side'));
    expect(preview, isNot(contains('No onions Extra crispy')));
  });

  test('reprint receipt keeps subtotal, discount, and total consistent', () {
    final item = CartItem(
      product: Product(
        id: 'burger-1',
        categoryId: 'burgers',
        name: 'Classic Burger',
        description: '',
        price: 12,
      ),
      quantity: 2,
      discountPercent: 25,
    );
    final receipt = ReceiptData.fromOrder(
      Order(
        id: '1',
        ticketNumber: 'W-020526-104',
        createdAt: DateTime(2026, 5, 2, 18, 42),
        items: [item],
        orderType: OrderType.takeaway,
        totalAmount: 18,
        discountAmount: 6,
        hasBackendTotal: true,
      ),
      isReprint: true,
    );

    expect(receipt.subtotal, 24);
    expect(receipt.discountAmount, 6);
    expect(receipt.totalAmount, 18);
  });

  test('deal component rows stay visible for preparation without double charge',
      () {
    final order = Order.fromJson({
      'id': 501,
      'ticket_number': 'W-260526-501',
      'created_at': '2026-05-26T18:30:00Z',
      'service_type': 'takeaway',
      'payment_type': 'deal',
      'status': 'confirmed',
      'total_amount': '0.000',
      'discount_amount': '0.000',
      'redemption_token': 'qr-token',
      'items': [
        {
          'id': 1,
          'quantity': 1,
          'unit_price': '0.000',
          'is_deal_component': false,
          'deal_details': {
            'id': 10,
            'title': 'Multi Day Burger Pack',
            'description': '5 burgers pack',
            'price': '55.000',
          },
        },
        {
          'id': 2,
          'parent_item': 1,
          'quantity': 2,
          'unit_price': '0.000',
          'note': 'No onions',
          'is_deal_component': true,
          'parent_deal_details': {
            'id': 10,
            'title': 'Multi Day Burger Pack',
          },
          'product_details': {
            'id': 7,
            'name': 'Classic Burger',
            'description': '',
            'price': '11.000',
          },
        },
      ],
    });

    expect(order.items, hasLength(2));
    expect(order.items.first.product.name, 'Multi Day Burger Pack');
    expect(order.items.first.total, 0);
    expect(order.items.last.product.name, 'Classic Burger');
    expect(order.items.last.quantity, 2);
    expect(order.items.last.isDealComponent, isTrue);
    expect(order.items.last.parentDealName, 'Multi Day Burger Pack');
    expect(order.items.last.total, 0);

    final receipt = ReceiptData.fromOrder(order);
    expect(receipt.subtotal, 0);
    expect(receipt.totalAmount, 0);
    expect(receipt.lines, hasLength(1));
    expect(receipt.lines.single.name, 'Multi Day Burger Pack');
    expect(receipt.lines.single.components, hasLength(1));
    expect(receipt.lines.single.components.single.name, 'Classic Burger');
    expect(receipt.lines.single.components.single.quantity, 2);
    expect(receipt.lines.single.components.single.note, 'No onions');

    final preview = ReceiptPrinterService.instance.buildPreviewText(
      receipt,
      printedAt: DateTime(2026, 5, 26, 19, 30),
    );

    expect(preview, contains('Multi Day Burger Pack'));
    expect(preview, contains('- 2x Classic Burger'));
    expect(preview, contains('No onions'));
    expect(preview, isNot(contains('Note:')));
    expect(preview, isNot(contains('Deal item')));
    final packLine = preview
        .split('\n')
        .firstWhere((line) => line.contains('Multi Day Burger Pack'));
    expect(packLine.trimLeft(), isNot(startsWith('1')));
  });

  test('builds a conservative hardware smoke test without logo raster bytes',
      () {
    final bytes = ReceiptTicketBuilder.buildSmokeTestBytes(
      const ReceiptPrinterConfig.mm58(),
      printedAt: DateTime(2026, 5, 2, 18, 42),
    );
    final printableText = String.fromCharCodes(
      bytes.where((byte) => byte >= 32 && byte <= 126),
    );

    expect(printableText, contains('W BURGER PRINTER TEST'));
    expect(printableText, contains('TEXT OK'));
    expect(_containsBytes(bytes, const [0x1d, 0x76, 0x30, 0x00]), isFalse);
    expect(bytes.skip(bytes.length - 3).toList(), [0x1d, 0x56, 0x00]);
  });

  test('builds a bounded cash drawer pulse without feed or cut bytes', () {
    final bytes = ReceiptPrinterService.instance.buildCashDrawerPulseBytes();

    expect(bytes.take(2).toList(), [0x1b, 0x40]);
    expect(_containsBytes(bytes, const [0x1b, 0x70, 0x00]), isTrue);
    expect(_containsBytes(bytes, const [0x1b, 0x70, 0x01]), isTrue);
    expect(_containsBytes(bytes, const [0x07]), isTrue);
    expect(bytes.length, lessThanOrEqualTo(32));
    expect(_containsBytes(bytes, const [0x0a]), isFalse);
    expect(_containsBytes(bytes, const [0x0d]), isFalse);
    expect(_containsBytes(bytes, const [0x1d, 0x56]), isFalse);
  });

  test('can combine a sample receipt with the cash drawer pulse', () async {
    final bytes = await ReceiptPrinterService.instance.buildReceiptTicketBytes(
      ReceiptData.sampleTestReceipt(),
      openDrawer: true,
    );
    final printableText = String.fromCharCodes(
      bytes.where((byte) => byte >= 32 && byte <= 126),
    );

    expect(_containsBytes(bytes, const [0x1b, 0x70, 0x00]), isTrue);
    expect(_containsBytes(bytes, const [0x1b, 0x70, 0x01]), isTrue);
    expect(
      _indexOfBytes(bytes, 'Double Cheeseburger'.codeUnits),
      lessThan(_indexOfBytes(bytes, const [0x1b, 0x70, 0x00])),
    );
    expect(printableText, contains('Double Cheeseburger'));
    expect(printableText, contains('Total:'));
  });

  test('opens the cash drawer automatically only for cash receipts', () {
    final service = ReceiptPrinterService.instance;
    final sampleReceipt = ReceiptData.sampleTestReceipt();
    final cashReceipt = ReceiptData(
      ticketNumber: 'W-020526-104',
      soldAt: DateTime(2026, 5, 2, 18, 42),
      lines: const [
        ReceiptLine(name: 'Classic Burger', quantity: 1, unitPrice: 12),
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.cash,
      sourceLabel: 'POS sale',
      subtotal: 12,
      discountAmount: 0,
      totalAmount: 12,
    );
    final cardReceipt = ReceiptData(
      ticketNumber: 'W-020526-105',
      soldAt: DateTime(2026, 5, 2, 18, 42),
      lines: const [
        ReceiptLine(name: 'Classic Burger', quantity: 1, unitPrice: 12),
      ],
      orderType: OrderType.takeaway,
      paymentType: PaymentType.card,
      sourceLabel: 'POS sale',
      subtotal: 12,
      discountAmount: 0,
      totalAmount: 12,
    );

    expect(service.shouldOpenDrawerForReceipt(sampleReceipt), isFalse);
    expect(service.shouldOpenDrawerForReceipt(cashReceipt), isTrue);
    expect(service.shouldOpenDrawerForReceipt(cardReceipt), isFalse);
    expect(
      service.shouldOpenDrawerForReceipt(
        cardReceipt,
        explicitOpenDrawer: true,
      ),
      isTrue,
    );
  });

  test('tracks partial multi-printer delivery separately from full success',
      () {
    const result = ReceiptPrintResult(
      printerCount: 2,
      printedCount: 1,
      failedPrinters: ['KitchenPrinter (offline)'],
    );

    expect(result.sentToAnyPrinter, isTrue);
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('Ticket queued on 1 of 2 printers'));
  });

  test('can consume expected drawer openings after a hardware pulse', () {
    final service = ReceiptPrinterService.instance;

    service.markDrawerOpenExpected(window: const Duration(seconds: 1));

    expect(service.consumeExpectedDrawerOpen(), isTrue);
    expect(service.consumeExpectedDrawerOpen(), isFalse);
  });

  test('prefers explicit success messages for non-native web print flows', () {
    const result = ReceiptPrintResult(
      printerCount: 1,
      printedCount: 1,
      successMessage:
          'Opened the browser print dialog for web testing. Use the dialog to finish printing.',
    );

    expect(result.isSuccess, isTrue);
    expect(result.message, contains('browser print dialog'));
  });
}

bool _containsBytes(List<int> bytes, List<int> pattern) {
  return _indexOfBytes(bytes, pattern) >= 0;
}

int _indexOfBytes(List<int> bytes, List<int> pattern) {
  for (var index = 0; index <= bytes.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (bytes[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  return -1;
}

int _countBytes(List<int> bytes, List<int> pattern) {
  var count = 0;
  for (var index = 0; index <= bytes.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (bytes[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) count++;
  }
  return count;
}
