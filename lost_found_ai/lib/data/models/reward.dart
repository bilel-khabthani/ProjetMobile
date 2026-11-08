enum CouponStatus {
  active,
  used,
  expired;

  static CouponStatus fromString(String? val) {
    return switch (val?.toUpperCase()) {
      'USED' => CouponStatus.used,
      'EXPIRED' => CouponStatus.expired,
      _ => CouponStatus.active,
    };
  }

  String get label => switch (this) {
        CouponStatus.active => 'Actif',
        CouponStatus.used => 'Utilisé',
        CouponStatus.expired => 'Expiré',
      };
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.partnerType,
    required this.description,
    required this.pointsCost,
    required this.discountText,
    required this.iconName,
    required this.colorHex,
    required this.terms,
  });

  final int id;
  final String title;
  final String partnerName;
  final String partnerType; // DELIVERY, RESTAURANT, CAFE, SHOPPING
  final String description;
  final int pointsCost;
  final String discountText;
  final String iconName;
  final String colorHex;
  final String terms;

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      partnerName: json['partner_name'] as String? ?? 'Partenaire',
      partnerType: json['partner_type'] as String? ?? 'DELIVERY',
      description: json['description'] as String? ?? '',
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      discountText: json['discount_text'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'redeem',
      colorHex: json['color_hex'] as String? ?? '#FF9800',
      terms: json['terms'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'partner_name': partnerName,
        'partner_type': partnerType,
        'description': description,
        'points_cost': pointsCost,
        'discount_text': discountText,
        'icon_name': iconName,
        'color_hex': colorHex,
        'terms': terms,
      };
}

class UserCoupon {
  const UserCoupon({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.partnerType,
    required this.code,
    required this.discountText,
    required this.status,
    required this.source,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
    this.terms,
    this.pdfUrl,
  });

  final String id;
  final String title;
  final String partnerName;
  final String partnerType;
  final String code;
  final String discountText;
  final CouponStatus status;
  final String source; // RESTITUTION, WHEEL_SPIN, POINTS_EXCHANGE
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;
  final String? terms;
  final String? pdfUrl;

  bool get isExpired => DateTime.now().isAfter(expiresAt) && status != CouponStatus.used;
  bool get isValid => status == CouponStatus.active && !isExpired;

  factory UserCoupon.fromJson(Map<String, dynamic> json) {
    return UserCoupon(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      partnerName: json['partner_name'] as String? ?? 'Partenaire',
      partnerType: json['partner_type'] as String? ?? 'DELIVERY',
      code: json['code'] as String? ?? '',
      discountText: json['discount_text'] as String? ?? '',
      status: CouponStatus.fromString(json['status'] as String?),
      source: json['source'] as String? ?? 'RESTITUTION',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      usedAt: json['used_at'] != null ? DateTime.tryParse(json['used_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      terms: json['terms'] as String?,
      pdfUrl: json['pdf_url'] as String?,
    );
  }
}

class WheelPrize {
  const WheelPrize({
    required this.index,
    required this.label,
    required this.type,
    required this.colorHex,
    required this.icon,
    this.points = 0,
    this.couponTitle,
    this.couponCode,
    this.partnerName,
  });

  final int index;
  final String label;
  final String type; // 'POINTS', 'COUPON', 'RETRY'
  final String colorHex;
  final String icon;
  final int points;
  final String? couponTitle;
  final String? couponCode;
  final String? partnerName;

  factory WheelPrize.fromJson(Map<String, dynamic> json) {
    return WheelPrize(
      index: (json['index'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'POINTS',
      colorHex: json['color_hex'] as String? ?? '#4F46E5',
      icon: json['icon'] as String? ?? 'star',
      points: (json['points'] as num?)?.toInt() ?? 0,
      couponTitle: json['coupon_title'] as String?,
      couponCode: json['coupon_code'] as String?,
      partnerName: json['partner_name'] as String?,
    );
  }
}

class SpinResult {
  const SpinResult({
    required this.prizeIndex,
    required this.prize,
    required this.message,
    required this.newBalance,
    this.coupon,
  });

  final int prizeIndex;
  final WheelPrize prize;
  final String message;
  final int newBalance;
  final UserCoupon? coupon;

  factory SpinResult.fromJson(Map<String, dynamic> json) {
    return SpinResult(
      prizeIndex: (json['prize_index'] as num?)?.toInt() ?? 0,
      prize: WheelPrize.fromJson(json['prize'] as Map<String, dynamic>? ?? {}),
      message: json['message'] as String? ?? '',
      newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
      coupon: json['coupon'] != null
          ? UserCoupon.fromJson(json['coupon'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int points;
  final String description;
  final DateTime createdAt;

  factory RewardTransaction.fromJson(Map<String, dynamic> json) {
    return RewardTransaction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class RewardWallet {
  const RewardWallet({
    required this.points,
    required this.canSpinFreeToday,
    required this.spinCost,
    required this.history,
  });

  final int points;
  final bool canSpinFreeToday;
  final int spinCost;
  final List<RewardTransaction> history;

  factory RewardWallet.fromJson(Map<String, dynamic> json) {
    final historyList = (json['history'] as List<dynamic>? ?? const [])
        .map((e) => RewardTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    return RewardWallet(
      points: (json['points'] as num?)?.toInt() ?? 0,
      canSpinFreeToday: json['can_spin_free_today'] as bool? ?? true,
      spinCost: (json['spin_cost'] as num?)?.toInt() ?? 15,
      history: historyList,
    );
  }
}

