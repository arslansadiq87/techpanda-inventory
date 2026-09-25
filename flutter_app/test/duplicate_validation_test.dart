import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tech_panda_inventory/core/api_client.dart';
import 'package:tech_panda_inventory/core/local_inventory_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalInventoryClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = LocalInventoryClient();
  });

  group('Duplicate validation tests in LocalInventoryClient', () {
    test('Component duplicate validation on create and update', () async {
      final categories = await client.categories();
      final categoryId = (categories.first as Map)['id'] as String;

      final comp1 = await client.createComponent({
        'name': 'Resistor 10k 0805',
        'category_id': categoryId,
        'package_type': 'SMD',
      });
      expect(comp1['name'], 'Resistor 10k 0805');

      // Duplicate case-insensitive create rejected
      expect(
        () => client.createComponent({
          'name': '  resistor 10K 0805  ',
          'category_id': categoryId,
        }),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Self-update succeeds
      await client.updateComponent(comp1['id'] as String, {
        'name': 'Resistor 10k 0805',
        'price': '0.05',
      });

      // Second component
      final comp2 = await client.createComponent({
        'name': 'Capacitor 100uF',
        'category_id': categoryId,
      });

      // Updating comp2 to comp1's name is rejected
      expect(
        () => client.updateComponent(comp2['id'] as String, {
          'name': 'RESISTOR 10K 0805',
        }),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('Component type duplicate validation on create and update', () async {
      final type1 = await client.createComponentType('Sensor Module');
      expect(type1['name'], 'Sensor Module');

      // Duplicate create rejected
      expect(
        () => client.createComponentType('sensor module'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Self-update succeeds
      await client.updateComponentType(type1['id'] as String, 'Sensor Module');

      // Second type
      final type2 = await client.createComponentType('Display Unit');

      // Updating type2 to type1's name rejected
      expect(
        () => client.updateComponentType(
          type2['id'] as String,
          'SENSOR MODULE',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('Location duplicate validation on create and update', () async {
      final loc1 = await client.createLocation({
        'name': 'Bench 1 Shelf A',
        'generate_qr_code': true,
      });
      expect(loc1['name'], 'Bench 1 Shelf A');

      // Duplicate create rejected
      expect(
        () => client.createLocation({'name': 'bench 1 shelf a'}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Self-update succeeds
      await client.updateLocation(loc1['id'] as String, {
        'name': 'Bench 1 Shelf A',
        'description': 'Updated description',
      });

      // Second location
      final loc2 = await client.createLocation({'name': 'Storage Bin B2'});

      // Updating loc2 to loc1's name rejected
      expect(
        () => client.updateLocation(loc2['id'] as String, {
          'name': 'BENCH 1 SHELF A',
        }),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('Supplier CRUD, duplicate validation, and component-supplier association', () async {
      // 1. Create supplier
      final sup1 = await client.createSupplier({
        'name': 'DigiKey',
        'website': 'https://digikey.com',
        'contact': 'support@digikey.com',
        'notes': 'Preferred vendor',
      });
      expect(sup1['name'], 'DigiKey');
      expect(sup1['website'], 'https://digikey.com');

      // 2. Duplicate create rejected (case-insensitive)
      expect(
        () => client.createSupplier({'name': '  digikey  '}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // 3. Second supplier
      final sup2 = await client.createSupplier({'name': 'Mouser'});
      expect(sup2['name'], 'Mouser');

      // 4. Updating sup2 to sup1's name rejected
      expect(
        () => client.updateSupplier(sup2['id'] as String, {'name': 'DIGIKEY'}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // 5. Updating sup1 succeeds
      final updatedSup1 = await client.updateSupplier(sup1['id'] as String, {
        'name': 'DigiKey Electronics',
      });
      expect(updatedSup1['name'], 'DigiKey Electronics');

      // 6. Create component linked to supplier
      final categories = await client.categories();
      final categoryId = (categories.first as Map)['id'] as String;
      final comp = await client.createComponent({
        'name': 'ESP32-WROOM-32E',
        'category_id': categoryId,
        'supplier_id': sup1['id'],
      });
      expect(comp['supplier_id'], sup1['id']);
      expect(comp['supplier_name'], 'DigiKey Electronics');

      // 7. Update component supplier to sup2
      final updatedComp = await client.updateComponent(comp['id'] as String, {
        'supplier_id': sup2['id'],
      });
      expect(updatedComp['supplier_id'], sup2['id']);
      expect(updatedComp['supplier_name'], 'Mouser');

      // 8. Delete supplier
      await client.deleteSupplier(sup2['id'] as String);
      final remainingSuppliers = await client.suppliers();
      expect(remainingSuppliers.any((s) => s['id'] == sup2['id']), isFalse);
    });
  });
}

