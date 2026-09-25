import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _techPandaLanCa = '''
-----BEGIN CERTIFICATE-----
MIIBpTCCAUqgAwIBAgIRAIMjmcNL36F6vbsXHSDQqTAwCgYIKoZIzj0EAwIwMDEu
MCwGA1UEAxMlQ2FkZHkgTG9jYWwgQXV0aG9yaXR5IC0gMjAyNiBFQ0MgUm9vdDAe
Fw0yNjA3MjAxODA1NThaFw0zNjA1MjgxODA1NThaMDAxLjAsBgNVBAMTJUNhZGR5
IExvY2FsIEF1dGhvcml0eSAtIDIwMjYgRUNDIFJvb3QwWTATBgcqhkjOPQIBBggq
hkjOPQMBBwNCAASwj+Ad4Kd/EKwmnyYvzRLz4NmyWE2fdgjw3l/xOcKusyrVt8iU
EuMPSzfBTUdl4/Pu0ru1g3tEDT3z0LbFbyJ/o0UwQzAOBgNVHQ8BAf8EBAMCAQYw
EgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQU2GgNaICBg8Fvo/SVjjAVQwEW
dsUwCgYIKoZIzj0EAwIDSQAwRgIhAOehfF4t/eiQadc6u18kOi8p9UDUghFa5qS+
1xTSZ8PTAiEAysAvTCZS1njqrcNU0HMbSJWKZEVzlfzlayL/LvWP/FU=
-----END CERTIFICATE-----
''';

http.Client createApiHttpClient() {
  return IOClient(HttpClient(context: _trustedSecurityContext()));
}

void configureSecureHttpOverrides() {
  HttpOverrides.global = _TechPandaHttpOverrides();
}

SecurityContext _trustedSecurityContext([SecurityContext? context]) {
  return (context ?? SecurityContext(withTrustedRoots: true))
    ..setTrustedCertificatesBytes(utf8.encode(_techPandaLanCa));
}

class _TechPandaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(_trustedSecurityContext(context));
  }
}
