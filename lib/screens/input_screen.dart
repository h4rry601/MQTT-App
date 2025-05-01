import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _amountController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSending = true); // Show loading indicator

      final amount = int.tryParse(_amountController.text);
      final content = _contentController.text;

      if (amount != null) {
        final mqttProvider = context.read<MqttProvider>();
        if (!mqttProvider.isConnected) {
          if (!mounted) return; // Kiểm tra mounted trước khi dùng context
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('MQTT client chưa kết nối. Vui lòng chờ hoặc kiểm tra kết nối.'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isSending = false);
          return; // Exit if not connected
        }

        bool success = await mqttProvider.publishMessage(amount, content);

        if (!mounted) return; // Kiểm tra mounted sau async gap

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dữ liệu đã được gửi thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          // Optional: Clear fields after successful send
          // _amountController.clear();
          // _contentController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thất bại trong việc gửi dữ liệu tới MQTT.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      if (mounted) {
        setState(() => _isSending = false); // Hide loading indicator
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Số lượng',
                hintText: 'Enter a number between 1 and 1000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập số lượng.';
                }
                final amount = int.tryParse(value);
                if (amount == null) {
                  return 'Vui lòng nhập một số hợp lệ.';
                }
                if (amount < 1 || amount > 1000) {
                  return 'Số phải nằm trong khoảng từ 1 đến 1000.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                hintText: 'Enter text (max 50 characters)',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập nội dung';
                }
                if (value.length > 50) {
                  return 'Nội dung không thể vượt quá 50 ký tự.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSending ? null : _submitData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Gửi dữ liệu qua MQTT'),
            ),
            const SizedBox(height: 20),
            Consumer<MqttProvider>(
              builder: (context, mqtt, child) {
                return ElevatedButton(
                  onPressed: mqtt.isConnected ? mqtt.disconnect : mqtt.connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mqtt.isConnected ? Colors.redAccent : Colors.greenAccent,
                  ),
                  child: Text(mqtt.isConnected ? 'Ngắt kết nối MQTT' : 'Kết nối MQTT'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}