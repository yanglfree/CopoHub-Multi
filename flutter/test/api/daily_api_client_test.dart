import 'package:copohub/api/daily_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeReportPayload unwraps the API envelope', () {
    final result = DailyApiClient.normalizeReportPayload({
      'data': {
        'summary': 'Daily summary',
        'topics': ['Dart'],
      },
    });

    expect(result, containsPair('summary', 'Daily summary'));
    expect(result, isNot(contains('data')));
  });

  test('normalizeReportPayload keeps an already normalized report', () {
    final result = DailyApiClient.normalizeReportPayload({
      'summary': 'Daily summary',
      'topics': ['Dart'],
    });

    expect(result, containsPair('summary', 'Daily summary'));
  });
}
