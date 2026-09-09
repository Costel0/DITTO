import 'expedition.dart';
import 'expedition_review.dart';

abstract interface class ExpeditionService {
  Future<ExpeditionLauncherInfo> fetchLauncherInfo();

  Future<List<ExpeditionReviewSummary>> fetchPendingReviews();

  Future<ExpeditionReview> fetchExpeditionReview(String reviewId);

  Future<ExpeditionResolutionResult> resolveExpeditionReview({
    required String reviewId,
    required Map<String, String> choices,
  });

  Future<void> startExpedition({
    required List<String> survivorIds,
    required ExpeditionCoordinates coordinates,
    required List<String> actionIds,
  });
}
