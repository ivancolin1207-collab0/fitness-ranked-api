import 'package:apexmetrix_mobile/data/repositories/fitness_repository.dart';
import 'package:apexmetrix_mobile/data/services/api_client_service.dart';
import 'package:apexmetrix_mobile/data/services/health_connect_service.dart';
import 'package:apexmetrix_mobile/data/services/secure_storage_service.dart';
import 'package:apexmetrix_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ApexMetrixApp renders authentication gate when unauthenticated', (
    WidgetTester tester,
  ) async {
    final FitnessRepository repository = FitnessRepository(
      apiClient: ApiClientService(),
      healthConnectService: HealthConnectService(),
      storageService: const SecureStorageService(),
    );

    await tester.pumpWidget(ApexMetrixApp(repository: repository));
    expect(find.byType(ApexMetrixApp), findsOneWidget);
  });
}
