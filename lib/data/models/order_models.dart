import '../../core/network/api_constants.dart';

class StaffMember {
  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String role;

  const StaffMember({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  String get fullName {
    if (firstName.isEmpty && lastName.isEmpty) return username;
    return '$firstName $lastName'.trim();
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'].toString(),
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
    );
  }
}

class Category {
  final String id;
  final String name;
  final String? iconEmoji;
  final String? imageUrl;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.iconEmoji,
    this.imageUrl,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'] as String,
      imageUrl: ApiConstants.resolveImageUrl(json['image'] as String?),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class Product {
  final String id;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String? imageAsset;
  final String? imageUrl;
  final int? pointsPrice;
  final bool isActive;
  final bool isMeal;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.imageAsset,
    this.imageUrl,
    this.pointsPrice,
    this.isActive = true,
    this.isMeal = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final categoryValue = json['category'];
    final categoryId = categoryValue is Map<String, dynamic>
        ? categoryValue['id']?.toString()
        : categoryValue is Map
            ? categoryValue['id']?.toString()
            : json['category_id']?.toString();

    return Product(
      id: json['id'].toString(),
      categoryId: categoryId ?? '',
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      imageUrl: ApiConstants.resolveImageUrl(json['image'] as String?),
      pointsPrice: json['points_price'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      isMeal: false,
    );
  }

  // Helper factory to map Meal backend to Product frontend model
  factory Product.fromMealJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      categoryId: 'meals', // We will inject a virtual "Meals" category
      name: json['name'] as String? ?? 'Unknown Meal',
      description: json['description'] as String? ?? '',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      imageUrl: ApiConstants.resolveImageUrl(json['image'] as String?),
      pointsPrice: null, // Meals cannot be bought with points
      isActive: json['is_active'] as bool? ?? true,
      isMeal: true,
    );
  }

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageAsset,
    String? imageUrl,
    int? pointsPrice,
    bool? isActive,
    bool? isMeal,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageAsset: imageAsset ?? this.imageAsset,
      imageUrl: imageUrl ?? this.imageUrl,
      pointsPrice: pointsPrice ?? this.pointsPrice,
      isActive: isActive ?? this.isActive,
      isMeal: isMeal ?? this.isMeal,
    );
  }

  // Helper factory to display deal parent lines imported from mobile QR orders.
  // These cart rows are read-only in POS, so the synthetic category/id are only
  // used for display and do not go back through the manual add-item flow.
  factory Product.fromDealJson(
    Map<String, dynamic> json, {
    double? unitPrice,
  }) {
    return Product(
      id: 'deal-${json['id']}',
      categoryId: 'deals',
      name: json['title'] as String? ?? 'Deal',
      description: json['description'] as String? ?? '',
      price: unitPrice ??
          double.tryParse((json['price'] ?? '0').toString()) ??
          0.0,
      imageUrl: ApiConstants.resolveImageUrl(json['image'] as String?),
      pointsPrice: null,
      isActive: json['is_active'] as bool? ?? true,
      isMeal: false,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  String? note;
  double? discountPercent;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.note,
    this.discountPercent,
  });

  double get unitPrice => discountPercent != null
      ? product.price * (1 - discountPercent! / 100)
      : product.price;

  double get total => unitPrice * quantity;

  double get originalTotal => product.price * quantity;

  double get discountAmount {
    final discount = originalTotal - total;
    return discount > 0 ? discount : 0;
  }

  CartItem copyWith({int? quantity, String? note, double? discountPercent}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  // Maps to backend format for POST /api/v1/sales/orders/add_item/
  Map<String, dynamic> toJson(
    String orderId, {
    bool includeItemDiscount = true,
  }) {
    return {
      'order': orderId,
      if (product.isMeal) 'meal': product.id else 'product': product.id,
      'quantity': quantity,
      'unit_price':
          (includeItemDiscount ? unitPrice : product.price).toStringAsFixed(3),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }
}

enum OrderType { dineIn, takeaway }

enum PaymentType { cash, card, staff, other, points, deal }

enum OrderStatus { pending, validated, cancelled }

class Order {
  final String id;
  final String ticketNumber;
  final DateTime createdAt;
  final List<CartItem> items;
  final OrderType orderType;
  final PaymentType? paymentType;
  final OrderStatus status;
  final String? cancellationReason;
  final String? customerName;
  final String? customerPhone;
  final String? customerId;
  final String? customerNote;
  final bool isQrOrder;
  final String? redemptionToken;
  final double totalAmount; // Actual total from backend calculation
  final double discountAmount;
  final double amountGiven;
  final double changeReturned;
  final bool hasBackendTotal;

  const Order({
    required this.id,
    required this.ticketNumber,
    required this.createdAt,
    required this.items,
    required this.orderType,
    this.paymentType,
    this.status = OrderStatus.pending,
    this.cancellationReason,
    this.customerName,
    this.customerPhone,
    this.customerId,
    this.customerNote,
    this.isQrOrder = false,
    this.redemptionToken,
    this.totalAmount = 0.0,
    this.discountAmount = 0.0,
    this.amountGiven = 0.0,
    this.changeReturned = 0.0,
    this.hasBackendTotal = false,
  });

  // Calculate local total sum when building order
  double get total => hasBackendTotal
      ? totalAmount
      : items.fold(0, (sum, item) => sum + item.total);

  String get displayTicketNumber => displayTicketNumberFrom(ticketNumber);

  Order copyWith({
    OrderStatus? status,
    String? cancellationReason,
    PaymentType? paymentType,
    double? totalAmount,
    double? discountAmount,
    double? amountGiven,
    double? changeReturned,
    List<CartItem>? items,
  }) {
    return Order(
      id: id,
      ticketNumber: ticketNumber,
      createdAt: createdAt,
      items: items ?? this.items,
      orderType: orderType,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      customerName: customerName,
      customerPhone: customerPhone,
      customerId: customerId,
      customerNote: customerNote,
      isQrOrder: isQrOrder,
      redemptionToken: redemptionToken,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      amountGiven: amountGiven ?? this.amountGiven,
      changeReturned: changeReturned ?? this.changeReturned,
      hasBackendTotal: hasBackendTotal,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    OrderType parsedType = OrderType.dineIn;
    if (json['service_type'] == 'takeaway') {
      parsedType = OrderType.takeaway;
    }

    PaymentType? parsedPayment;
    final String? pt = json['payment_type'];
    if (pt == 'cash') {
      parsedPayment = PaymentType.cash;
    } else if (pt == 'card') {
      parsedPayment = PaymentType.card;
    } else if (pt == 'points') {
      parsedPayment = PaymentType.points;
    } else if (pt == 'deal') {
      parsedPayment = PaymentType.deal;
    } else if (pt == 'staff') {
      parsedPayment = PaymentType.staff;
    } else if (pt == 'other') {
      parsedPayment = PaymentType.other;
    }

    OrderStatus parsedStatus = OrderStatus.pending;
    final String st = json['status'] ?? 'pending';
    if (st == 'confirmed' || st == 'validated') {
      parsedStatus = OrderStatus.validated;
    } else if (st == 'cancelled') {
      parsedStatus = OrderStatus.cancelled;
    }

    List<CartItem> parsedItems = [];
    if (json['items'] != null) {
      for (var itemJson in json['items']) {
        // If it's a deal component, we skip showing it individually and rely on parent item,
        // OR we map it to product/meal. For POS display, we map based on what's available.
        final pDetails = itemJson['product_details'];
        final mDetails = itemJson['meal_details'];
        final dDetails = itemJson['deal_details'];
        final unitPrice =
            double.tryParse((itemJson['unit_price'] ?? '0').toString()) ?? 0.0;

        Product? product;
        if (pDetails != null) {
          product = Product.fromJson(pDetails);
        } else if (mDetails != null) {
          product = Product.fromMealJson(mDetails);
        } else if (dDetails != null) {
          product = Product.fromDealJson(dDetails, unitPrice: unitPrice);
        }

        if (product != null && itemJson['is_deal_component'] != true) {
          product = product.copyWith(price: unitPrice);
          parsedItems.add(CartItem(
            product: product,
            quantity: itemJson['quantity'] ?? 1,
            note: itemJson['note'],
            discountPercent: null, // Deals compute total instead
          ));
        }
      }
    }

    final customerDetails = json['customer_details'] as Map?;
    final firstName = customerDetails?['first_name']?.toString().trim() ?? '';
    final lastName = customerDetails?['last_name']?.toString().trim() ?? '';
    final username = customerDetails?['username']?.toString().trim() ?? '';
    final phone = customerDetails?['phone']?.toString().trim();
    final customerDisplayName =
        [firstName, lastName].where((part) => part.isNotEmpty).join(' ').trim();

    return Order(
      id: json['id'].toString(),
      ticketNumber: json['ticket_number'] ?? '',
      createdAt: (json['sale_datetime'] ??
                  json['confirmed_at'] ??
                  json['created_at']) !=
              null
          ? DateTime.tryParse((json['sale_datetime'] ??
                          json['confirmed_at'] ??
                          json['created_at'])
                      .toString())
                  ?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      items: parsedItems,
      orderType: parsedType,
      paymentType: parsedPayment,
      status: parsedStatus,
      cancellationReason: json['cancellation_reason'],
      customerName: customerDisplayName.isNotEmpty
          ? customerDisplayName
          : (username.isNotEmpty ? username : json['customer']?.toString()),
      customerPhone: phone?.isNotEmpty == true ? phone : null,
      customerId: json['customer']?.toString(),
      customerNote: json['customer_note']?.toString(),
      isQrOrder: json['redemption_token'] != null,
      redemptionToken: json['redemption_token'],
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      amountGiven:
          double.tryParse(json['amount_given']?.toString() ?? '0') ?? 0.0,
      changeReturned:
          double.tryParse(json['change_returned']?.toString() ?? '0') ?? 0.0,
      hasBackendTotal: json.containsKey('total_amount'),
    );
  }
}

String displayTicketNumberFrom(String ticketNumber) {
  final clean = ticketNumber.trim();
  if (clean.isEmpty) return clean;
  final parts = clean.split('-').where((part) => part.trim().isNotEmpty);
  if (parts.isEmpty) return clean;
  return parts.last.trim();
}
