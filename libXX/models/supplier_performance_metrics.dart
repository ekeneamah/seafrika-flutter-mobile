class SupplierPerformanceMetrics {
  final int totalOrders;
  final double onTimeDeliveryRate;
  final double averageRating;
  final double totalSpent;

  SupplierPerformanceMetrics({
    required this.totalOrders,
    required this.onTimeDeliveryRate,
    required this.averageRating,
    required this.totalSpent,
  });

  factory SupplierPerformanceMetrics.fromMap(Map<String, dynamic> map) {
    return SupplierPerformanceMetrics(
      totalOrders: map['totalOrders'] ?? 0,
      onTimeDeliveryRate: (map['onTimeDeliveryRate'] ?? 0.0).toDouble(),
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalSpent: (map['totalSpent'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrders': totalOrders,
      'onTimeDeliveryRate': onTimeDeliveryRate,
      'averageRating': averageRating,
      'totalSpent': totalSpent,
    };
  }
}
