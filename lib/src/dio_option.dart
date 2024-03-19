import 'dart:collection';

import 'package:dio/dio.dart';

class DioOptions {
  DioOptions({
    Duration? sendTimeout,
    Duration? receiveTimeout,
    this.extra,
    this.headers,
    this.preserveHeaderCase,
    this.contentType,
    this.validateStatus,
    this.receiveDataWhenStatusError,
    this.followRedirects,
    this.maxRedirects,
    this.persistentConnection,
    this.requestEncoder,
    this.responseDecoder,
    this.listFormat,
  })  : assert(receiveTimeout == null || !receiveTimeout.isNegative),
        _receiveTimeout = receiveTimeout,
        assert(sendTimeout == null || !sendTimeout.isNegative),
        _sendTimeout = sendTimeout;

  /// Create a Option from current instance with merging attributes.
  DioOptions copyWith({
    String? method,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, Object?>? extra,
    Map<String, Object?>? headers,
    bool? preserveHeaderCase,
    ResponseType? responseType,
    String? contentType,
    ValidateStatus? validateStatus,
    bool? receiveDataWhenStatusError,
    bool? followRedirects,
    int? maxRedirects,
    bool? persistentConnection,
    RequestEncoder? requestEncoder,
    ResponseDecoder? responseDecoder,
    ListFormat? listFormat,
  }) {
    Map<String, dynamic>? effectiveHeaders;
    if (headers == null && this.headers != null) {
      effectiveHeaders = caseInsensitiveKeyMap(this.headers!);
    }

    if (headers != null) {
      headers = caseInsensitiveKeyMap(headers);
      assert(
        !(contentType != null &&
            headers.containsKey(Headers.contentTypeHeader)),
        'You cannot set both contentType param and a content-type header',
      );
    }

    Map<String, dynamic>? effectiveExtra;
    if (extra == null && this.extra != null) {
      effectiveExtra = Map.from(this.extra!);
    }

    return DioOptions(
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      extra: extra ?? effectiveExtra,
      headers: headers ?? effectiveHeaders,
      preserveHeaderCase: preserveHeaderCase ?? this.preserveHeaderCase,
      contentType: contentType ?? this.contentType,
      validateStatus: validateStatus ?? this.validateStatus,
      receiveDataWhenStatusError:
          receiveDataWhenStatusError ?? this.receiveDataWhenStatusError,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      persistentConnection: persistentConnection ?? this.persistentConnection,
      requestEncoder: requestEncoder ?? this.requestEncoder,
      responseDecoder: responseDecoder ?? this.responseDecoder,
      listFormat: listFormat ?? this.listFormat,
    );
  }

  RequestOptions compose(
    BaseOptions baseOpt,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    StackTrace? sourceStackTrace,
  }) {
    final query = <String, dynamic>{}..addAll(baseOpt.queryParameters);
    if (queryParameters != null) query.addAll(queryParameters);

    final headers = caseInsensitiveKeyMap(baseOpt.headers);
    if (this.headers != null) {
      headers.addAll(this.headers!);
    }
    if (this.contentType != null) {
      headers[Headers.contentTypeHeader] = this.contentType;
    }
    final String? contentType = headers[Headers.contentTypeHeader] as String;
    final extra = Map<String, dynamic>.from(baseOpt.extra);
    if (this.extra != null) {
      extra.addAll(this.extra!);
    }
    final requestOptions = RequestOptions(
      headers: headers,
      extra: extra,
      baseUrl: baseOpt.baseUrl,
      path: path,
      data: data,
      preserveHeaderCase: preserveHeaderCase ?? baseOpt.preserveHeaderCase,
      sourceStackTrace: sourceStackTrace ?? StackTrace.current,
      connectTimeout: baseOpt.connectTimeout,
      sendTimeout: sendTimeout ?? baseOpt.sendTimeout,
      receiveTimeout: receiveTimeout ?? baseOpt.receiveTimeout,
      validateStatus: validateStatus ?? baseOpt.validateStatus,
      receiveDataWhenStatusError:
          receiveDataWhenStatusError ?? baseOpt.receiveDataWhenStatusError,
      followRedirects: followRedirects ?? baseOpt.followRedirects,
      maxRedirects: maxRedirects ?? baseOpt.maxRedirects,
      persistentConnection:
          persistentConnection ?? baseOpt.persistentConnection,
      queryParameters: query,
      requestEncoder: requestEncoder ?? baseOpt.requestEncoder,
      responseDecoder: responseDecoder ?? baseOpt.responseDecoder,
      listFormat: listFormat ?? baseOpt.listFormat,
      onReceiveProgress: onReceiveProgress,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
      contentType: contentType ?? this.contentType ?? baseOpt.contentType,
    );
    requestOptions.cancelToken?.requestOptions = requestOptions;
    return requestOptions;
  }


  /// HTTP request headers.
  ///
  /// The keys of the header are case-insensitive,
  /// e.g.: `content-type` and `Content-Type` will be treated as the same key.
  Map<String, dynamic>? headers;

  /// Whether the case of header keys should be preserved.
  ///
  /// Defaults to false.
  ///
  /// This option WILL NOT take effect on these circumstances:
  /// - XHR ([HttpRequest]) does not support handling this explicitly.
  /// - The HTTP/2 standard only supports lowercase header keys.
  bool? preserveHeaderCase;

  /// Timeout when sending data.
  ///
  /// Throws the [DioException] with
  /// [DioExceptionType.sendTimeout] type when timed out.
  ///
  /// `null` or `Duration.zero` means no timeout limit.
  Duration? get sendTimeout => _sendTimeout;
  Duration? _sendTimeout;

  set sendTimeout(Duration? value) {
    if (value != null && value.isNegative) {
      throw ArgumentError.value(value, 'sendTimeout', 'should be positive');
    }
    _sendTimeout = value;
  }

  /// Timeout when receiving data.
  ///
  /// The timeout represents:
  ///  - a timeout before the connection is established
  ///    and the first received response bytes.
  ///  - the duration during data transfer of each byte event,
  ///    rather than the total duration of the receiving.
  ///
  /// Throws the [DioException] with
  /// [DioExceptionType.receiveTimeout] type when timed out.
  ///
  /// `null` or `Duration.zero` means no timeout limit.
  Duration? get receiveTimeout => _receiveTimeout;
  Duration? _receiveTimeout;

  set receiveTimeout(Duration? value) {
    if (value != null && value.isNegative) {
      throw ArgumentError.value(value, 'receiveTimeout', 'should be positive');
    }
    _receiveTimeout = value;
  }

  /// The request content-type.
  ///
  /// {@macro dio.interceptors.ImplyContentTypeInterceptor}
  String? contentType;



  /// Defines whether the request is considered to be successful
  /// with the given status code.
  /// The request will be treated as succeed if the callback returns true.
  ValidateStatus? validateStatus;

  /// Whether to retrieve the data if status code indicates a failed request.
  ///
  /// Defaults to true.
  bool? receiveDataWhenStatusError;

  /// An extra map that you can retrieve in [Interceptor], [Transformer]
  /// and [Response.requestOptions].
  ///
  /// The field is designed to be non-identical with [Response.extra].
  Map<String, dynamic>? extra;

  /// See [HttpClientRequest.followRedirects].
  ///
  /// Defaults to true.
  bool? followRedirects;

  /// The maximum number of redirects when [followRedirects] is `true`.
  /// [RedirectException] will be thrown if redirects exceeded the limit.
  ///
  /// Defaults to 5.
  int? maxRedirects;

  /// See [HttpClientRequest.persistentConnection].
  ///
  /// Defaults to true.
  bool? persistentConnection;

  /// The type of a request encoding callback.
  ///
  /// Defaults to [Utf8Encoder].
  RequestEncoder? requestEncoder;

  /// The type of a response decoding callback.
  ///
  /// Defaults to [Utf8Decoder].
  ResponseDecoder? responseDecoder;

  /// Indicates the format of collection data in request query parameters and
  /// `x-www-url-encoded` body data.
  ///
  /// Defaults to [ListFormat.multi].
  ListFormat? listFormat;
}

Map<String, V> caseInsensitiveKeyMap<V>([Map<String, V>? value]) {
  final map = LinkedHashMap<String, V>(
    equals: (key1, key2) => key1.toLowerCase() == key2.toLowerCase(),
    hashCode: (key) => key.toLowerCase().hashCode,
  );
  if (value != null && value.isNotEmpty) map.addAll(value);
  return map;
}
