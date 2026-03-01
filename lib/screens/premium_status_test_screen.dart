import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumStatusTestScreen extends StatefulWidget {
  const PremiumStatusTestScreen({Key? key}) : super(key: key);

  @override
  State<PremiumStatusTestScreen> createState() =>
      _PremiumStatusTestScreenState();
}

class _PremiumStatusTestScreenState extends State<PremiumStatusTestScreen> {
  late Future<Map<String, dynamic>> _premiumStatusFuture;

  @override
  void initState() {
    super.initState();
    _premiumStatusFuture = _fetchPremiumStatus();
  }

  Future<Map<String, dynamic>> _fetchPremiumStatus() async {
    try {
      // Get current logged-in user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('[PremiumTest] No logged-in user');
        return {
          'isPremium': null,
          'error': 'Not logged in',
          'timestamp': DateTime.now().toString(),
        };
      }

      final uid = user.uid;
      print('[PremiumTest] Fetching premium status for UID: $uid');

      // Read subscriptions/{uid} document
      final docSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .get();

      print('[PremiumTest] Document exists: ${docSnapshot.exists}');
      print('[PremiumTest] Raw document data: ${docSnapshot.data()}');

      if (!docSnapshot.exists) {
        print(
          '[PremiumTest] Subscription document does not exist - defaulting to false',
        );
        return {
          'isPremium': false,
          'reason': 'Document does not exist',
          'timestamp': DateTime.now().toString(),
        };
      }

      final rawValue = docSnapshot.data()?['isPremium'];
      print(
        '[PremiumTest] Raw isPremium value from Firestore: $rawValue (type: ${rawValue.runtimeType})',
      );

      final isPremium = (rawValue is bool) ? rawValue : false;
      print('[PremiumTest] Parsed isPremium: $isPremium');

      return {
        'isPremium': isPremium,
        'rawValue': rawValue.toString(),
        'timestamp': DateTime.now().toString(),
      };
    } catch (e) {
      print('[PremiumTest] Error fetching premium status: $e');
      return {
        'isPremium': null,
        'error': e.toString(),
        'timestamp': DateTime.now().toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Status Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _premiumStatusFuture,
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Get data
            final data = snapshot.data ?? {};
            final isPremium = data['isPremium'] as bool?;
            final error = data['error'] as String?;
            final reason = data['reason'] as String?;
            final rawValue = data['rawValue'] as String?;
            final timestamp = data['timestamp'] as String?;

            // Error state
            if (error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '❌ Error loading premium status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _premiumStatusFuture = _fetchPremiumStatus();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // No user logged in
            if (isPremium == null && error == null && reason == null) {
              return const Center(
                child: Text(
                  '⚠️ Not logged in',
                  style: TextStyle(fontSize: 18, color: Colors.orange),
                ),
              );
            }

            // Success state
            return SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    if (isPremium == true)
                      const Icon(Icons.star, color: Colors.amber, size: 80)
                    else
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                        size: 80,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      isPremium == true ? 'Premium: Yes ✅' : 'Premium: No ❌',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isPremium == true ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // DEBUG INFO
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEBUG INFO:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _debugLine(
                            'UID',
                            FirebaseAuth.instance.currentUser?.uid ?? 'N/A',
                          ),
                          _debugLine('Raw isPremium', rawValue ?? 'null'),
                          _debugLine('Parsed Boolean', isPremium.toString()),
                          if (reason != null) _debugLine('Reason', reason),
                          _debugLine(
                            'Fetched',
                            timestamp?.substring(0, 19) ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        print('[PremiumTest] User clicked Refresh button');
                        setState(() {
                          _premiumStatusFuture = _fetchPremiumStatus();
                        });
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _debugLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
