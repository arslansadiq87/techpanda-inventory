import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tech_panda_inventory/core/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('API defaults to the local backend endpoint', () {
    expect(apiBaseUrl, 'http://127.0.0.1:8000/api/v1');
    expect(Uri.parse(apiBaseUrl).host, '127.0.0.1');
  });

  test(
    'connection errors do not expose an IP address or request URL',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          throw http.ClientException(
            'Connection refused at 127.0.0.1:8000',
            request.url,
          );
        }),
      );

      await expectLater(
        api.login('admin', 'password'),
        throwsA(
          isA<ApiConnectionException>().having(
            (error) => error.toString(),
            'message',
            'Connection failed. Start the local inventory server and try again.',
          ),
        ),
      );
    },
  );

  test('uses the local API directly', () async {
    final requestedUrls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response('{"access_token":"local-token"}', 200);
      }),
    );

    await api.login('admin', 'password');

    expect(api.activeBaseUrl, apiBaseUrl);
    expect(requestedUrls, ['$apiBaseUrl/auth/login']);
  });

  test(
    'downloads authenticated inventory reports with the API filename',
    () async {
      final requestedUrls = <String>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          expect(request.headers['authorization'], 'Bearer report-token');
          expect(request.headers['accept'], 'text/csv');
          return http.Response.bytes(
            utf8.encode('Image URL,Name\r\n,Resistor\r\n'),
            200,
            headers: {
              'content-type': 'text/csv; charset=utf-8',
              'content-disposition': 'attachment; filename=inventory.csv',
            },
          );
        }),
      )..accessToken = 'report-token';

      final report = await api.downloadInventoryReport('CSV');

      expect(report.filename, 'inventory.csv');
      expect(utf8.decode(report.bytes), contains('Resistor'));
      expect(requestedUrls, ['$apiBaseUrl/reports/inventory.csv']);
    },
  );

  test('downloads a project PDF with its API filename', () async {
    final requestedUrls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        expect(request.headers['authorization'], 'Bearer project-token');
        expect(request.headers['accept'], 'application/pdf');
        return http.Response.bytes(
          utf8.encode('%PDF-project'),
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition':
                'attachment; filename=Studio-Light-Build.pdf',
          },
        );
      }),
    )..accessToken = 'project-token';

    final report = await api.downloadProjectReport('project-1');

    expect(report.filename, 'Studio-Light-Build.pdf');
    expect(utf8.decode(report.bytes), '%PDF-project');
    expect(requestedUrls, ['$apiBaseUrl/projects/project-1/report.pdf']);
  });

  test('uploads a project image through the active API endpoint', () async {
    final requestedUrls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer image-token');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        return http.Response(
          jsonEncode({
            'id': 'project-1',
            'name': 'Photo Project',
            'project_type': 'Personal Project',
            'status': 'Planned',
            'description': null,
            'image_url': '/api/v1/media/projects/photo.jpg',
            'is_archived': false,
            'created_at': '2026-07-21T00:00:00Z',
          }),
          200,
        );
      }),
    )..accessToken = 'image-token';

    final project = await api.uploadProjectImage(
      'project-1',
      'project.jpg',
      Uint8List.fromList([1, 2, 3]),
    );

    expect(project['image_url'], '/api/v1/media/projects/photo.jpg');
    expect(requestedUrls, ['$apiBaseUrl/projects/project-1/image']);
  });
}
