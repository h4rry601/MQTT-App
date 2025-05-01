import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

class MessageData {
  final String rawPayload;
  final String uuid;
  final int amount;
  final String content;
  final DateTime? timestamp;
  final String? result;
  final int? interval;

  MessageData({
    required this.rawPayload,
    this.uuid = '',
    this.amount = 0,
    this.content = '',
    this.timestamp,
    this.result,
    this.interval,
  });

  static final Logger _logger = Logger('MessageData');

  factory MessageData.fromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;

      DateTime? parsedTimestamp;
      if (decoded.containsKey('TimeStamp')) {
        try {
          parsedTimestamp = DateTime.parse(decoded['TimeStamp'] as String);
        } catch (e) {
          _logger.warning('Error parsing TimeStamp: $e');
        }
      }

      return MessageData(
        rawPayload: payload,
        uuid: decoded['UUID'] as String? ?? '',
        amount: decoded['Amount'] as int? ?? 0,
        content: decoded['Content'] as String? ?? '',
        timestamp: parsedTimestamp,
        result: decoded['Result'] as String?,
        interval: decoded['Interval'] as int?,
      );
    } catch (e) {
      _logger.warning('Error parsing MQTT payload: $e, Raw payload: $payload');
      return MessageData(
        rawPayload: payload,
        content: 'Error parsing payload: $e',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'UUID': uuid,
      'Amount': amount,
      'Content': content,
      'TimeStamp': timestamp?.toIso8601String(),
      'Result': result,
      'Interval': interval,
    };
  }

  String get formattedTimestamp {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp!);
  }
}