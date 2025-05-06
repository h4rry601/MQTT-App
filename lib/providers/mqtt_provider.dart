import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/message_data.dart';

class MqttProvider with ChangeNotifier {
  static const String _host = '192.168.1.24';
  static const int _port = 31883;
  static const String _username = 'test';
  static const String _password = 'Abc@123';
  static const String _pubTopic = 'test/req';
  static const String _subTopic = 'test/rep';

  MqttServerClient? _client;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  final List<MessageData> _receivedMessages = [];

  List<MessageData> get receivedMessages => _receivedMessages;
  MqttConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == MqttConnectionState.connected;

  Future<void> connect() async {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      return;
    }

    _client = MqttServerClient(_host, '');
    _client!.port = _port;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_mqtt_app_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .authenticateAs(_username, _password);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('Exception: $e');
      _client!.disconnect();
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _connectionState = MqttConnectionState.connected;
      _subscribe();
    } else {
      _connectionState = _client!.connectionStatus!.state;
    }
    notifyListeners();
  }

  void _subscribe() {
    _client!.subscribe(_subTopic, MqttQos.atLeastOnce);
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final recMess = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        debugPrint('Received message on ${message.topic}: $payload');
        
        try {
          final Map<String, dynamic> data = json.decode(payload);
          final messageData = MessageData.fromJson(data);
          _receivedMessages.add(messageData);
          debugPrint('Added message to list: ${messageData.content}');
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to parse message: $e');
        }
      }
    });
    
    // Also subscribe to the request topic for testing/debugging
    _client!.subscribe(_pubTopic, MqttQos.atLeastOnce);
  }

  Future<bool> publishMessage(MessageData messageData) async {
    if (!isConnected) {
      await connect();
      if (!isConnected) return false;
    }

    final builder = MqttClientPayloadBuilder();
    final jsonMessage = json.encode(messageData.toJson());
    builder.addString(jsonMessage);

    debugPrint('Publishing message to $_pubTopic: $jsonMessage');

    try {
      _client!.publishMessage(
        _pubTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
      
      // For testing: add the message to our own list too
      // This simulates receiving our own message back, which helps testing
      // You can remove this in production if you don't want to see your own messages
      _receivedMessages.add(messageData);
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Failed to publish message: $e');
      return false;
    }
  }

  void _onConnected() {
    _connectionState = MqttConnectionState.connected;
    notifyListeners();
  }

  void _onDisconnected() {
    _connectionState = MqttConnectionState.disconnected;
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    debugPrint('Subscribed to topic: $topic');
  }

  void disconnect() {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.disconnect();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}