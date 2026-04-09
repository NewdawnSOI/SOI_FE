import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soi/api/api_client.dart';
import 'package:soi/api/models/login.dart';
import 'package:soi_api_client/api.dart';

/// HTTP 응답 시나리오를 코드로 주입해 refresh/retry 분기를 결정적으로 검증합니다.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.onSend);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return onSend(request);
  }
}

http.StreamedResponse _jsonResponse(int statusCode, Object body) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
    contentLength: bytes.length,
  );
}

void main() {
  group('SoiApiClient refresh token handling', () {
    test('retries a protected request after refreshing both tokens', () async {
      var refreshCallCount = 0;
      var protectedCallCount = 0;

      final client = _FakeHttpClient((request) async {
        if (request.url.path == '/protected') {
          protectedCallCount += 1;
          if (protectedCallCount == 1) {
            expect(request.headers['Authorization'], 'Bearer access-1');
            return _jsonResponse(401, <String, dynamic>{'message': 'expired'});
          }

          expect(request.headers['Authorization'], 'Bearer access-2');
          return _jsonResponse(200, <String, dynamic>{'ok': true});
        }

        if (request.url.path == '/auth/refresh') {
          refreshCallCount += 1;
          final body =
              jsonDecode((request as http.Request).body)
                  as Map<String, dynamic>;
          expect(body['refreshToken'], 'refresh-1');
          expect(request.headers.containsKey('Authorization'), isFalse);
          return _jsonResponse(200, <String, dynamic>{
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'accessTokenExpiresInMs': 1800000,
            'refreshTokenExpiresInMs': 1209600000,
          });
        }

        fail('Unexpected path: ${request.url.path}');
      });

      SoiApiClient.instance.initialize(
        basePath: 'https://example.com',
        httpClient: client,
      );
      SoiApiClient.instance.setAuthSession(
        LoginSession(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      final response = await SoiApiClient.instance.apiClient.invokeAPI(
        '/protected',
        'GET',
        <QueryParam>[],
        null,
        <String, String>{},
        <String, String>{},
        null,
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body)['ok'], isTrue);
      expect(refreshCallCount, 1);
      expect(protectedCallCount, 2);
      expect(SoiApiClient.instance.authToken, 'access-2');
      expect(
        SoiApiClient.instance.currentAuthSession?.refreshToken,
        'refresh-2',
      );
    });

    test('clears session and notifies listeners when refresh fails', () async {
      var authLossCount = 0;

      final client = _FakeHttpClient((request) async {
        if (request.url.path == '/protected') {
          return _jsonResponse(401, <String, dynamic>{'message': 'expired'});
        }

        if (request.url.path == '/auth/refresh') {
          final body =
              jsonDecode((request as http.Request).body)
                  as Map<String, dynamic>;
          expect(body['refreshToken'], 'refresh-1');
          return _jsonResponse(401, <String, dynamic>{'message': 'invalid'});
        }

        fail('Unexpected path: ${request.url.path}');
      });

      SoiApiClient.instance.initialize(
        basePath: 'https://example.com',
        httpClient: client,
      );
      SoiApiClient.instance.setAuthSession(
        LoginSession(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      void onAuthLoss() {
        authLossCount += 1;
      }

      SoiApiClient.instance.addAuthLossListener(onAuthLoss);

      final response = await SoiApiClient.instance.apiClient.invokeAPI(
        '/protected',
        'GET',
        <QueryParam>[],
        null,
        <String, String>{},
        <String, String>{},
        null,
      );

      expect(response.statusCode, 401);
      expect(SoiApiClient.instance.authToken, isNull);
      expect(SoiApiClient.instance.currentAuthSession, isNull);
      expect(authLossCount, 1);
      SoiApiClient.instance.removeAuthLossListener(onAuthLoss);
    });
  });
}
