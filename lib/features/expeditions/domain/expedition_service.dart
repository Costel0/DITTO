import 'expedition.dart';
import 'expedition_review.dart';

abstract interface class ExpeditionService {
  Future<ExpeditionLauncherInfo> fetchLauncherInfo();

  Future<List<ExpeditionReview>> fetchPendingReviews();

  Future<ExpeditionReview> reviewExpeditionResult(String reviewId);

  Future<void> startExpedition({
    required List<String> survivorIds,
    required ExpeditionCoordinates coordinates,
    required List<String> actionIds,
  });
}
