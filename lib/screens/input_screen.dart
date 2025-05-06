import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:provider/provider.dart';

import '../models/message_data.dart';
import '../providers/mqtt_provider.dart';
import 'results_screen.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({Key? key}) : super(key: key);

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Connect to MQTT when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
      mqttProvider.connect();
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      final formData = _formKey.currentState!.value;
      final messageData = MessageData(
        amount: int.parse(formData['amount'].toString()),
        content: formData['content'],
      );

      final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
      
      try {
        final success = await mqttProvider.publishMessage(messageData);
        
        if (success) {
          // Show dialog for success
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Success'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Message sent successfully to MQTT server.'),
                    const SizedBox(height: 8),
                    Text('Amount: ${messageData.amount}'),
                    Text('Content: ${messageData.content}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
          
          // Also show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Message sent successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'VIEW RESULTS',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to results screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ResultsScreen(),
                    ),
                  );
                },
              ),
            ),
          );
          
          _formKey.currentState?.reset();
        } else {
          // Show dialog for failure
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Error'),
                  ],
                ),
                content: const Text('Failed to send message. Please check your MQTT connection.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqttProvider = Provider.of<MqttProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Data'),
        actions: [
          // Status indicator for MQTT connection
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: mqttProvider.isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mqttProvider.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: mqttProvider.isConnected ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: mqttProvider.isConnected ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mqttProvider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: mqttProvider.isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mqttProvider.isConnected 
                          ? 'Connected to MQTT Server'
                          : 'Disconnected from MQTT Server',
                      style: TextStyle(
                        color: mqttProvider.isConnected ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              FormBuilderTextField(
                name: 'amount',
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  hintText: 'Enter a number between 1 and 1000',
                ),
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.numeric(),
                  FormBuilderValidators.min(1),
                  FormBuilderValidators.max(1000),
                ]),
              ),
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'content',
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  hintText: 'Enter content (max 50 characters)',
                ),
                maxLength: 50,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.maxLength(50),
                ]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('SEND TO MQTT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}