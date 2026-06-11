class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final DateTime createdAt;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Order {
  final String id;
  final String customerProfileId;
  final String shopId;
  final String status;
  final double totalAmount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentId;
  final Map<String, dynamic> deliveryAddress;
  final String? customerNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.customerProfileId,
    required this.shopId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.paymentId,
    this.customerNote,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final addr = json['delivery_address'];
    return Order(
      id: json['id'] as String,
      customerProfileId: json['customer_profile_id'] as String,
      shopId: json['shop_id'] as String,
      status: (json['status'] as String?) ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? (json['total'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'BHD',
      paymentMethod: (json['payment_method'] as String?) ?? 'cod',
      paymentStatus: (json['payment_status'] as String?) ?? 'unpaid',
      paymentId: json['payment_id'] as String?,
      deliveryAddress: addr is Map ? Map<String, dynamic>.from(addr) : const <String, dynamic>{},
      customerNote: json['customer_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

