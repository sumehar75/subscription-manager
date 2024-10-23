import 'package:flutter/material.dart';
import 'add_subs.dart';
import 'view_details.dart';
import 'profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'monthly_expense.dart';
import 'dart:io'; // Import for File

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> subscriptions = [];
  String? _userName;
  List<Map<String, dynamic>> filteredSubscriptions = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _imagePath;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _fetchSubscriptions();
    _loadProfileImage();
  }

  void _loadUserName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      setState(() {
        _userName = userDoc.data()?['username'] ??
            user.displayName ??
            prefs.getString('username') ??
            'User';
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    _imagePath = prefs.getString('profile_image');

    if (_imagePath != null && _imagePath!.isNotEmpty) {
      setState(() {
        _imageFile = File(_imagePath!);
      });
    }
  }

  Future<void> _fetchSubscriptions() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final querySnapshot = await _firestore
            .collection('subscriptions')
            .doc(user.uid)
            .collection('userSubscriptions')
            .get();

        final fetchedSubscriptions = querySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          subscriptions = fetchedSubscriptions
              .where((subscription) => subscription['deleted'] != true)
              .toList();
          _updateDueDatesIfNeeded();
          _sortSubscriptionsByDueDate();
          filteredSubscriptions = List.from(subscriptions);
        });
      } catch (e) {
        print("Error fetching subscriptions: $e");
      }
    }
  }

  void addSubscription(Map<String, dynamic> newSubscription) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final docRef = await _firestore
            .collection('subscriptions')
            .doc(user.uid)
            .collection('userSubscriptions')
            .add(newSubscription);

        newSubscription['id'] = docRef.id;

        if (!mounted) return;
        setState(() {
          subscriptions.add(newSubscription);
          _updateDueDatesIfNeeded();
          _sortSubscriptionsByDueDate();
          filteredSubscriptions = List.from(subscriptions);
        });
      } catch (e) {
        print("Error adding subscription: $e");
      }
    }
  }

  void updateSubscription(int index, dynamic result) async {
    final user = _auth.currentUser;
    if (user != null && result is Map<String, dynamic>) {
      final subscriptionId = subscriptions[index]['id'];
      try {
        await _firestore
            .collection('subscriptions')
            .doc(user.uid)
            .collection('userSubscriptions')
            .doc(subscriptionId)
            .update(result);

        if (!mounted) return;
        setState(() {
          subscriptions[index] = {
            'id': subscriptionId,
            ...result,
          };
          _updateDueDatesIfNeeded();
          _sortSubscriptionsByDueDate();
          filteredSubscriptions = List.from(subscriptions);
        });
      } catch (e) {
        print("Error updating subscription: $e");
      }
    } else if (result == 'delete') {
      final subscriptionId = subscriptions[index]['id'];
      try {
        await _firestore
            .collection('subscriptions')
            .doc(user?.uid)
            .collection('userSubscriptions')
            .doc(subscriptionId)
            .update({'deleted': true});

        if (!mounted) return;
        setState(() {
          subscriptions.removeAt(index);
          filteredSubscriptions = List.from(subscriptions);
        });
      } catch (e) {
        print("Error deleting subscription: $e");
      }
    }
  }

  void _updateDueDatesIfNeeded() {
    DateTime today = DateTime.now();
    DateTime todayWithoutTime = DateTime(today.year, today.month, today.day);

    for (var subscription in subscriptions) {
      if (subscription['dueDate'] != null) {
        DateTime dueDate =
            DateTime.parse(subscription['dueDate'].split('-').reversed.join());

        if (todayWithoutTime.isAfter(dueDate)) {
          String billingCycle = subscription['billingCycle'] ?? '1 month';
          int cycleMonths = int.parse(billingCycle.split(' ')[0]);

          DateTime newDueDate = _getNextBillingDate(dueDate, cycleMonths);

          subscription['dueDate'] =
              '${newDueDate.day.toString().padLeft(2, '0')}-${newDueDate.month.toString().padLeft(2, '0')}-${newDueDate.year}';
        }
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

  void _sortSubscriptionsByDueDate() {
    DateTime today = DateTime.now();
    DateTime todayWithoutTime = DateTime(today.year, today.month, today.day);

    subscriptions.sort((a, b) {
      final aDueDate = a['dueDate'];
      final bDueDate = b['dueDate'];

      if (aDueDate != null && bDueDate != null) {
        DateTime dateA = DateTime.parse(aDueDate.split('-').reversed.join());
        DateTime dateB = DateTime.parse(bDueDate.split('-').reversed.join());

        if (dateA.isAtSameMomentAs(todayWithoutTime) &&
            !dateB.isAtSameMomentAs(todayWithoutTime)) {
          return -1;
        } else if (!dateA.isAtSameMomentAs(todayWithoutTime) &&
            dateB.isAtSameMomentAs(todayWithoutTime)) {
          return 1;
        }

        return dateA.compareTo(dateB);
      } else {
        return 0;
      }
    });
  }

  void _filterSubscriptions(String query) {
    final filtered = subscriptions.where((sub) {
      final nameLower = sub['name']?.toLowerCase() ?? '';
      final queryLower = query.toLowerCase();
      return nameLower.contains(queryLower);
    }).toList();

    if (!mounted) return;
    setState(() {
      filteredSubscriptions = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!)
                  : const AssetImage('default-profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Welcome, $_userName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (query) => _filterSubscriptions(query),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search subscription',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _HomeButton(
                    icon: Icons.add,
                    label: 'Add New',
                    onTap: () async {
                      final newSubscription = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddSubscriptionPage(),
                        ),
                      );

                      if (newSubscription != null) {
                        addSubscription(newSubscription);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _HomeButton(
                    icon: Icons.calendar_today,
                    label: 'Monthly',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MonthlyExpensePage(
                            subscriptions: subscriptions,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _HomeButton(
                    icon: Icons.manage_accounts,
                    label: 'Manage',
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );

                      if (result == 'refresh') {
                        _loadUserName();
                        _loadProfileImage(); // Refresh profile image on return
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Upcoming Payments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: filteredSubscriptions.length,
                itemBuilder: (context, index) {
                  final subscription = filteredSubscriptions[index];
                  final price = subscription['price'];
                  final billingCycle = subscription['billingCycle'];
                  final cycleText =
                      billingCycle != null && billingCycle.contains(' ')
                          ? billingCycle.split(' ').last
                          : 'month';
                  final displayPrice = price != null && billingCycle != null
                      ? '$price/${billingCycle.split(' ').first} $cycleText'
                      : 'Unknown';

                  DateTime today = DateTime.now();
                  DateTime todayWithoutTime =
                      DateTime(today.year, today.month, today.day);
                  bool isDueToday = subscription['dueDate'] != null &&
                      DateTime.parse(subscription['dueDate']!
                              .split('-')
                              .reversed
                              .join())
                          .isAtSameMomentAs(todayWithoutTime);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: _SubscriptionCard(
                      name: subscription['name'] ?? 'No Name',
                      price: displayPrice,
                      dueDate: subscription['dueDate'] ?? 'No Date',
                      onViewDetails: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewDetailsPage(
                              subscription: subscription,
                              index: index,
                            ),
                          ),
                        );

                        if (result != null) {
                          updateSubscription(index, result);
                        }
                      },
                      isDueToday: isDueToday,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add, color: Colors.black),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.black),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, color: Colors.black),
            label: '',
          ),
        ],
        backgroundColor: Colors.white,
        currentIndex: 1,
        onTap: (index) async {
          if (index == 0) {
            final newSubscription = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddSubscriptionPage(),
              ),
            );

            if (newSubscription != null) {
              addSubscription(newSubscription);
            }
          } else if (index == 2) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );

            if (result == 'refresh') {
              _loadUserName();
              _loadProfileImage(); // Refresh profile image on return
            }
          }
        },
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String name;
  final String price;
  final String dueDate;
  final VoidCallback onViewDetails;
  final bool isDueToday;

  const _SubscriptionCard({
    required this.name,
    required this.price,
    required this.dueDate,
    required this.onViewDetails,
    this.isDueToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: isDueToday
            ? const BorderSide(color: Colors.red, width: 2.0)
            : BorderSide.none,
      ),
      elevation: isDueToday ? 5 : 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDueToday ? Colors.red : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Next due date: $dueDate',
                    style: TextStyle(
                      color: isDueToday ? Colors.red : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDueToday ? Colors.red : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
