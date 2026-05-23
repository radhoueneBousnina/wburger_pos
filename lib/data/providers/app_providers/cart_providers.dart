part of '../app_providers.dart';

class CartState {
  final List<CartItem> items;
  final OrderType orderType;
  final PaymentType? paymentType;
  final String? redemptionToken;
  final String? customerId;
  final String? customerName;
  final String? customerNote;
  final String? ticketNumber;

  const CartState({
    this.items = const [],
    this.orderType = OrderType.dineIn,
    this.paymentType,
    this.redemptionToken,
    this.customerId,
    this.customerName,
    this.customerNote,
    this.ticketNumber,
  });

  double get originalSubtotal =>
      items.fold(0, (sum, i) => sum + i.originalTotal);
  double get discountAmount =>
      items.fold(0, (sum, i) => sum + i.discountAmount);
  double get subtotal => items.fold(0, (sum, i) => sum + i.total);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isQrOrder => redemptionToken != null && redemptionToken!.isNotEmpty;
  bool get isLockedForQr => isQrOrder;

  CartState copyWith({
    List<CartItem>? items,
    OrderType? orderType,
    PaymentType? paymentType,
    String? redemptionToken,
    String? customerId,
    String? customerName,
    String? customerNote,
    String? ticketNumber,
  }) {
    return CartState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      paymentType: paymentType ?? this.paymentType,
      redemptionToken: redemptionToken ?? this.redemptionToken,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerNote: customerNote ?? this.customerNote,
      ticketNumber: ticketNumber ?? this.ticketNumber,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addProduct(Product product) {
    final items = List<CartItem>.from(state.items);
    final index =
        items.indexWhere((i) => i.product.id == product.id && i.note == null);
    if (index >= 0) {
      items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
    } else {
      items.add(CartItem(product: product));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(int index) {
    final items = [...state.items];
    items.removeAt(index);
    state = state.copyWith(items: items);
  }

  void updateQuantity(int index, int qty) {
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    final items = List<CartItem>.from(state.items);
    items[index] = items[index].copyWith(quantity: qty);
    state = state.copyWith(items: items);
  }

  void updateNote(int index, String? note) {
    final items = [...state.items];
    items[index] = CartItem(
      product: items[index].product,
      quantity: items[index].quantity,
      note: note,
      discountPercent: items[index].discountPercent,
    );
    state = state.copyWith(items: items);
  }

  void updateDiscount(int index, double? percent) {
    final items = [...state.items];
    items[index] = CartItem(
      product: items[index].product,
      quantity: items[index].quantity,
      note: items[index].note,
      discountPercent: percent,
    );
    state = state.copyWith(items: items);
  }

  void setOrderType(OrderType type) {
    state = state.copyWith(orderType: type);
  }

  void loadFromQrOrder(Order qrOrder) {
    state = CartState(
      items: List.from(qrOrder.items),
      orderType: qrOrder.orderType,
      paymentType: qrOrder.paymentType,
      redemptionToken: qrOrder.redemptionToken,
      customerId: qrOrder.customerId,
      customerName: qrOrder.customerName,
      customerNote: qrOrder.customerNote,
      ticketNumber: qrOrder.ticketNumber,
    );
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
