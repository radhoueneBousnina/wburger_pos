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
  final double mealAddOnPrice;

  const PosSettings({
    this.staffDiscountPercent = 0,
    this.mealAddOnPrice = 0,
  });

  factory PosSettings.fromJson(Map<String, dynamic> json) {
    final percent = _parseNullableDouble(json['staff_discount_percent']) ?? 0;
    final mealAddOn = _parseNullableDouble(json['meal_add_on_price']) ?? 0;
    return PosSettings(
      staffDiscountPercent: percent.clamp(0, 100).toDouble(),
      mealAddOnPrice: mealAddOn < 0 ? 0 : mealAddOn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_discount_percent': staffDiscountPercent,
      'meal_add_on_price': mealAddOnPrice,
    };
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

  Map<String, dynamic> toLocalJson() {
    return {
      'stock_item_id': stockItemId,
      'name': name,
      'unit': unit,
      'quantity_required': quantityRequired,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
    };
  }

  factory ProductSauceOption.fromLocalJson(Map<String, dynamic> json) {
    return ProductSauceOption(
      stockItemId: json['stock_item_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sauce',
      unit: json['unit']?.toString() ?? '',
      quantityRequired: _parseNullableDouble(json['quantity_required']) ?? 0,
      productId: _firstNonEmptyString([json['product_id']]),
      productName: _firstNonEmptyString([json['product_name']]),
    );
  }
}

class MealComponent {
  final String productId;
  final String name;
  final int quantity;
  final bool hasSauces;
  final List<ProductSauceOption> sauceOptions;

  const MealComponent({
    required this.productId,
    required this.name,
    required this.quantity,
    this.hasSauces = false,
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
      hasSauces:
          productMap?['has_sauces'] == true || json['has_sauces'] == true,
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
      hasSauces: hasSauces,
      sauceOptions: sauceOptions ?? this.sauceOptions,
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'product_id': productId,
      'name': name,
      'quantity': quantity,
      'has_sauces': hasSauces,
      'sauce_options':
          sauceOptions.map((option) => option.toLocalJson()).toList(),
    };
  }

  factory MealComponent.fromLocalJson(Map<String, dynamic> json) {
    return MealComponent(
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Product',
      quantity: _parseInt(json['quantity'], fallback: 1),
      hasSauces: json['has_sauces'] == true,
      sauceOptions: (json['sauce_options'] as List? ?? const [])
          .whereType<Map>()
          .map((option) => ProductSauceOption.fromLocalJson(
                Map<String, dynamic>.from(option),
              ))
          .toList(),
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
      if (quantityRequired > 0) 'quantity': quantityRequired.toStringAsFixed(3),
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
  final bool canBeMeal;
  final bool hasSauces;
  final bool isSoda;
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
    this.canBeMeal = false,
    this.hasSauces = false,
    this.isSoda = false,
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
      canBeMeal: json['can_be_meal'] == true,
      hasSauces: json['has_sauces'] == true,
      isSoda: json['is_soda'] == true,
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
      canBeMeal: false,
      hasSauces: false,
      isSoda: false,
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
    bool? canBeMeal,
    bool? hasSauces,
    bool? isSoda,
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
      canBeMeal: canBeMeal ?? this.canBeMeal,
      hasSauces: hasSauces ?? this.hasSauces,
      isSoda: isSoda ?? this.isSoda,
      sauceOptions: sauceOptions ?? this.sauceOptions,
      mealComponents: mealComponents ?? this.mealComponents,
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      if (imageAsset != null) 'image_asset': imageAsset,
      if (imageUrl != null) 'image_url': imageUrl,
      if (pointsPrice != null) 'points_price': pointsPrice,
      'is_active': isActive,
      'is_meal': isMeal,
      'can_be_meal': canBeMeal,
      'has_sauces': hasSauces,
      'is_soda': isSoda,
      'sauce_options':
          sauceOptions.map((option) => option.toLocalJson()).toList(),
      'meal_components':
          mealComponents.map((component) => component.toLocalJson()).toList(),
    };
  }

  factory Product.fromLocalJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      description: json['description']?.toString() ?? '',
      price: _parseNullableDouble(json['price']) ?? 0,
      imageAsset: _firstNonEmptyString([json['image_asset']]),
      imageUrl: _firstNonEmptyString([json['image_url']]),
      pointsPrice: json['points_price'] is int
          ? json['points_price'] as int
          : int.tryParse(json['points_price']?.toString() ?? ''),
      isActive: json['is_active'] != false,
      isMeal: json['is_meal'] == true,
      canBeMeal: json['can_be_meal'] == true,
      hasSauces: json['has_sauces'] == true,
      isSoda: json['is_soda'] == true,
      sauceOptions: (json['sauce_options'] as List? ?? const [])
          .whereType<Map>()
          .map((option) => ProductSauceOption.fromLocalJson(
                Map<String, dynamic>.from(option),
              ))
          .toList(),
      mealComponents: (json['meal_components'] as List? ?? const [])
          .whereType<Map>()
          .map((component) => MealComponent.fromLocalJson(
                Map<String, dynamic>.from(component),
              ))
          .toList(),
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
      canBeMeal: false,
      isSoda: false,
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
  final bool isMealUpgrade;
  final double mealAddOnPrice;
  final Product? mealSodaProduct;

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
    this.isMealUpgrade = false,
    this.mealAddOnPrice = 0,
    this.mealSodaProduct,
  });

  double get configuredUnitPrice =>
      product.price + (isMealUpgrade ? mealAddOnPrice : 0);

  double get unitPrice => isDealComponent
      ? 0
      : discountPercent != null
          ? configuredUnitPrice * (1 - discountPercent! / 100)
          : configuredUnitPrice;

  double get total => unitPrice * quantity;

  double get originalTotal =>
      isDealComponent ? 0 : configuredUnitPrice * quantity;

  double get discountAmount {
    final discount = originalTotal - total;
    return discount > 0 ? discount : 0;
  }

  List<String> get sauceDisplayLines => sauces
      .map((sauce) => sauce.displayLabel(includeProduct: product.isMeal))
      .toList();

  String get displayName =>
      isMealUpgrade ? '${product.name} - Meal' : product.name;

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
    bool? isMealUpgrade,
    double? mealAddOnPrice,
    Product? mealSodaProduct,
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
      isMealUpgrade: isMealUpgrade ?? this.isMealUpgrade,
      mealAddOnPrice: mealAddOnPrice ?? this.mealAddOnPrice,
      mealSodaProduct: mealSodaProduct ?? this.mealSodaProduct,
    );
  }

  // Maps to backend format for POST /api/v1/sales/orders/add_item/
  Map<String, dynamic> toJson(
    String orderId, {
    bool includeItemDiscount = true,
    String? clientLineId,
  }) {
    return {
      'order': orderId,
      if (clientLineId != null && clientLineId.isNotEmpty)
        'client_line_id': clientLineId,
      if (product.isMeal) 'meal': product.id else 'product': product.id,
      'quantity': quantity,
      'unit_price': (includeItemDiscount ? unitPrice : configuredUnitPrice)
          .toStringAsFixed(3),
      if (note != null && note!.isNotEmpty) 'note': note,
      if (sauces.isNotEmpty)
        'selected_sauces': sauces.map((sauce) => sauce.toJson()).toList(),
      if (isMealUpgrade) ...{
        'is_meal_upgrade': true,
        'meal_add_on_price': mealAddOnPrice.toStringAsFixed(3),
        if (mealSodaProduct != null) 'meal_soda': mealSodaProduct!.id,
      },
    };
  }

  Map<String, dynamic> toLocalJson() {
    return {
      if (lineId != null) 'line_id': lineId,
      if (parentLineId != null) 'parent_line_id': parentLineId,
      'product': product.toLocalJson(),
      'quantity': quantity,
      if (note != null) 'note': note,
      if (discountPercent != null) 'discount_percent': discountPercent,
      'is_deal_component': isDealComponent,
      if (parentDealName != null) 'parent_deal_name': parentDealName,
      'sauces': sauces.map((sauce) => sauce.toJson()).toList(),
      'is_meal_upgrade': isMealUpgrade,
      'meal_add_on_price': mealAddOnPrice,
      if (mealSodaProduct != null)
        'meal_soda_product': mealSodaProduct!.toLocalJson(),
    };
  }

  factory CartItem.fromLocalJson(Map<String, dynamic> json) {
    final productMap = _asStringKeyMap(json['product']);
    final mealSodaMap = _asStringKeyMap(json['meal_soda_product']);
    return CartItem(
      lineId: _firstNonEmptyString([json['line_id']]),
      parentLineId: _firstNonEmptyString([json['parent_line_id']]),
      product: productMap == null
          ? const Product(
              id: '',
              categoryId: '',
              name: 'Unknown',
              description: '',
              price: 0,
            )
          : Product.fromLocalJson(productMap),
      quantity: _parseInt(json['quantity'], fallback: 1),
      note: _firstNonEmptyString([json['note']]),
      discountPercent: _parseNullableDouble(json['discount_percent']),
      isDealComponent: json['is_deal_component'] == true,
      parentDealName: _firstNonEmptyString([json['parent_deal_name']]),
      sauces: CartSauceSelection.listFromJson(json['sauces']),
      isMealUpgrade: json['is_meal_upgrade'] == true,
      mealAddOnPrice: _parseNullableDouble(json['meal_add_on_price']) ?? 0,
      mealSodaProduct:
          mealSodaMap == null ? null : Product.fromLocalJson(mealSodaMap),
    );
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

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((item) => item.toLocalJson()).toList(),
      'order_type': orderType.name,
      if (paymentType != null) 'payment_type': paymentType!.name,
      'status': status.name,
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (customerId != null) 'customer_id': customerId,
      if (customerNote != null) 'customer_note': customerNote,
      if (giftRecipient != null) 'gift_recipient': giftRecipient,
      'is_qr_order': isQrOrder,
      if (redemptionToken != null) 'redemption_token': redemptionToken,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'amount_given': amountGiven,
      'change_returned': changeReturned,
      'has_backend_total': hasBackendTotal,
    };
  }

  factory Order.fromLocalJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      ticketNumber: json['ticket_number']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => CartItem.fromLocalJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      orderType: _orderTypeFromName(json['order_type']?.toString()),
      paymentType: _paymentTypeFromName(json['payment_type']?.toString()),
      status: _orderStatusFromName(json['status']?.toString()),
      cancellationReason: _firstNonEmptyString([json['cancellation_reason']]),
      customerName: _firstNonEmptyString([json['customer_name']]),
      customerPhone: _firstNonEmptyString([json['customer_phone']]),
      customerId: _firstNonEmptyString([json['customer_id']]),
      customerNote: _firstNonEmptyString([json['customer_note']]),
      giftRecipient: _firstNonEmptyString([json['gift_recipient']]),
      isQrOrder: json['is_qr_order'] == true,
      redemptionToken: _firstNonEmptyString([json['redemption_token']]),
      totalAmount: _parseNullableDouble(json['total_amount']) ?? 0,
      discountAmount: _parseNullableDouble(json['discount_amount']) ?? 0,
      amountGiven: _parseNullableDouble(json['amount_given']) ?? 0,
      changeReturned: _parseNullableDouble(json['change_returned']) ?? 0,
      hasBackendTotal: json['has_backend_total'] == true,
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
        final mealSodaDetails = _asStringKeyMap(itemMap['meal_soda_details']);
        final dDetails = _asStringKeyMap(itemMap['deal_details']);
        final unitPrice =
            double.tryParse((itemMap['unit_price'] ?? '0').toString()) ?? 0.0;
        final isMealUpgrade = itemMap['is_meal_upgrade'] == true;
        final mealAddOnPrice =
            _parseNullableDouble(itemMap['meal_add_on_price']) ?? 0;

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

          final parsedMealSoda = mealSodaDetails == null
              ? null
              : Product.fromJson(mealSodaDetails);
          final baseMealPrice = unitPrice - mealAddOnPrice;
          final displayUnitPrice = isMealUpgrade
              ? (baseMealPrice > 0 ? baseMealPrice : 0.0)
              : unitPrice;
          product =
              product.copyWith(price: isDealComponent ? 0 : displayUnitPrice);
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
            isMealUpgrade: isMealUpgrade,
            mealAddOnPrice: mealAddOnPrice,
            mealSodaProduct: parsedMealSoda,
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

OrderType _orderTypeFromName(String? value) {
  switch (value) {
    case 'takeaway':
      return OrderType.takeaway;
    case 'glovo':
      return OrderType.glovo;
    case 'dineIn':
    case 'dine_in':
    default:
      return OrderType.dineIn;
  }
}

PaymentType? _paymentTypeFromName(String? value) {
  switch (value) {
    case 'cash':
      return PaymentType.cash;
    case 'card':
      return PaymentType.card;
    case 'glovo':
      return PaymentType.glovo;
    case 'staff':
      return PaymentType.staff;
    case 'gift':
      return PaymentType.gift;
    case 'other':
      return PaymentType.other;
    case 'points':
      return PaymentType.points;
    case 'deal':
      return PaymentType.deal;
  }
  return null;
}

OrderStatus _orderStatusFromName(String? value) {
  switch (value) {
    case 'validated':
    case 'confirmed':
      return OrderStatus.validated;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'pending':
    default:
      return OrderStatus.pending;
  }
}

String displayTicketNumberFrom(String ticketNumber) {
  final clean = ticketNumber.trim();
  if (clean.isEmpty) return clean;
  final parts = clean.split('-').where((part) => part.trim().isNotEmpty);
  if (parts.isEmpty) return clean;
  return parts.last.trim();
}
