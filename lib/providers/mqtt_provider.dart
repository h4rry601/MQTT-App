import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_data.dart';

enum MqttConnectionState { connected, disconnected, connecting }

class MqttProvider with ChangeNotifier {
  final Logger _log = Logger('MqttProvider');
  final String _host = '192.168.1.24';
  final int _port = 31883;
  final String _user = 'test';
  final String _password = 'Abc@123';
  final String _pubTopic = 'test/req';
  final String _subTopic = 'test/rep';
  final String _clientId =
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  final String _uuidUrl = 'http://192.168.1.24:31501/uuid';

  MqttServerClient? _client;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  final List<MessageData> _receivedMessages = [];
  StreamSubscription? _updatesSubscription;
  String? _currentUuid;

  MqttConnectionState get connectionState => _connectionState;
  List<MessageData> get receivedMessages =>
      List.unmodifiable(_receivedMessages);
  bool get isConnected => _connectionState == MqttConnectionState.connected;

  MqttProvider() {
    _log.info('MqttProvider initialized');
    _loadUuid();
  }

  Future<void> _loadUuid() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUuid = prefs.getString('uuid');
    if (_currentUuid == null) {
      await _fetchUuid();
    }
    _log.info('Loaded UUID: $_currentUuid');
  }

  Future<void> _fetchUuid() async {
    try {
      final response = await http
          .get(Uri.parse(_uuidUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _currentUuid = json['uuid'] as String?;
        if (_currentUuid != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('uuid', _currentUuid!);
          _log.info('Fetched and saved new UUID: $_currentUuid');
        } else {
          _log.warning('UUID not found in response: ${response.body}');
        }
      } else {
        _log.severe('Failed to fetch UUID. Status: ${response.statusCode}');
      }
    } catch (e) {
      _log.severe('Error fetching UUID: $e');
    }
  }

  Future<void> connect() async {
    if (_connectionState == MqttConnectionState.connected ||
        _connectionState == MqttConnectionState.connecting) {
      _log.info('Already connected or connecting. State: $_connectionState');
      return;
    }

    _setConnectionState(MqttConnectionState.connecting);
    _log.info('Connecting to $_host:$_port with client ID: $_clientId');

    _client = MqttServerClient(_host, _clientId);
    _client!.port = _port;
    _client!.logging(on: true);
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = _onSubscribeFail;
    _client!.pongCallback = _pong;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .authenticateAs(_user, _password)
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );
      _log.info('Connection attempt completed');
    } on TimeoutException catch (e) {
      _log.severe('Connection timed out: $e');
      _handleDisconnect();
    } on NoConnectionException catch (e) {
      _log.severe('Client exception: $e');
      _handleDisconnect();
    } on SocketException catch (e) {
      _log.severe('Socket exception: $e');
      _handleDisconnect();
    } catch (e) {
      _log.severe('Connection failed: $e');
      _handleDisconnect();
    }

    if (_client != null) {
      _updatesSubscription?.cancel();
      _updatesSubscription = _client!.updates?.listen(_onMessageReceived);
      _log.info('Message updates listener set up');
    } else {
      _log.warning('Client is null, cannot set up message listener');
    }
  }

  void disconnect() {
    _log.info('Attempting to disconnect. Current state: $_connectionState');
    if (_client != null &&
        _connectionState != MqttConnectionState.disconnected) {
      _client!.disconnect();
    }
    _handleDisconnect();
  }

  Future<bool> publishMessage(int amount, String content) async {
    if (!isConnected || _client == null) {
      _log.warning('Cannot publish: client not connected');
      return false;
    }

    if (_currentUuid == null) {
      await _fetchUuid();
      if (_currentUuid == null) {
        _log.severe('Cannot publish: UUID not available');
        return false;
      }
    }

    final messageData = {
      'UUID': _currentUuid,
      'Amount': amount,
      'Content': content,
    };
    final jsonPayload = jsonEncode(messageData);
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonPayload);

    try {
      _log.info('Publishing message to $_pubTopic: $jsonPayload');
      _client!.publishMessage(_pubTopic, MqttQos.atLeastOnce, builder.payload!);
      _log.info('Publish attempt sent');
      return true;
    } catch (e) {
      _log.severe('Error publishing message: $e');
      return false;
    }
  }

  void _onConnected() {
   _log.severe('Client connected to MQTT broker');
    _setConnectionState(MqttConnectionState.connected);
    _log.severe('Subscribing to $_subTopic');
    final subscribeTopicResult = _client?.subscribe(
      _subTopic,
      MqttQos.atLeastOnce,
    );
    if (subscribeTopicResult == null) {
      _log.severe('Error: Subscribe call returned null');
      _handleDisconnect();
    } else {
      _log.info('Subscribe call initiated. Awaiting confirmation...');
    }
  }

  void _onDisconnected() {
    _log.info('Client disconnected from MQTT broker');
    _handleDisconnect();
  }

  void _onSubscribed(String topic) {
    _log.info('Confirmed subscribed to topic: $topic');
    if (topic == _subTopic) {
      _log.info('Successfully subscribed to topic: $_subTopic');
    }
  }

  void _onSubscribeFail(String topic) {
    _log.severe('Failed to subscribe to topic: $topic');
    _handleDisconnect();
  }

  void _pong() {
    _log.fine('Ping response received (pong)');
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> event) {
    _log.info('>>>> _onMessageReceived called. Event length: ${event.length}');

    if (event.isEmpty) {
      _log.warning('Received empty message event');
      return;
    }

    final messageEvent = event[0];
    final recMess = messageEvent.payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );
    final topic = messageEvent.topic;

    if (payload.isEmpty) {
      _log.warning('Received empty payload on topic: "$topic"');
      return;
    }

    _log.info('Received message - Topic: "$topic", Payload: "$payload"');

    if (topic == _subTopic) {
      _log.info(
        'Processing message for subscribed topic: "$_subTopic". Payload: "$payload"',
      );
      try {
        final message = MessageData.fromPayload(payload);
        if (message.uuid == _currentUuid) {
          _receivedMessages.insert(0, message);
          _log.info(
            'Message added. Total messages: ${_receivedMessages.length}, Message: ${message.toJson()}',
          );
          notifyListeners();
        } else {
          _log.info(
            'Message ignored: UUID ${message.uuid} does not match client UUID $_currentUuid',
          );
        }
      } catch (e, stackTrace) {
        _log.severe(
          'Error processing message - Payload: "$payload", Error: $e, StackTrace: $stackTrace',
        );
      }
    } else {
      _log.warning('Received message on non-subscribed topic: "$topic"');
    }
  }

  void _handleDisconnect() {
    _log.info('Handling disconnect. Current state: $_connectionState');
    if (_connectionState != MqttConnectionState.disconnected) {
      _setConnectionState(MqttConnectionState.disconnected);
    }
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _client = null;
    _log.info('Client reference nullified');
    Future.delayed(const Duration(seconds: 5), () {
      if (_connectionState == MqttConnectionState.disconnected) {
        _log.info('Attempting to reconnect...');
        connect();
      }
    });
  }

  void _setConnectionState(MqttConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _log.info('Connection state changed to: $state');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _log.info('MqttProvider disposed. Disconnecting...');
    disconnect();
    super.dispose();
  }
}
