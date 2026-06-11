import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/hallaq_images.dart';

class AuthImagePrecache {
  static Future<void> warm(BuildContext context) async {
    final urls = [
      HallaqImages.blackGoldBackground(variant: '01'),
      HallaqImages.luxuryBarberInterior(variant: '01'),
      HallaqImages.professionalBarberPortrait(variant: '01'),
      HallaqImages.premiumGrooming(variant: '01'),
      HallaqImages.fadeHaircut(variant: '01'),
      HallaqImages.beardStyling(variant: '01'),
    ];

    for (final u in urls) {
      try {
        await precacheImage(CachedNetworkImageProvider(u), context);
      } catch (_) {}
    }
  }
}
