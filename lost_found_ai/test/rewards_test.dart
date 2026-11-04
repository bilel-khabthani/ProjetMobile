import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/models/reward.dart';

void main() {
  group('Module 4 - Rewards Models & Business Logic', () {
    test('Reward deserialization works correctly', () {
      final json = {
        'id': 1,
        'title': 'Livraison Offerte Glovo',
        'partner_name': 'Glovo Express',
        'partner_type': 'DELIVERY',
        'description': 'Livraison gratuite sur tout repas',
        'points_cost': 50,
        'discount_text': 'Livraison 100% Gratuite',
        'icon_name': 'delivery_dining',
        'color_hex': '#FFC244',
        'terms': 'Sans minimum',
      };

      final reward = Reward.fromJson(json);

      expect(reward.id, 1);
      expect(reward.partnerName, 'Glovo Express');
      expect(reward.pointsCost, 50);
      expect(reward.discountText, 'Livraison 100% Gratuite');
    });

    test('UserCoupon validity and expiration checks work', () {
      final activeJson = {
        'id': 'coupon-1',
        'title': 'Livraison Yassir',
        'partner_name': 'Yassir Express',
        'partner_type': 'DELIVERY',
        'code': 'YASSIR-FREE-12',
        'discount_text': 'Course Offerte',
        'status': 'ACTIVE',
        'source': 'RESTITUTION',
        'expires_at': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final coupon = UserCoupon.fromJson(activeJson);
      expect(coupon.status, CouponStatus.active);
      expect(coupon.isExpired, isFalse);
      expect(coupon.isValid, isTrue);

      final expiredJson = {
        ...activeJson,
        'expires_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      };
      final expiredCoupon = UserCoupon.fromJson(expiredJson);
      expect(expiredCoupon.isExpired, isTrue);
      expect(expiredCoupon.isValid, isFalse);
    });

    test('SpinResult and WheelPrize parse correctly', () {
      final json = {
        'prize_index': 0,
        'prize': {
          'index': 0,
          'label': 'Livraison Glovo',
          'type': 'COUPON',
          'color_hex': '#FFC244',
          'icon': 'delivery_dining',
          'points': 0,
          'coupon_code': 'GLOVO-ROUE-9921',
          'partner_name': 'Glovo Express',
        },
        'message': 'Bravo ! Vous avez gagné un coupon Glovo !',
        'new_balance': 180,
      };

      final spinResult = SpinResult.fromJson(json);
      expect(spinResult.prizeIndex, 0);
      expect(spinResult.prize.label, 'Livraison Glovo');
      expect(spinResult.newBalance, 180);
      expect(spinResult.prize.couponCode, 'GLOVO-ROUE-9921');
    });
  });
}

