import '../../core/network/api_constants.dart';

class StockItem {
  final String id;
  final String name;
  final String unit; // kg, g, pcs, l
  final double quantity;
  final double minThreshold;
  final double purchasePrice;
  final double basePrice;

  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minThreshold,
    required this.purchasePrice,
    required this.basePrice,
  });

  bool get isLowStock => quantity <= minThreshold;
  bool get isCritical => quantity <= minThreshold * 0.5;

  StockItem copyWith({double? quantity}) {
    return StockItem(
      id: id,
      name: name,
      unit: unit,
      quantity: quantity ?? this.quantity,
      minThreshold: minThreshold,
      purchasePrice: purchasePrice,
      basePrice: basePrice,
    );
  }

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown',
      unit: json['unit'] as String? ?? 'piece',
      quantity:
          double.tryParse(json['current_stock_quantity']?.toString() ?? '0') ??
              0.0,
      minThreshold:
          double.tryParse(json['minimum_threshold']?.toString() ?? '0') ?? 0.0,
      purchasePrice:
          double.tryParse(json['base_price']?.toString() ?? '0') ?? 0.0,
      basePrice: double.tryParse(json['base_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class PurchaseLine {
  final StockItem stockItem;
  double quantity;
  double purchasePrice;

  PurchaseLine({
    required this.stockItem,
    required this.quantity,
    required this.purchasePrice,
  });

  double get lineTotal => quantity * purchasePrice;

  factory PurchaseLine.fromJson(Map<String, dynamic> json) {
    return PurchaseLine(
      stockItem: StockItem.fromJson(json['stock_item_details'] ?? {}),
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      purchasePrice:
          double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

enum PurchaseStatus { pending, validated, cancelled }

class Purchase {
  final String id;
  final DateTime createdAt;
  final List<PurchaseLine> lines;
  final String? invoiceImagePath;
  final PurchaseStatus status;
  final String? validatedBy;
  final double totalAmount;

  const Purchase({
    required this.id,
    required this.createdAt,
    required this.lines,
    this.invoiceImagePath,
    this.status = PurchaseStatus.pending,
    this.validatedBy,
    this.totalAmount = 0.0,
  });

  double get total => totalAmount > 0
      ? totalAmount
      : lines.fold(0, (sum, l) => sum + l.lineTotal);

  factory Purchase.fromJson(Map<String, dynamic> json) {
    PurchaseStatus pStatus = PurchaseStatus.pending;
    final st = json['status'];
    if (st == 'confirmed' || st == 'validated') {
      pStatus = PurchaseStatus.validated;
    } else if (st == 'cancelled') {
      pStatus = PurchaseStatus.cancelled;
    }

    final linesJson = json['lines'] as List<dynamic>? ?? [];
    return Purchase(
      id: json['id'].toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      lines: linesJson.map((l) => PurchaseLine.fromJson(l)).toList(),
      invoiceImagePath:
          ApiConstants.resolveImageUrl(json['invoice_image'] as String?),
      status: pStatus,
      validatedBy:
          json['user_details']?['first_name'] ?? json['user']?.toString(),
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
    );
  }
}
