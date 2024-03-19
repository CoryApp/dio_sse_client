import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:dart_sse_client/sse_client.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
// / EXAMPLE 1: Single connecting client
// / // The user message to be sent to the request.
//   OpenAI.apiKey = 'Dica@123';
//   OpenAI.baseUrl = 'https://gpt.giainhanh.io/api/v1';
//   final userMessage = OpenAIChatCompletionChoiceMessageModel(
//     content: [
//       OpenAIChatCompletionChoiceMessageContentItemModel.text(
//         'Hello my friend!',
//       ),
//     ],
//     role: OpenAIChatMessageRole.user,
//   );

// // The request to be sent.
//   final chatStream = OpenAI.instance.chat.createStream(
//     model: 'gpt-3.5-turbo',
//     messages: [
//       userMessage,
//     ],
//     seed: 423,
//     n: 2,
//   );

// // Listen to the stream.
//   chatStream.listen(
//     (streamChatCompletion) {
//       final content = streamChatCompletion.choices.first.delta.content;
//       print(content);
//     },
//     onDone: () {
//       print('Done');
//     },
//   );

// / Create the client.
  final client = SseDio(
    'POST',
    'https://cory_be.bsson2407.workers.dev/message',
    queryParameters: {
      'text': 'Hello',
      'style': 'friendly',
      'voice': 'en-AU-CarlyNeural',
      'speed': 'normal'
    },
    httpClientAdapter: Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 10),
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
      ),
    ),
    onConnected: () {
      print('Connected');
    },

    /// Whether the class should add the "text/event-stream" content type header to the request. The default is `true`.
    setContentTypeHeader: true,
  );

  /// Now you can connect to the server.
  try {
    /// Connects to the server. Here we are using the `await` keyword to wait for the connection to be established.
    /// If the connection fails, an exception will be thrown.
    var stream = await client.connect();

    /// Connection is successful, now listen to the stream.
    /// Connection will be closed when onError() or onDone() is called.
    stream.listen((event) {
      print('Id: ${event.id}');
      print('Event: ${event.event}');
      print('Data: ${event.data}');
    })
      ..onError((Object error) {
        print('Error: $error');
      })
      ..onDone(() {
        /// This will not be called when the connection is closed by the client via [client.close()].
        /// So, [onDone()] means the connection is closed by the server, which is usually not normal,
        /// and a reconnection is probably needed.
        print('Disconnected by the server');
      });
  } catch (e) {
    print('Connection Error: $e');
  }

  /// Closes the connection manually.
  // client.close();

  // /// EXAMPLE 2: Auto reconnecting client

  // final autoReconnectingClient = AutoReconnectSseDio(
  //   /// Same as SseClient, see above.
  //   'POST',
  //   'https://cory_be.bsson2407.workers.dev/message',
  //   queryParameters: {
  //     'text': 'Hello',
  //     'style': 'friendly',
  //     'voice': 'en-AU-CarlyNeural',
  //     'speed': 'normal'
  //   },
  //   onConnected: () {
  //     print('Connected');
  //   },
  //   setContentTypeHeader: true,

  //   /// Maximum number of retries before giving up. The default is -1, which means infinite retries.
  //   /// The number of retry won't accumulate, it will reset every time a connection is successfully established.
  //   /// If the maximum number of retries is reached, the stream will close with an error.
  //   maxRetries: -1,

  //   /// Called when an error occurred and a reconnection is about to be made.
  //   /// The callback won't be called if the maximum number of retries is reached.
  //   /// If this callback returns `null`, no retry will be made, and the error will be propagated to the stream.
  //   /// Check the source code's `ReconnectStrategyCallback` typedef for details of the callback parameters.
  //   onError: (errorType, retryCount, reconnectionTime, error, stacktrace) =>
  //       RetryStrategy(
  //     /// The delay before the next retry. By default it will acknowledge `reconnectionTime` with an exponential backoff.
  //     delay: Duration(seconds: 5),

  //     /// Whether to append the `Last-Event-ID` header to the request. Defaults to true.
  //     appendLastIdHeader: true,
  //   ),
  // );

  // final str = await autoReconnectingClient.connect();
  // str.listen((event) {
  //   print('Id: ${event.id}');
  //   print('Event: ${event.event}');
  //   print('Data: ${event.data}');
  // })
  //   ..onError((Object error) {
  //     print('Error: $error');
  //   })
  //   ..onDone(() {
  //     /// This will not be called when the connection is closed by the client via [client.close()].
  //     /// So, [onDone()] means the connection is closed by the server, which is usually not normal,
  //     /// and a reconnection is probably needed.
  //     print('Disconnected by the server');
  //   });
}
