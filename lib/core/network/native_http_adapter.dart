import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native HTTP adapter for Android that delegates HTTP requests to OkHttp
/// via a platform channel, enabling HTTP/2 and HPACK compression.
///
/// On other platforms or in unit test environments without binary messengers,
/// falls back seamlessly to Dio's standard [IOHttpClientAdapter].
class NativeHttpAdapter implements HttpClientAdapter {
  static const MethodChannel _channel = MethodChannel('com.drgodly.app/native_http');
  final HttpClientAdapter _fallback = IOHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Only use on Android devices when Flutter platform channels are available
    if (!Platform.isAndroid) {
      return _fallback.fetch(options, requestStream, cancelFuture);
    }

    Uint8List? bodyBytes;
    if (options.data != null) {
      if (options.data is Uint8List) {
        bodyBytes = options.data as Uint8List;
      } else if (options.data is List<int>) {
        bodyBytes = Uint8List.fromList(options.data as List<int>);
      } else if (options.data is String) {
        bodyBytes = Uint8List.fromList(utf8.encode(options.data as String));
      } else if (options.data is Map || options.data is List) {
        bodyBytes = Uint8List.fromList(utf8.encode(jsonEncode(options.data)));
      }
    } else if (requestStream != null) {
      final builder = BytesBuilder();
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
      bodyBytes = builder.toBytes();
    }

    final headers = <String, String>{};
    options.headers.forEach((k, v) {
      if (v != null) headers[k] = v.toString();
    });

    final url = options.uri.toString();

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('request', {
        'url': url,
        'method': options.method.toUpperCase(),
        'headers': headers,
        'body': bodyBytes,
      });

      if (res == null) {
        throw DioException(
          requestOptions: options,
          error: 'Native HTTP returned null response',
        );
      }

      final statusCode = res['statusCode'] as int? ?? 500;
      final statusMessage = res['statusMessage'] as String?;
      final rawHeaders = res['headers'] as Map<dynamic, dynamic>? ?? {};
      final dataBytes = res['data'] as Uint8List? ?? Uint8List(0);

      final responseHeaders = <String, List<String>>{};
      rawHeaders.forEach((k, v) {
        if (k != null && v is List) {
          responseHeaders[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });

      return ResponseBody(
        Stream.value(dataBytes),
        statusCode,
        statusMessage: statusMessage,
        headers: responseHeaders,
      );
    } on PlatformException catch (pe) {
      throw DioException(
        requestOptions: options,
        error: pe.message,
        type: DioExceptionType.connectionError,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NativeHttpAdapter] Platform channel error: $e, falling back to IOHttpClientAdapter');
      }
      return _fallback.fetch(options, requestStream, cancelFuture);
    }
  }

  @override
  void close({bool force = false}) {
    _fallback.close(force: force);
  }
}
