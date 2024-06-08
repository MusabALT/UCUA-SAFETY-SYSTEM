import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ucua_staging/features/ucua_fx/screens/pages/Employee/action_form/viewAction_form.dart';
import 'package:ucua_staging/features/ucua_fx/screens/pages/Employee/condition_form/viewCondition_form.dart';
import 'package:badges/badges.dart' as badges;
import '../../../../../ucuaNotify.dart';

class empNotyPage extends StatefulWidget {
  const empNotyPage({super.key});

  @override
  _empNotyPageState createState() => _empNotyPageState();
}

class _empNotyPageState extends State<empNotyPage> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  late NotificationService _notificationService;
  String? currentUserStaffID;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();

    getCurrentUserStaffID().then((_) {
      _fetchNotifications();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final data = message.data;
        final String type = data['formType'] ?? 'unknown';
        final String formId = data['formId'] ?? '';
        final String notificationId = data['notificationId'] ?? '';
        final String staffID = data['staffID'] ?? '';

        if (staffID == currentUserStaffID) {
          setState(() {
            _notifications.add({
              'title': message.notification!.title ?? 'No Title',
              'body': message.notification!.body ?? 'No Body',
              'formType': type,
              'formId': formId,
              'notificationId': notificationId,
              'empNotiStatus': 'unread',
              'staffID': staffID,
            });
            _unreadNotifications++;
          });
        }
      }
    });
  }

  Future<void> getCurrentUserStaffID() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final uid = currentUser.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final staffID = userDoc.get('staffID');
      setState(() {
        currentUserStaffID = staffID;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    if (currentUserStaffID == null) {
      return;
    }
    try {
      QuerySnapshot ucFormSnapshot = await FirebaseFirestore.instance
          .collection('ucform')
          .where('staffID', isEqualTo: currentUserStaffID)
          .get();
      QuerySnapshot uaFormSnapshot = await FirebaseFirestore.instance
          .collection('uaform')
          .where('staffID', isEqualTo: currentUserStaffID)
          .get();
      int unreadCount = 0;

      unreadCount += await _processFormNotifications(ucFormSnapshot, 'ucform');
      unreadCount += await _processFormNotifications(uaFormSnapshot, 'uaform');

      // Sort notifications by timestamp
      _notifications.sort((a, b) {
        Timestamp timestampA = a['timestamp'] as Timestamp;
        Timestamp timestampB = b['timestamp'] as Timestamp;
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        _unreadNotifications = unreadCount;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<int> _processFormNotifications(QuerySnapshot formSnapshot, String type) async {
    int unreadCount = 0;
    for (QueryDocumentSnapshot formDoc in formSnapshot.docs) {
      CollectionReference notificationsRef = formDoc.reference.collection('notifications');
      QuerySnapshot notificationSnapshot = await notificationsRef.get();
      for (QueryDocumentSnapshot notificationDoc in notificationSnapshot.docs) {
        var notificationData = notificationDoc.data() as Map<String, dynamic>?;
        if (notificationData != null) {
          String empNotiStatus = notificationData.containsKey('empNotiStatus') ? notificationData['empNotiStatus'] : 'unread';
          if (notificationData['staffID'] == currentUserStaffID) {
            _notifications.add({
              'title': notificationData['department'] ?? 'No department',
              'body': notificationData['message'] ?? 'No message',
              'timestamp': notificationData['timestamp'] ?? Timestamp.now(),
              'type': type,
              'formId': formDoc.id,
              'notificationId': notificationDoc.id,
              'empNotiStatus': empNotiStatus,
            });
            if (empNotiStatus == 'unread') {
              unreadCount++;
            }
          }
        }
      }
    }
    return unreadCount;
  }

  String timeAgo(DateTime date) {
    Duration difference = DateTime.now().difference(date);

    if (difference.inDays > 8) {
      return DateFormat('dd/MM/yyyy').format(date); 
    } else if ((difference.inDays / 7).floor() >= 1) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inSeconds >= 1) {
      return '${difference.inSeconds}s';
    } else {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: ListView.separated(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          var notification = _notifications[index];
          var timestamp = notification['timestamp'] as Timestamp;
          var date = timestamp.toDate();
          var formattedTime = timeAgo(date);

          return ListTile(
            title: Text(
              notification['title']!,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(notification['body']!),
                ),
                Flexible(
                  child: Text(formattedTime, style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            trailing: notification['empNotiStatus'] == 'unread'
                ? Transform.translate(
                    offset: Offset(0, 12),
                    child: Icon(Icons.circle, color: Color.fromARGB(255, 33, 82, 243), size: 20),
                  )
                : null,
            onTap: () async {
              String formType = notification['type'];
              String formId = notification['formId'];

              if (formType == 'ucform' || formType == 'uaform') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => formType == 'ucform'
                        ? empViewUCForm(docId: formId)
                        : empViewUAForm(docId: formId),
                  ),
                );
              }

              if (notification['empNotiStatus'] != 'read') {
                try {
                  final docRef = FirebaseFirestore.instance
                      .collection(formType)
                      .doc(formId)
                      .collection('notifications')
                      .doc(notification['notificationId']);

                  await docRef.update({
                    'empNotiStatus': 'read',
                  });

                  setState(() {
                    _notifications[index]['empNotiStatus'] = 'read';
                    _unreadNotifications--;
                  });
                } catch (e) {
                  print('Error marking notifications as read: $e');
                }
              }
            },
          );
        },
        separatorBuilder: (context, index) {
          return Divider();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, "/empHome");
        },
        backgroundColor: const Color.fromARGB(255, 33, 82, 243),
        child: const Icon(
          Icons.home,
          size: 30,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromARGB(255, 33, 82, 243),
        unselectedItemColor: Colors.grey,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: badges.Badge(
              badgeContent: Text(
                '$_unreadNotifications',
                style: TextStyle(color: Colors.white),
              ),
              child: Icon(Icons.notifications),
              showBadge: _unreadNotifications > 0,
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(context, "/empNoty");
        break;
      case 1:
        Navigator.pushNamed(context, "/employeeProfile");
        break;
    }
  }
}
