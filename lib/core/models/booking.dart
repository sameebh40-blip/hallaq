enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  rescheduled,
  noShow,
  cancelled,
  completed;

  static BookingStatus fromDb(String? value) {
    return switch (value) {
      'confirmed' => BookingStatus.confirmed,
      'accepted' => BookingStatus.confirmed,
      'in_progress' => BookingStatus.inProgress,
      'rescheduled' => BookingStatus.rescheduled,
      'no_show' => BookingStatus.noShow,
      'cancelled' => BookingStatus.cancelled,
      'rejected' => BookingStatus.cancelled,
      'completed' => BookingStatus.completed,
      _ => BookingStatus.pending,
    };
  }

  String toDb() {
    return switch (this) {
      BookingStatus.pending => 'pending',
      BookingStatus.confirmed => 'confirmed',
      BookingStatus.inProgress => 'in_progress',
      BookingStatus.rescheduled => 'rescheduled',
      BookingStatus.noShow => 'no_show',
      BookingStatus.cancelled => 'cancelled',
      BookingStatus.completed => 'completed',
    };
  }
}

class Booking {
  final String id;
  final String customerProfileId;
  final String? barberId;
  final String? shopId;
  final String? serviceId;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final double? totalPrice;
  final double depositRequiredAmount;
  final String? serviceNameEn;
  final String? serviceNameAr;
  final String? barberName;
  final String? shopName;

  const Booking({
    required this.id,
    required this.customerProfileId,
    required this.serviceId,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.barberId,
    this.shopId,
    this.totalPrice,
    this.depositRequiredAmount = 0,
    this.serviceNameEn,
    this.serviceNameAr,
    this.barberName,
    this.shopName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final totalPrice = (json['total_price'] as num?)?.toDouble();
    final depositRequiredAmount = ((json['deposit_required_amount'] as num?) ?? 0).toDouble();
    return Booking(
      id: json['id'] as String,
      customerProfileId: json['customer_profile_id'] as String,
      barberId: json['barber_id'] as String?,
      shopId: json['shop_id'] as String?,
      serviceId: json['service_id'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      status: BookingStatus.fromDb(json['status'] as String?),
      totalPrice: totalPrice,
      depositRequiredAmount: depositRequiredAmount,
      serviceNameEn: json['service_name_en'] as String?,
      serviceNameAr: json['service_name_ar'] as String?,
      barberName: json['barber_name'] as String?,
      shopName: json['shop_name'] as String?,
    );
  }
}
