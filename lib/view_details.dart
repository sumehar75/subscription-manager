import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subscription;
  final int index;

  const ViewDetailsPage({
    required this.subscription,
    required this.index,
    super.key,
  });

  @override
  _ViewDetailsPageState createState() => _ViewDetailsPageState();
}

class _ViewDetailsPageState extends State<ViewDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _price;
  late String _dueDate;
  late String _notes;
  late String _billingCycle;

  final TextEditingController _dateController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _name = widget.subscription['name'] ?? '';
    _price = widget.subscription['price'] ?? '';
    _dueDate = widget.subscription['dueDate'] ?? '';
    _notes = widget.subscription['notes'] ?? '';
    _billingCycle = widget.subscription['billingCycle'] ?? '1 month';

    _dateController.text = _dueDate; // Initialize date controller
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedSubscription = {
        'id': widget.subscription['id'], // Ensure 'id' is included
        'name': _name,
        'price': _price,
        'dueDate': _dueDate,
        'notes': _notes,
        'billingCycle': _billingCycle,
      };

      Navigator.pop(context, updatedSubscription);
    }
  }

  Future<void> _deleteSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final subscriptionId =
            widget.subscription['id']; // Ensure this field exists

        if (subscriptionId != null) {
          // Mark the subscription as deleted in Firebase instead of removing it
          await _firestore
              .collection('subscriptions')
              .doc(user.uid)
              .collection('userSubscriptions')
              .doc(subscriptionId)
              .update({'deleted': true}); // Add a 'deleted' flag

          Navigator.pop(context, 'delete');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid subscription ID found.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    setState(() {
      _dueDate =
          '${pickedDate!.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}';
      _dateController.text = _dueDate; // Update date text field
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SubsManager'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(
                context, 'cancel'); // Return 'cancel' when back is pressed
          },
        ),
      ),
      backgroundColor: Colors.white, // Set background color to white
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.05), // Dynamic padding
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subscription Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _name,
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
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _price,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount (e.g., 10.00)';
                  }
                  return null;
                },
                onSaved: (value) {
                  _price = double.parse(value!).toStringAsFixed(2);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Renewal Date (DD-MM-YYYY)',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onTap: _pickDate,
                onSaved: (value) {
                  _dueDate = value!;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _billingCycle,
                decoration: InputDecoration(
                  labelText: 'Billing Cycle',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: '${index + 1} month${index + 1 > 1 ? 's' : ''}',
                    child:
                        Text('${index + 1} month${index + 1 > 1 ? 's' : ''}'),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _billingCycle = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onSaved: (value) {
                  _notes = value!;
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.02),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _deleteSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.02),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                        ),
                        child: const Text(
                          'Delete Subscription',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
