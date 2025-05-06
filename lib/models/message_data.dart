class MessageData {
  final int amount;
  final String content;
  final DateTime timestamp;

  MessageData({
    required this.amount,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MessageData.fromJson(Map<String, dynamic> json) {
    return MessageData(
      amount: json['Amount'],
      content: json['Content'],
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Amount': amount,
      'Content': content,
    };
  }
}