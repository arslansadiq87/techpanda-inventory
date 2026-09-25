import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tech_panda_inventory/core/api_client.dart';
import 'package:tech_panda_inventory/main.dart';

class ProjectWorkflowApi extends ApiClient {
  final component = <String, dynamic>{
    'id': 'component-1',
    'inventory_code': 'RES-000001',
    'name': 'Inline Resistor',
    'category_id': 'category-1',
    'manufacturer': 'Generic',
    'package_type': 'Resistor',
    'current_quantity': '10.0000',
    'minimum_quantity': '0.0000',
    'unit': 'Pieces',
    'location_id': null,
    'location_name': 'Parts Room',
    'primary_image_thumbnail': null,
    'primary_image_preview': null,
    'is_favorite': false,
    'is_archived': false,
    'can_delete': false,
    'created_at': '2026-07-20T00:00:00Z',
    'updated_at': '2026-07-20T00:00:00Z',
  };

  List<Map<String, dynamic>> lastSavedLines = [];
  List<dynamic> savedProjectComponents = [];
  Map<String, dynamic>? lastUpdatedMovement;
  String projectDescription = 'Initial project notes';
  int projectComponentRequests = 0;
  int movementDetailRequests = 0;
  bool movementDeleted = false;

  @override
  Future<bool> restoreSession() async => true;

  @override
  Future<Map<String, dynamic>> dashboard() async => {
    'total_component_types': 1,
    'total_products': 1,
    'total_stock_quantity': '10',
    'low_stock_count': 0,
    'out_of_stock_count': 0,
    'component_type_stock': [
      {
        'name': 'Resistor',
        'product_count': 1,
        'stock_quantity': '10',
        'icon_svg':
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M2 12h20"/></svg>',
      },
    ],
  };

  @override
  Future<List<dynamic>> categories() async => [
    {'id': 'category-1', 'name': 'Resistors'},
  ];

  @override
  Future<List<dynamic>> componentTypes() async => [
    {'id': 'type-1', 'name': 'Resistor'},
  ];

  @override
  Future<List<dynamic>> locations() async => [];

  @override
  Future<List<dynamic>> suppliers() async => [];

  @override
  Future<List<dynamic>> transactions() async => movementDeleted
      ? []
      : [
          {
            'id': 'movement-1',
            'transaction_code': 'TX-00000001',
            'transaction_type': 'stock_out',
            'status': 'posted',
            'project_id': null,
            'can_modify': true,
            'line_count': 1,
            'total_quantity': '2.0000',
            'created_at': '2026-07-20T00:00:00Z',
          },
        ];

  @override
  Future<List<dynamic>> projects() async => [
    {
      'id': 'project-1',
      'name': 'Inline Project',
      'project_type': 'Personal Project',
      'status': 'Planned',
      'description': projectDescription,
      'image_url': null,
      'is_archived': false,
      'created_at': '2026-07-20T00:00:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> updateProject(
    String id,
    Map<String, dynamic> payload,
  ) async {
    projectDescription = payload['description'] as String? ?? '';
    return {
      'id': id,
      'name': 'Inline Project',
      'project_type': 'Personal Project',
      'status': 'Planned',
      'description': projectDescription,
      'image_url': null,
      'is_archived': false,
      'created_at': '2026-07-20T00:00:00Z',
    };
  }

  @override
  Future<List<dynamic>> components({String query = '', int limit = 500}) async {
    return [component];
  }

  @override
  Future<List<dynamic>> projectComponents(String projectId) async {
    projectComponentRequests += 1;
    return savedProjectComponents;
  }

  @override
  Future<List<dynamic>> replaceProjectComponents(
    String projectId,
    List<Map<String, dynamic>> lines,
  ) async {
    lastSavedLines = lines;
    savedProjectComponents = lines
        .map(
          (line) => {
            'id': 'project-component-1',
            'project_id': projectId,
            'component_id': component['id'],
            'quantity': line['quantity'],
            'unit': component['unit'],
            'notes': null,
            'inventory_code': component['inventory_code'],
            'component_name': component['name'],
            'package_type': component['package_type'],
            'manufacturer': component['manufacturer'],
            'location_name': component['location_name'],
            'available_quantity': '8.0000',
            'primary_image_thumbnail': null,
          },
        )
        .toList();
    return savedProjectComponents;
  }

  @override
  Future<Map<String, dynamic>> transaction(String id) async {
    movementDetailRequests += 1;
    return {
      'id': id,
      'transaction_code': 'TX-00000001',
      'transaction_type': 'stock_out',
      'status': 'posted',
      'project_id': null,
      'can_modify': true,
      'line_count': 1,
      'total_quantity': '2.0000',
      'created_at': '2026-07-20T00:00:00Z',
      'reason': 'Workshop build',
      'notes': 'Read-only movement details',
      'lines': [
        {
          'component_id': component['id'],
          'quantity': '2.0000',
          'unit': component['unit'],
          'line_notes': 'Use matched pair',
          'component_name': component['name'],
          'inventory_code': component['inventory_code'],
          'package_type': component['package_type'],
          'manufacturer': component['manufacturer'],
          'location_name': component['location_name'],
          'available_quantity': component['current_quantity'],
          'primary_image_thumbnail': null,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> payload,
  ) async {
    lastUpdatedMovement = payload;
    return transaction(id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    movementDeleted = true;
  }
}

class RejectedStockApi extends ProjectWorkflowApi {
  @override
  Future<Map<String, dynamic>> postTransaction(Map<String, dynamic> payload) {
    throw ApiException(500, 'Database rejected movement');
  }
}

class ComponentEligibilityApi extends ProjectWorkflowApi {
  @override
  Future<List<dynamic>> components({String query = '', int limit = 500}) async {
    return [
      {
        ...component,
        'id': 'protected-component',
        'inventory_code': 'PRT-000001',
        'name': 'Protected Part',
        'can_delete': false,
      },
      {
        ...component,
        'id': 'unused-component',
        'inventory_code': 'NEW-000001',
        'name': 'Unused Part',
        'can_delete': true,
      },
    ];
  }
}

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(TechPandaInventoryApp(api: ApiClient()));
    await tester.pump();
    expect(find.text('Tech Panda Inventory'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('project components use inline search and save all', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final api = ProjectWorkflowApi();

    await tester.pumpWidget(TechPandaInventoryApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inline Project'));
    await tester.pumpAndSettle();

    expect(find.text('Add component to project'), findsNothing);
    expect(
      find.text('Search component to add to this project'),
      findsOneWidget,
    );

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText ==
              'Search component to add to this project',
    );
    await tester.enterText(searchField, 'Inline');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inline Resistor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    await tester.tap(find.text('Save all'));
    await tester.pumpAndSettle();

    expect(api.lastSavedLines, hasLength(1));
    expect(api.lastSavedLines.single['component_id'], 'component-1');
    expect(api.lastSavedLines.single['quantity'], '2');
    expect(find.text('Project components are saved.'), findsOneWidget);
  });

  testWidgets('project description can be saved and project PDF is offered', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final api = ProjectWorkflowApi();

    await tester.pumpWidget(TechPandaInventoryApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('export-project-pdf-project-1')),
      findsOneWidget,
    );
    expect(find.text('Initial project notes'), findsOneWidget);

    await tester.tap(find.text('Inline Project'));
    await tester.pumpAndSettle();
    expect(find.text('Add project image'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('project-description-field')),
      'Updated build notes',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-project-description')));
    await tester.pumpAndSettle();

    expect(api.projectDescription, 'Updated build notes');
    expect(find.text('Project description saved.'), findsOneWidget);
  });

  testWidgets('project list expands components without opening the project', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final api = ProjectWorkflowApi();
    api.savedProjectComponents = [
      {
        'id': 'project-component-1',
        'project_id': 'project-1',
        'component_id': api.component['id'],
        'quantity': '3.0000',
        'unit': api.component['unit'],
        'notes': 'Install on the main board',
        'inventory_code': api.component['inventory_code'],
        'component_name': api.component['name'],
        'package_type': api.component['package_type'],
        'manufacturer': api.component['manufacturer'],
        'location_name': api.component['location_name'],
        'available_quantity': '7.0000',
        'primary_image_thumbnail': null,
      },
    ];

    await tester.pumpWidget(TechPandaInventoryApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('View project components'));
    await tester.tap(find.byTooltip('View project components'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-list-line-project-1-component-1')),
      findsOneWidget,
    );
    expect(find.text('RES-000001 • Inline Resistor'), findsOneWidget);
    expect(find.text('3 Pieces'), findsOneWidget);
    expect(
      find.textContaining('Note: Install on the main board'),
      findsOneWidget,
    );
    expect(find.text('Search component to add to this project'), findsNothing);
    expect(api.projectComponentRequests, 1);

    await tester.tap(find.byTooltip('Hide project components'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View project components'));
    await tester.pumpAndSettle();
    expect(api.projectComponentRequests, 1);
  });

  testWidgets('component view mode is restored after app restart', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to thumbnail view'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to thumbnail view'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('component_view_mode'), 'Thumbnails');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to list view'), findsOneWidget);
  });

  testWidgets('project thumbnail view is persisted after app restart', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch projects to thumbnail view'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch projects to thumbnail view'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('project-thumbnail-project-1')),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('project_view_mode'), 'Thumbnails');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch projects to list view'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('project-thumbnail-project-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile navigation keeps four tabs and moves utilities to drawer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

      await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
      await tester.pumpAndSettle();

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.destinations, hasLength(4));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Components'), findsOneWidget);
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.byTooltip('Logout'), findsNothing);

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Dark mode'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(4),
      );
    },
  );

  testWidgets('dark mode can be enabled and is persisted', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-token',
      'dark_mode': false,
    });

    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isTrue);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Number of products'), findsOneWidget);
    expect(find.text('Low stock'), findsNothing);
    final metricTile = tester.widget<Container>(
      find.byKey(const ValueKey('metric-icon-Component types')),
    );
    final metricDecoration = metricTile.decoration! as BoxDecoration;
    expect(metricDecoration.color!.a, closeTo(0.30, 0.01));
    expect(metricDecoration.border, isNotNull);

    final typeTile = tester.widget<Container>(
      find.byKey(const ValueKey('component-type-icon-Resistor')),
    );
    final typeDecoration = typeTile.decoration! as BoxDecoration;
    expect(typeDecoration.color!.a, closeTo(0.30, 0.01));
    expect(typeDecoration.border, isNotNull);
  });

  testWidgets('reports page offers separate CSV and PDF exports', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

    await tester.pumpWidget(TechPandaInventoryApp(api: ProjectWorkflowApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('CSV inventory export'), findsOneWidget);
    expect(find.text('PDF inventory export'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-csv')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-pdf')), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('stock movement can be edited and deleted as a whole', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final api = ProjectWorkflowApi();

    await tester.pumpWidget(TechPandaInventoryApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit entire movement'));
    await tester.pumpAndSettle();
    expect(find.text('Editing TX-00000001'), findsOneWidget);
    expect(find.text('Update entire movement'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase quantity').first);
    await tester.pump();
    await tester.tap(find.text('Update entire movement'));
    await tester.pumpAndSettle();

    expect(api.lastUpdatedMovement, isNotNull);
    final updatedLines = api.lastUpdatedMovement!['lines'] as List<dynamic>;
    final updatedLine = Map<String, dynamic>.from(updatedLines.single as Map);
    expect(updatedLine['quantity'], '3');

    await tester.tap(find.byTooltip('Delete entire movement'));
    await tester.pumpAndSettle();
    expect(find.text('Delete entire stock movement?'), findsOneWidget);
    await tester.tap(find.text('Delete movement'));
    await tester.pumpAndSettle();
    expect(api.movementDeleted, isTrue);
    expect(find.text('TX-00000001 stock_out'), findsNothing);
  });

  testWidgets('recent movement expands component lines without editing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    final api = ProjectWorkflowApi();

    await tester.pumpWidget(TechPandaInventoryApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('movement-line-movement-1-component-1')),
      findsNothing,
    );
    await tester.ensureVisible(find.byTooltip('View movement components'));
    await tester.tap(find.byTooltip('View movement components'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('movement-line-movement-1-component-1')),
      findsOneWidget,
    );
    expect(find.text('RES-000001 • Inline Resistor'), findsOneWidget);
    expect(find.text('2 Pieces'), findsOneWidget);
    expect(
      find.text('Reason: Workshop build\nNotes: Read-only movement details'),
      findsOneWidget,
    );
    expect(find.textContaining('Note: Use matched pair'), findsOneWidget);
    expect(find.text('Editing TX-00000001'), findsNothing);
    expect(api.movementDetailRequests, 1);

    await tester.tap(find.byTooltip('Hide movement components'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('movement-line-movement-1-component-1')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('View movement components'));
    await tester.pumpAndSettle();
    expect(api.movementDetailRequests, 1);
  });

  testWidgets('delete is hidden for components with transaction history', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

    await tester.pumpWidget(
      TechPandaInventoryApp(api: ComponentEligibilityApi()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Components'));
    await tester.pumpAndSettle();

    final protectedTile = find.ancestor(
      of: find.text('Protected Part'),
      matching: find.byType(ListTile),
    );
    final unusedTile = find.ancestor(
      of: find.text('Unused Part'),
      matching: find.byType(ListTile),
    );

    expect(protectedTile, findsOneWidget);
    expect(
      find.descendant(
        of: protectedTile,
        matching: find.byTooltip('Delete component'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: protectedTile,
        matching: find.byTooltip('Edit component'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: unusedTile,
        matching: find.byTooltip('Delete component'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stock rejection is shown without draft actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});

    await tester.pumpWidget(TechPandaInventoryApp(api: RejectedStockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Search component to add',
    );
    await tester.enterText(searchField, 'Inline');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inline Resistor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Database rejected movement'), findsOneWidget);
    expect(find.text('Save draft'), findsNothing);
    expect(find.textContaining('Sync drafts'), findsNothing);
    expect(find.text('Inline Resistor'), findsOneWidget);
  });
}
