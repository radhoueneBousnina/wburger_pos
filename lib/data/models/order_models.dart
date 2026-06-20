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

class PosSettings {
  final double staffDiscountPercent;

  const PosSettings({
    this.staffDiscountPercent = 0,
  });

  factory PosSettings.fromJson(Map<String, dynamic> json) {
    final percent = _parseNullableDouble(json['staff_discount_percent']) ?? 0;
    return PosSettings(
      staffDiscountPercent: percent.clamp(0, 100).toDouble(),
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

class ProductSauceOption {
  final String stockItemId;
  final String name;
  final String unit;
  final double quantityRequired;
  final String? productId;
  final String? productName;

  const ProductSauceOption({
    required this.stockItemId,
    required this.name,
    required this.unit,
    required this.quantityRequired,
    this.productId,
    this.productName,
  });

  factory ProductSauceOption.fromRecipeJson(
    Map<String, dynamic> json, {
    String? productId,
    String? productName,
  }) {
    final stockDetails = _asStringKeyMap(json['stock_item_details']);
    final stockItemId = _firstNonEmptyString([
          json['stock_item'],
          json['stock_item_id'],
          stockDetails?['id'],
        ]) ??
        '';
    final stockName = _firstNonEmptyString([
          json['name'],
          json['stock_item_name'],
          stockDetails?['name'],
        ]) ??
        'Sauce';

    return ProductSauceOption(
      stockItemId: stockItemId,
      name: stockName,
      unit: _firstNonEmptyString([json['unit'], stockDetails?['unit']]) ?? '',
      quantityRequired:
          _parseNullableDouble(json['quantity_required'] ?? json['quantity']) ??
              0,
      productId: productId,
      productName: productName,
    );
  }

  CartSauceSelection toSelection({
    String? productId,
    String? productName,
    double quantityMultiplier = 1,
  }) {
    return CartSauceSelection(
      stockItemId: stockItemId,
      name: name,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityRequired: quantityRequired * quantityMultiplier,
    );
  }
}

class MealComponent {
  final String productId;
  final String name;
  final int quantity;
  final List<ProductSauceOption> sauceOptions;

  const MealComponent({
    required this.productId,
    required this.name,
    required this.quantity,
    this.sauceOptions = const [],
  });

  factory MealComponent.fromJson(Map<String, dynamic> json) {
    final productMap = _asStringKeyMap(json['product']);
    final productId = _firstNonEmptyString([
          json['product_id'],
          json['product'],
          productMap?['id'],
        ]) ??
        '';
    final name = _firstNonEmptyString([
          json['name'],
          json['product_name'],
          productMap?['name'],
        ]) ??
        'Product';

    return MealComponent(
      productId: productId,
      name: name,
      quantity: _parseInt(json['quantity'], fallback: 1),
      sauceOptions: _parseRecipeSauceOptions(
        productMap?['recipe'],
        productId: productId,
        productName: name,
      ),
    );
  }

  MealComponent copyWith({
    List<ProductSauceOption>? sauceOptions,
  }) {
    return MealComponent(
      productId: productId,
      name: name,
      quantity: quantity,
      sauceOptions: sauceOptions ?? this.sauceOptions,
    );
  }
}

class CartSauceSelection {
  final String stockItemId;
  final String name;
  final String? productId;
  final String? productName;
  final double quantityRequired;

  const CartSauceSelection({
    required this.stockItemId,
    required this.name,
    this.productId,
    this.productName,
    this.quantityRequired = 0,
  });

  String displayLabel({bool includeProduct = false}) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Sauce';
    final cleanProduct = productName?.trim();
    if (includeProduct && cleanProduct != null && cleanProduct.isNotEmpty) {
      return '$cleanProduct: $cleanName';
    }
    return cleanName;
  }

  Map<String, dynamic> toJson() {
    return {
      'stock_item': stockItemId,
      'name': name,
      if (productId != null && productId!.isNotEmpty) 'product_id': productId,
      if (productName != null && productName!.isNotEmpty)
        'product_name': productName,
      if (quantityRequired > 0)
        'quantity_required': quantityRequired.toStringAsFixed(3),
    };
  }

  factory CartSauceSelection.fromJson(Map<String, dynamic> json) {
    final stockDetails = _asStringKeyMap(json['stock_item_details']);
    return CartSauceSelection(
      stockItemId: _firstNonEmptyString([
            json['stock_item'],
            json['stock_item_id'],
            json['id'],
            stockDetails?['id'],
          ]) ??
          '',
      name: _firstNonEmptyString([
            json['name'],
            json['label'],
            json['stock_item_name'],
            stockDetails?['name'],
          ]) ??
          'Sauce',
      productId: _firstNonEmptyString([json['product_id'], json['product']]),
      productName: _firstNonEmptyString([
        json['product_name'],
        json['product_label'],
      ]),
      quantityRequired:
          _parseNullableDouble(json['quantity_required'] ?? json['quantity']) ??
              0,
    );
  }

  static List<CartSauceSelection> listFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((json) => CartSauceSelection.fromJson(
              Map<String, dynamic>.from(json),
            ))
        .where((sauce) => sauce.stockItemId.isNotEmpty || sauce.name.isNotEmpty)
        .toList();
  }

  static bool sameList(
    List<CartSauceSelection> left,
    List<CartSauceSelection> right,
  ) {
    if (left.length != right.length) return false;
    final leftKeys = left.map((sauce) => sauce._signature).toList()..sort();
    final rightKeys = right.map((sauce) => sauce._signature).toList()..sort();
    for (var index = 0; index < leftKeys.length; index++) {
      if (leftKeys[index] != rightKeys[index]) return false;
    }
    return true;
  }

  String get _signature =>
      '${productId ?? ''}|$stockItemId|${quantityRequired.toStringAsFixed(3)}';
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
  final List<ProductSauceOption> sauceOptions;
  final List<MealComponent> mealComponents;

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
    this.sauceOptions = const [],
    this.mealComponents = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    final categoryValue = json['category'];
    final categoryId = categoryValue is Map<String, dynamic>
        ? categoryValue['id']?.toString()
        : categoryValue is Map
            ? categoryValue['id']?.toString()
            : json['category_id']?.toString();
    final name = json['name'] as String? ?? 'Unknown';

    return Product(
      id: id,
      categoryId: categoryId ?? '',
      name: name,
      description: json['description'] as String? ?? '',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      imageUrl: ApiConstants.resolveImageUrl(json['image'] as String?),
      pointsPrice: json['points_price'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      isMeal: false,
      sauceOptions: _parseRecipeSauceOptions(
        json['recipe'],
        productId: id,
        productName: name,
      ),
    );
  }

  // Helper factory to map Meal backend to Product frontend model
  factory Product.fromMealJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? const [];
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
      mealComponents: items
          .whereType<Map>()
          .map((item) => MealComponent.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.productId.isNotEmpty)
          .toList(),
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
    List<ProductSauceOption>? sauceOptions,
    List<MealComponent>? mealComponents,
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
      sauceOptions: sauceOptions ?? this.sauceOptions,
      mealComponents: mealComponents ?? this.mealComponents,
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
  final String? lineId;
  final String? parentLineId;
  final Product product;
  int quantity;
  String? note;
  double? discountPercent;
  final bool isDealComponent;
  final String? parentDealName;
  final List<CartSauceSelection> sauces;

  CartItem({
    this.lineId,
    this.parentLineId,
    required this.product,
    this.quantity = 1,
    this.note,
    this.discountPercent,
    this.isDealComponent = false,
    this.parentDealName,
    this.sauces = const [],
  });

  double get unitPrice => isDealComponent
      ? 0
      : discountPercent != null
          ? product.price * (1 - discountPercent! / 100)
          : product.price;

  double get total => unitPrice * quantity;

  double get originalTotal => isDealComponent ? 0 : product.price * quantity;

  double get discountAmount {
    final discount = originalTotal - total;
    return discount > 0 ? discount : 0;
  }

  List<String> get sauceDisplayLines => sauces
      .map((sauce) => sauce.displayLabel(includeProduct: product.isMeal))
      .toList();

  CartItem copyWith({
    String? lineId,
    String? parentLineId,
    Product? product,
    int? quantity,
    String? note,
    double? discountPercent,
    bool? isDealComponent,
    String? parentDealName,
    List<CartSauceSelection>? sauces,
  }) {
    return CartItem(
      lineId: lineId ?? this.lineId,
      parentLineId: parentLineId ?? this.parentLineId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      discountPercent: discountPercent ?? this.discountPercent,
      isDealComponent: isDealComponent ?? this.isDealComponent,
      parentDealName: parentDealName ?? this.parentDealName,
      sauces: sauces ?? this.sauces,
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
      if (sauces.isNotEmpty)
        'selected_sauces': sauces.map((sauce) => sauce.toJson()).toList(),
    };
  }
}

class CartItemGroup {
  final int itemIndex;
  final CartItem item;
  final List<CartItem> components;

  const CartItemGroup({
    required this.itemIndex,
    required this.item,
    this.components = const [],
  });
}

List<CartItemGroup> groupCartItemsForDisplay(List<CartItem> items) {
  final rootIndexes = <int>[];
  final componentsByRootIndex = <int, List<CartItem>>{};
  final rootIndexByLineId = <String, int>{};

  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    if (item.isDealComponent) continue;

    rootIndexes.add(index);
    final lineId = item.lineId;
    if (lineId != null && lineId.isNotEmpty) {
      rootIndexByLineId[lineId] = index;
    }
  }

  final standaloneComponentIndexes = <int>[];
  for (var index = 0; index < items.length; index++) {
    final component = items[index];
    if (!component.isDealComponent) continue;

    final rootIndex = _rootIndexForComponent(
      component,
      index,
      items,
      rootIndexes,
      rootIndexByLineId,
    );
    if (rootIndex == null) {
      standaloneComponentIndexes.add(index);
      continue;
    }

    componentsByRootIndex.putIfAbsent(rootIndex, () => []).add(component);
  }

  final groups = <CartItemGroup>[
    for (final index in rootIndexes)
      CartItemGroup(
        itemIndex: index,
        item: items[index],
        components: componentsByRootIndex[index] ?? const [],
      ),
    for (final index in standaloneComponentIndexes)
      CartItemGroup(itemIndex: index, item: items[index]),
  ];

  groups.sort((a, b) => a.itemIndex.compareTo(b.itemIndex));
  return groups;
}

int displayQuantityForCartItems(List<CartItem> items) {
  return groupCartItemsForDisplay(items).fold<int>(0, (sum, group) {
    if (group.components.isEmpty) return sum + group.item.quantity;
    return sum +
        group.components.fold<int>(
          0,
          (componentSum, component) => componentSum + component.quantity,
        );
  });
}

int? _rootIndexForComponent(
  CartItem component,
  int componentIndex,
  List<CartItem> items,
  List<int> rootIndexes,
  Map<String, int> rootIndexByLineId,
) {
  final parentLineId = component.parentLineId;
  if (parentLineId != null && parentLineId.isNotEmpty) {
    final rootIndex = rootIndexByLineId[parentLineId];
    if (rootIndex != null) return rootIndex;
  }

  final parentName = component.parentDealName?.trim().toLowerCase();
  if (parentName != null && parentName.isNotEmpty) {
    for (final rootIndex in rootIndexes.reversed) {
      final root = items[rootIndex];
      if (rootIndex > componentIndex) continue;
      if (root.product.name.trim().toLowerCase() == parentName) {
        return rootIndex;
      }
    }
  }

  for (final rootIndex in rootIndexes.reversed) {
    if (rootIndex < componentIndex) return rootIndex;
  }
  return rootIndexes.isEmpty ? null : rootIndexes.last;
}

enum OrderType { dineIn, takeaway, glovo }

enum PaymentType { cash, card, glovo, staff, gift, other, points, deal }

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
  final String? giftRecipient;
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
    this.giftRecipient,
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
    String? giftRecipient,
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
      giftRecipient: giftRecipient ?? this.giftRecipient,
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
    if (json['payment_type'] == 'glovo' || json['service_type'] == 'delivery') {
      parsedType = OrderType.glovo;
    } else if (json['service_type'] == 'takeaway') {
      parsedType = OrderType.takeaway;
    }

    PaymentType? parsedPayment;
    final String? pt = json['payment_type'];
    if (pt == 'cash') {
      parsedPayment = PaymentType.cash;
    } else if (pt == 'card') {
      parsedPayment = PaymentType.card;
    } else if (pt == 'glovo') {
      parsedPayment = PaymentType.glovo;
    } else if (pt == 'points') {
      parsedPayment = PaymentType.points;
    } else if (pt == 'deal') {
      parsedPayment = PaymentType.deal;
    } else if (pt == 'staff') {
      parsedPayment = PaymentType.staff;
    } else if (pt == 'gift') {
      parsedPayment = PaymentType.gift;
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
        final itemMap = _asStringKeyMap(itemJson);
        if (itemMap == null) continue;

        final isDealComponent = itemMap['is_deal_component'] == true;
        final pDetails = _asStringKeyMap(itemMap['product_details']);
        final mDetails = _asStringKeyMap(itemMap['meal_details']);
        final dDetails = _asStringKeyMap(itemMap['deal_details']);
        final unitPrice =
            double.tryParse((itemMap['unit_price'] ?? '0').toString()) ?? 0.0;

        Product? product;
        if (pDetails != null) {
          product = Product.fromJson(pDetails);
        } else if (mDetails != null) {
          product = Product.fromMealJson(mDetails);
        } else if (dDetails != null) {
          product = Product.fromDealJson(dDetails, unitPrice: unitPrice);
        }

        if (product != null) {
          final parentDealDetails =
              _asStringKeyMap(itemMap['parent_deal_details']) ??
                  _asStringKeyMap(itemMap['deal_parent_details']) ??
                  dDetails;
          final parentDealName = _firstNonEmptyString([
            itemMap['parent_deal_title'],
            itemMap['deal_title'],
            parentDealDetails?['title'],
            parentDealDetails?['name'],
          ]);

          product = product.copyWith(price: isDealComponent ? 0 : unitPrice);
          parsedItems.add(CartItem(
            lineId: itemMap['id']?.toString(),
            parentLineId: itemMap['parent_item']?.toString(),
            product: product,
            quantity: _parseInt(itemMap['quantity'], fallback: 1),
            note: itemMap['note']?.toString(),
            discountPercent: null, // Deals compute total instead
            isDealComponent: isDealComponent,
            parentDealName: isDealComponent ? parentDealName : null,
            sauces: CartSauceSelection.listFromJson(
              itemMap['selected_sauces'],
            ),
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
      giftRecipient: json['gift_recipient']?.toString(),
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

List<ProductSauceOption> _parseRecipeSauceOptions(
  Object? recipe, {
  String? productId,
  String? productName,
}) {
  final recipeMap = _asStringKeyMap(recipe);
  final rawItems = recipeMap?['items'];
  if (rawItems is! List) return const [];

  return rawItems
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) {
        final stockDetails = _asStringKeyMap(item['stock_item_details']);
        return item['is_sauce'] == true || stockDetails?['is_sauce'] == true;
      })
      .map((item) => ProductSauceOption.fromRecipeJson(
            item,
            productId: productId,
            productName: productName,
          ))
      .where((option) => option.stockItemId.isNotEmpty)
      .toList();
}

Map<String, dynamic>? _asStringKeyMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _parseInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _parseNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String displayTicketNumberFrom(String ticketNumber) {
  final clean = ticketNumber.trim();
  if (clean.isEmpty) return clean;
  final parts = clean.split('-').where((part) => part.trim().isNotEmpty);
  if (parts.isEmpty) return clean;
  return parts.last.trim();
}
