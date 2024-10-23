import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  _AddSubscriptionPageState createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  double _price = 0.0;
  String _dueDate = '';
  String _billingCycle = '1 month';
  late TextEditingController _dateController;
  String _notes = '';

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Subscription'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildNameField(),
                const SizedBox(height: 16),
                _buildPriceField(),
                const SizedBox(height: 16),
                _buildDateField(context),
                const SizedBox(height: 16),
                _buildBillingCycleField(),
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 16),
                _buildSaveButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Subscription Name',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter the subscription name';
        }
        return null;
      },
      onSaved: (value) {
        _name = value!;
      },
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Price',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter the price';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid price (e.g., 10.00)';
        }
        return null;
      },
      onSaved: (value) {
        _price = double.parse(value!);
      },
    );
  }

  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Next Billing Date (DD-MM-YYYY)',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        setState(() {
          _dueDate = DateFormat('dd-MM-yyyy').format(pickedDate!);
          _dateController.text = _dueDate;
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter the next billing date';
        }
        return null;
      },
      onSaved: (value) {
        _dueDate = value!;
      },
    );
  }

  Widget _buildBillingCycleField() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Billing Cycle',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      value: _billingCycle,
      items: List.generate(
        12,
        (index) => DropdownMenuItem(
          value: '${index + 1} month${index + 1 > 1 ? 's' : ''}',
          child: Text('${index + 1} month${index + 1 > 1 ? 's' : ''}'),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _billingCycle = value!;
        });
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Notes',
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      onSaved: (value) {
        _notes = value ?? '';
      },
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();

            final newSubscription = <String, dynamic>{
              'name': _name,
              'price': _price.toStringAsFixed(2),
              'dueDate': _dueDate,
              'billingCycle': _billingCycle,
              'notes': _notes,
            };

            Navigator.pop(context, newSubscription);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
        child: const Text(
          'Save Subscription',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
