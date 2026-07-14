/// A pending AI/rules recommendation (ai_recommendations row).
class AiRecommendation {
  final String id;
  final String recommendationType; // REORDER | ...
  final String entityType; // product | ...
  final String entityId;
  final Map<String, dynamic> recommendation;
  final double confidenceScore;
  final String? reasoning;
  final String status;

  const AiRecommendation({
    required this.id,
    required this.recommendationType,
    required this.entityType,
    required this.entityId,
    required this.recommendation,
    required this.confidenceScore,
    this.reasoning,
    required this.status,
  });
}
