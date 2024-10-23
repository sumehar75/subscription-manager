import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonthlyExpensePage extends StatefulWidget {
  final List<Map<String, dynamic>> subscriptions;

  const MonthlyExpensePage({required this.subscriptions, super.key});

  @override
  _MonthlyExpensePageState createState() => _MonthlyExpensePageState();
}

class _MonthlyExpensePageState extends State<MonthlyExpensePage> {
  Map<int, Map<String, dynamic>> _expectedExpenses = {};
  Map<int, Map<String, dynamic>> _currentExpenses = {};
  int _currentYear = DateTime.now().year;
  bool _showCurrentExpenses = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeExpenses();
  }

  Future<void> _initializeExpenses() async {
    await _fetchExpenseHistoryFromFirebase();
    await _calculateExpenses();
  }

  Future<void> _fetchExpenseHistoryFromFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('expenseHistory')
            .where('year', isEqualTo: _currentYear)
            .get();

        Map<int, Map<String, dynamic>> fetchedExpenses = {};

        // Populate fetchedExpenses with data from Firebase
        for (var doc in snapshot.docs) {
          int month = doc.data()['month'] ?? 0;
          double total = doc.data()['total'] ?? 0.0;
          List subscriptions = doc.data()['subscriptions'] ?? [];

          fetchedExpenses[month] = {
            'total': total,
            'subscriptions': subscriptions,
          };
        }

        // Initialize all months for the current year
        for (int month = 1; month <= 12; month++) {
          if (!fetchedExpenses.containsKey(month)) {
            fetchedExpenses[month] = {'total': 0.0, 'subscriptions': []};
          }
        }

        setState(() {
          _currentExpenses = fetchedExpenses;
        });
      } catch (e) {
        print('Error fetching expense history from Firebase: $e');
      }
    } else {
      print('User is not logged in.');
    }
  }

  Future<void> _calculateExpenses() async {
    Map<int, Map<String, dynamic>> expectedExpenses = {};
    Map<int, Map<String, dynamic>> currentExpenses = {};

    // Initialize expenses for each month (1-12)
    for (int month = 1; month <= 12; month++) {
      expectedExpenses[month] = {'total': 0.0, 'subscriptions': []};
      currentExpenses[month] = _currentExpenses.containsKey(month)
          ? _currentExpenses[month]!
          : {'total': 0.0, 'subscriptions': []};
    }

    DateTime todayWithoutTime =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int currentMonth = DateTime.now().month;

    for (var subscription in widget.subscriptions) {
      String dueDateStr = subscription['dueDate']!;
      DateTime dueDate = DateFormat('dd-MM-yyyy').parse(dueDateStr);
      double price = double.tryParse(subscription['price'] ?? '0') ?? 0.0;
      String billingCycle = subscription['billingCycle'] ?? '1 month';
      int cycleMonths = int.parse(billingCycle.split(' ')[0]);

      DateTime nextDueDate = dueDate;

      // Loop through billing cycles until the current year
      while (nextDueDate.year <= _currentYear) {
        if (nextDueDate.year == _currentYear) {
          // Current view logic: add all subscriptions up to today
          if (nextDueDate.isBefore(todayWithoutTime) ||
              nextDueDate.isAtSameMomentAs(todayWithoutTime)) {
            bool alreadyExists = currentExpenses[nextDueDate.month]
                        ?['subscriptions']
                    ?.any((sub) => sub['name'] == subscription['name']) ??
                false;

            // Add to current expenses if not already added
            if (!alreadyExists) {
              currentExpenses[nextDueDate.month]!['total'] += price;
              currentExpenses[nextDueDate.month]!['subscriptions'].add({
                'name': subscription['name'],
                'price': price.toStringAsFixed(2),
              });

              // Save to Firebase
              await _saveToFirebaseIfNeeded(
                  nextDueDate.month, subscription, price);
            }
          }

          // Expected view logic for the current month: add both past and future subscriptions
          if (nextDueDate.month == currentMonth) {
            // Add upcoming subscriptions (due after today)
            bool alreadyExistsInExpected = expectedExpenses[nextDueDate.month]
                        ?['subscriptions']
                    ?.any((sub) => sub['name'] == subscription['name']) ??
                false;

            // Only add future subscriptions
            if (!alreadyExistsInExpected &&
                nextDueDate.isAfter(todayWithoutTime)) {
              expectedExpenses[nextDueDate.month]!['total'] += price;
              expectedExpenses[nextDueDate.month]!['subscriptions'].add({
                'name': subscription['name'],
                'price': price.toStringAsFixed(2),
              });
            }
          }

          // Expected view logic for other months: add the subscription directly
          if (nextDueDate.month != currentMonth) {
            expectedExpenses[nextDueDate.month]!['total'] += price;
            expectedExpenses[nextDueDate.month]!['subscriptions'].add({
              'name': subscription['name'],
              'price': price.toStringAsFixed(2),
            });
          }
        }

        // Get next billing cycle due date
        nextDueDate = _getNextBillingDate(nextDueDate, cycleMonths);
      }
    }

    // Ensure that every month is initialized in both expected and current expenses
    for (int month = 1; month <= 12; month++) {
      if (!_currentExpenses.containsKey(month)) {
        _currentExpenses[month] = {'total': 0.0, 'subscriptions': []};
      }
    }

    // Merge current and expected expenses
    setState(() {
      _currentExpenses = currentExpenses;

      // Merge past subscriptions in current month with upcoming ones in expected view
      if (expectedExpenses.containsKey(currentMonth)) {
        expectedExpenses[currentMonth]!['total'] +=
            currentExpenses[currentMonth]!['total'];
        expectedExpenses[currentMonth]!['subscriptions']
            .addAll(currentExpenses[currentMonth]!['subscriptions']);
      }

      _expectedExpenses = expectedExpenses;
    });
  }

  Future<void> _saveToFirebaseIfNeeded(
      int month, Map<String, dynamic> subscription, double price) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('expenseHistory')
            .doc('$_currentYear')
            .collection('months')
            .doc(month.toString());

        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          // Check if the subscription already exists
          List savedSubscriptions = docSnapshot.data()?['subscriptions'] ?? [];
          bool alreadyExists = savedSubscriptions.any((sub) =>
              sub['name'] == subscription['name'] &&
              sub['price'] == price.toStringAsFixed(2));

          if (!alreadyExists) {
            await docRef.update({
              'total': FieldValue.increment(price),
              'subscriptions': FieldValue.arrayUnion([
                {
                  'name': subscription['name'],
                  'price': price.toStringAsFixed(2),
                }
              ])
            });
          }
        } else {
          // Create a new document if it doesn't exist
          await docRef.set({
            'month': month,
            'year': _currentYear,
            'total': price,
            'subscriptions': [
              {
                'name': subscription['name'],
                'price': price.toStringAsFixed(2),
              }
            ]
          });
        }
      } catch (e) {
        print('Error saving to Firebase: $e');
      }
    }
  }

  DateTime _getNextBillingDate(DateTime currentDueDate, int cycleMonths) {
    int nextMonth = currentDueDate.month + cycleMonths;
    int nextYear = currentDueDate.year;

    if (nextMonth > 12) {
      nextYear += nextMonth ~/ 12;
      nextMonth = nextMonth % 12;
      if (nextMonth == 0) {
        nextMonth = 12;
        nextYear -= 1;
      }
    }

    int lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    int newDay = currentDueDate.day > lastDayOfNextMonth
        ? lastDayOfNextMonth
        : currentDueDate.day;

    return DateTime(nextYear, nextMonth, newDay);
  }

  void _changeYear(int offset) {
    setState(() {
      _currentYear += offset;
      _initializeExpenses();
    });
  }

  double _calculateTotalYearlyExpense(Map<int, Map<String, dynamic>> expenses) {
    return expenses.values
        .map((monthData) => monthData['total'] as double)
        .fold(0.0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    Map<int, Map<String, dynamic>> displayedExpenses =
        _showCurrentExpenses ? _currentExpenses : _expectedExpenses;

    double yearlyTotal = _calculateTotalYearlyExpense(displayedExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => _changeYear(-1),
          ),
          Center(
            child: Text(
              '$_currentYear',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.black),
            onPressed: () => _changeYear(1),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCurrentExpenses = true;
                    });
                  },
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _showCurrentExpenses ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCurrentExpenses = false;
                    });
                  },
                  child: Text(
                    'Expected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: !_showCurrentExpenses ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: displayedExpenses.entries.map((entry) {
                  int month = entry.key;
                  double total = entry.value['total'];
                  List subscriptions = entry.value['subscriptions'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Card(
                      color: Colors.grey[300],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.MMMM().format(DateTime(0, month)),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...subscriptions.map<Widget>((sub) {
                              return ListTile(
                                title: Text(sub['name']),
                                trailing: Text('${sub['price']}'),
                              );
                            }),
                            const Divider(),
                            ListTile(
                              title: const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(total.toStringAsFixed(2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text(
                'Yearly Total',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(yearlyTotal.toStringAsFixed(2)),
            ),
          ],
        ),
      ),
    );
  }
}
