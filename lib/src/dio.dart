import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_sse_client/src/dio_option.dart';
import 'package:dio/dio.dart';

// import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

/// Internal buffer for SSE events.
class _EventBuffer {
  final String id;
  final String event;
  final String data;

  _EventBuffer({this.data = '', this.id = '', this.event = ''});

  _EventBuffer copyWith({
    String? id,
    String? event,
    String? data,
  }) =>
      _EventBuffer(
        id: id ?? this.id,
        event: event ?? this.event,
        data: data ?? this.data,
      );

  MessageEvent toMessageEvent() => MessageEvent(
        id: id,
        event: event,
        data: data.endsWith('\n') ? data.substring(0, data.length - 1) : data,
      );
}

enum ConnectionState { connected, connecting, disconnected }

final _numericRegex = RegExp(r'^\d+$');

class SseDio {
  final String method;
  final String url;
  final Map<String, dynamic>? queryParameters;
  final Object? data;
  final bool setContentTypeHeader;
  final DioOptions? options;
  final Function? onConnected;
  final HttpClientAdapter? httpClientAdapter;

  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  SseDio(this.method, this.url,
      {this.httpClientAdapter,
      this.queryParameters,
      this.data,
      this.options,
      this.onConnected,
      this.setContentTypeHeader = true}) {}

  late Dio _dio = Dio();

  StreamController<MessageEvent>? _streamController;

  String? _lastEventId;
  String? get lastEventId => _lastEventId;
  int? _reconnectionTime;
  int? get reconnectionTime => _reconnectionTime;

  Future<Stream<MessageEvent>> connect() async {
    if (_state != ConnectionState.disconnected) {
      throw Exception('Already connected or connecting to SSE');
    }

    var streamController = StreamController<MessageEvent>();

    _state = ConnectionState.connecting;

    Response<ResponseBody>? response;

    final Options _options = Options(
      method: method,
      responseType: ResponseType.stream,
      sendTimeout: options?.sendTimeout,
      receiveTimeout: options?.receiveTimeout,
      extra: options?.extra,
      headers: options?.headers,
      preserveHeaderCase: options?.preserveHeaderCase,
      contentType: options?.contentType,
      validateStatus: options?.validateStatus,
      receiveDataWhenStatusError: options?.receiveDataWhenStatusError,
      followRedirects: options?.followRedirects,
      maxRedirects: options?.maxRedirects,
      persistentConnection: options?.persistentConnection,
      requestEncoder: options?.requestEncoder,
      responseDecoder: options?.responseDecoder,
      listFormat: options?.listFormat,
    );

    try {
      // var future = _client!.send(_copyRequest());

      if (httpClientAdapter != null) {
        _dio.httpClientAdapter = httpClientAdapter!;
      }
      response = await _dio.request<ResponseBody>(
        url,
        queryParameters: queryParameters,
        data: data,
        options: _options,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed subscribing to SSE - invalid response code ${response.statusCode}');
      }

      // if (!response.headers.containsKey('content-type') ||
      //     (response.headers['content-type']!.split(';')[0] !=
      //         'text/event-stream')) {
      //   throw Exception(
      //       'Failed subscribing to SSE - unexpected Content-Type ${response.headers['content-type']}');
      // }
    } catch (error) {
      rethrow;
    }

    if (_state != ConnectionState.connecting) {
      throw Exception(
          'Failed subscribing to SSE - connection is fine but client\'s connection state is not "connecting"');
    }

    if (response.data == null) {
      throw Exception(
          'Failed subscribing to SSE - connection is fine but client\'s connection state is not "connecting"');
    }
    _state = ConnectionState.connected;

    _EventBuffer? eventBuffer;

    try {
      response.data!.stream
          .transform(unit8Transformer)
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen((dataLine) {
        if (dataLine.isEmpty) {
          if (streamController.isClosed) {
            return;
          }

          if (eventBuffer == null) {
            return;
          }

          _lastEventId = eventBuffer!.id;
          streamController.sink.add(eventBuffer!.toMessageEvent());
          eventBuffer = _EventBuffer();
          return;
        }

        if (dataLine.startsWith(':')) {
          return;
        }

        String? fieldName;
        String? fieldValue;

        if (dataLine.contains(':')) {
          var pos = dataLine.indexOf(':');
          fieldName = dataLine.substring(0, pos);
          fieldValue = dataLine.substring(pos + 1);
          if (fieldValue.startsWith(' ')) {
            fieldValue = fieldValue.substring(1);
          }
        } else {
          fieldName = dataLine;
          fieldValue = '';
        }

        eventBuffer ??= _EventBuffer();

        switch (fieldName) {
          case 'event':
            eventBuffer = eventBuffer!.copyWith(
              event: fieldValue,
            );

          case 'data':
            eventBuffer = eventBuffer!.copyWith(
              data: '${eventBuffer!.data}$fieldValue\n',
            );

          case 'id':
            if (!fieldValue.contains('\u0000')) {
              eventBuffer = eventBuffer!.copyWith(
                id: fieldValue,
              );
            }
          case 'retry':
            if (_numericRegex.hasMatch(fieldValue)) {
              _reconnectionTime = int.parse(fieldValue);
            }
        }
      })
        ..onDone(() {
          if (streamController.isClosed) {
            return;
          }
          streamController.close();
        })
        ..onError((Object e, StackTrace? s) {
          if (streamController.isClosed) {
            return;
          }
          streamController.addError(e, s);
        });
    } catch (error) {
      rethrow;
    }

    onConnected?.call();
    _streamController = streamController;
    return streamController.stream;
  }

  void close() {
    _state = ConnectionState.disconnected;
    _streamController?.close();
    _streamController = null;
    _dio.close();
  }
}

enum ConnectionError { streamEndedPrematurely, connectionFailed, errorEmitted }

typedef ReconnectStrategyCallback = RetryStrategy? Function(
    ConnectionError errorType,
    int retryCount,
    int? reconnectionTime,
    Object error,
    StackTrace stacktrace);

class AutoReconnectSseDio extends SseDio {
  final int _maxRetries;

  final ReconnectStrategyCallback _onError;

  final void Function()? _onRetry;
  StreamController<MessageEvent>? _outerStreamController;

  RetryStrategy? _lastRetryStrategy;

  AutoReconnectSseDio(
    super.url,
    super.options, {
    super.onConnected,
    super.queryParameters,
    super.httpClientAdapter,
    super.setContentTypeHeader = true,
    int maxRetries = -1,
    required ReconnectStrategyCallback onError,
    void Function()? onRetry,
  })  : _maxRetries = maxRetries,
        _onRetry = onRetry,
        _onError = onError;

  AutoReconnectSseDio.defaultStrategy(super.url, super.options,
      {super.onConnected,
      super.queryParameters,
      super.httpClientAdapter,
      super.setContentTypeHeader = true,
      int maxRetries = -1,
      void Function()? onRetry})
      : _maxRetries = maxRetries,
        _onError = _defaultStrategyCallback,
        _onRetry = onRetry;

  // @override
  // http.StreamedRequest _copyRequest() {
  //   var copiedRequest = super._copyRequest();
  //   if ((_lastRetryStrategy?.appendLastIdHeader ?? false) &&
  //       lastEventId != null) {
  //     copiedRequest.headers['Last-Event-ID'] = lastEventId!;
  //   }
  //   return copiedRequest;
  // }

  @override
  void close() {
    print('Disconnecting');
    _outerStreamController?.close();
    super.close();
  }

  @override
  Future<Stream<MessageEvent>> connect() async {
    if (_state != ConnectionState.disconnected) {
      throw Exception('Already connected or connecting to SSE');
    }

    _outerStreamController = StreamController<MessageEvent>();
    _doConnect(0);
    return _outerStreamController!.stream;
  }

  Future<void> _doConnect(int retryCount) async {
    bool didConnect = false;
    try {
      var innerStream = await super.connect();
      didConnect = true;

      await for (final event in innerStream) {
        if (_outerStreamController == null ||
            _outerStreamController!.isClosed) {
          return;
        }
        _outerStreamController!.add(event);
      }

      if (_outerStreamController == null || _outerStreamController!.isClosed) {
        return;
      }

      throw UnexpectedStreamDoneException('The server event stream is closed.');
    } catch (error, stackTrace) {
      if (_outerStreamController == null || _outerStreamController!.isClosed) {
        return;
      }

      RetryStrategy? getLastRetryStrategy() => _lastRetryStrategy = _onError(
          didConnect
              ? (error is UnexpectedStreamDoneException
                  ? ConnectionError.streamEndedPrematurely
                  : ConnectionError.errorEmitted)
              : ConnectionError.connectionFailed,
          retryCount,
          reconnectionTime,
          error,
          stackTrace);

      if (retryCount == _maxRetries || getLastRetryStrategy() == null) {
        _outerStreamController!.addError(error, stackTrace);
        close();
      } else {
        super.close();
        await Future<void>.delayed(_lastRetryStrategy!.delay);
        _onRetry?.call();
        _doConnect(retryCount + 1);
      }
    }
  }
}

final _defaultStrategyCallback = (ConnectionError errorType, int retryCount,
        int? reconnectionTime, Object obj, StackTrace stack) =>
    RetryStrategy(
      delay: Duration(milliseconds: reconnectionTime ?? 500) *
          math.pow(1.5, math.min(10, retryCount)),
      appendLastIdHeader: true,
    );

StreamTransformer<Uint8List, List<int>> unit8Transformer =
    StreamTransformer.fromHandlers(
  handleData: (data, sink) {
    sink.add(List<int>.from(data));
  },
);
