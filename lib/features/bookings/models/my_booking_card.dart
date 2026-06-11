import '../../../core/models/booking.dart';

enum BookingsTab {
  upcoming,
  pending,
  autoAccepted,
  rescheduled,
  completed,
  cancelled,
  cancelledByBarber,
  cancelledByShop,
  cancelledByClient,
}

enum BookingCancelOrigin { client, barber, shop, unknown }

class MyBookingCard {
  final String id;
  final String? barberId;
  final String? shopId;
  final String? serviceId;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final DateTime? createdAt;
  final DateTime? cancelledAt;
  final String? cancelledByProfileId;
  final DateTime? rescheduledAt;
  final String? rescheduledByProfileId;
  final BookingCancelOrigin cancelOrigin;
  final bool autoAccepted;
  final double? amountBhd;
  final String? serviceNameEn;
  final String? serviceNameAr;
  final String? barberName;
  final String? barberAvatarUrl;
  final bool barberVerified;
  final String? shopName;
  final String? locationText;
  final double? lat;
  final double? lng;
  final String? googleMapsUrl;
  final String? shopPhone;
  final String? shopWhatsApp;
  final String? paymentMethodLabel;

  const MyBookingCard({
    required this.id,
    required this.serviceId,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.createdAt,
    this.cancelledAt,
    this.cancelledByProfileId,
    this.rescheduledAt,
    this.rescheduledByProfileId,
    this.cancelOrigin = BookingCancelOrigin.unknown,
    this.autoAccepted = false,
    this.barberId,
    this.shopId,
    this.amountBhd,
    this.serviceNameEn,
    this.serviceNameAr,
    this.barberName,
    this.barberAvatarUrl,
    this.barberVerified = false,
    this.shopName,
    this.locationText,
    this.lat,
    this.lng,
    this.googleMapsUrl,
    this.shopPhone,
    this.shopWhatsApp,
    this.paymentMethodLabel,
  });
}
