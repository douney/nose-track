import 'package:app_permissions/app_permissions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('permission checks work without requesting access', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('Vérification des autorisations')),
      ),
    );
    const permissions = AppPermissions();
    for (final permission in AppPermission.values) {
      final status = await permissions.check(permission);
      expect(
        status == AppPermissionStatus.unsupported,
        !permissions.isSupported,
      );
    }
    final service = await permissions.checkLocationService();
    expect(
      service == AppLocationServiceStatus.unsupported,
      !permissions.isSupported,
    );
    if (!permissions.isSupported) {
      expect(
        await permissions.request(AppPermission.notifications),
        AppPermissionStatus.unsupported,
      );
      expect(await permissions.openSettings(), isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
