import '../constants/app_constants.dart';
import '../models/health_evaluation_model.dart';
import 'api_service.dart';

class HealthService {
  static Future<HealthEvaluationResult> evaluateFood({
    required NutrientSnapshot nutrients,
    DateTime? consumedAt,
  }) async {
    final body = {
      'nutrients': nutrients.toJson(),
      if (consumedAt != null)
        'consumed_at': consumedAt.toUtc().toIso8601String(),
    };

    final json = await ApiService.post(
      ApiConstants.healthEvaluateFoodEndpoint,
      body,
      requireAuth: true,
    );

    return HealthEvaluationResult.fromJson(json);
  }

  static Future<DailyHealthSummary> getDailySummary({DateTime? date}) async {
    final queryParams = <String, String>{};
    if (date != null) {
      queryParams['date'] = date.toUtc().toIso8601String().split('T')[0];
    }

    final json = await ApiService.get(
      ApiConstants.healthDailySummaryEndpoint,
      requireAuth: true,
      queryParams: queryParams.isEmpty ? null : queryParams,
    );

    return DailyHealthSummary.fromJson(json);
  }

  static Future<HealthHistory> getHistory({
    DateTime? fromDate,
    DateTime? toDate,
    int days = 14,
  }) async {
    final queryParams = <String, String>{
      'days': days.toString(),
    };

    if (fromDate != null) {
      queryParams['from_date'] =
          fromDate.toUtc().toIso8601String().split('T')[0];
    }
    if (toDate != null) {
      queryParams['to_date'] = toDate.toUtc().toIso8601String().split('T')[0];
    }

    final json = await ApiService.get(
      ApiConstants.healthHistoryEndpoint,
      requireAuth: true,
      queryParams: queryParams,
    );

    return HealthHistory.fromJson(json);
  }
}
