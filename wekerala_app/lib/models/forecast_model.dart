import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-product demand forecast, computed nightly by the `computeForecasts`
/// Cloud Function and stored at `shops/{shopId}/forecasts/{productId}`.
/// Kept in a separate subcollection so product edits never overwrite it.
class ForecastModel {
  final String productId;

  /// Predicted units sold per day (recency-weighted; Croston rate for
  /// intermittent items).
  final double dailyDemand;

  /// Days of stock remaining at the current demand rate. `null` when there is
  /// no measurable demand (can't run out).
  final double? daysCover;

  /// Suggested units to order now to reach the shop's target days of cover.
  final int recommendedQty;

  /// 'high' | 'medium' | 'low' — based on how much sales history backs it.
  final String confidence;

  final DateTime updatedAt;

  const ForecastModel({
    required this.productId,
    required this.dailyDemand,
    required this.daysCover,
    required this.recommendedQty,
    required this.confidence,
    required this.updatedAt,
  });

  bool get hasDemand => dailyDemand > 0;

  factory ForecastModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final cover = (d['daysCover'] as num?)?.toDouble();
    return ForecastModel(
      productId: d['productId'] as String? ?? doc.id,
      dailyDemand: (d['dailyDemand'] as num?)?.toDouble() ?? 0,
      daysCover: (cover != null && cover >= 0) ? cover : null,
      recommendedQty: (d['recommendedQty'] as num?)?.toInt() ?? 0,
      confidence: d['confidence'] as String? ?? 'low',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
