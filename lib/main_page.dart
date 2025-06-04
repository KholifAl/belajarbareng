import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'profile_page.dart';
import 'quiz_page.dart';
import 'materi_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';
import 'dart:async';
import 'package:belajarbersama/utils.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const HomeLayout();
        }
        return const LoginPage();
      },
    );
  }
}

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});
  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  List<Map<String, dynamic>> nearbyUsers = [];
  Timer? _timer;
  Timer? _locationTimer;
  Map? userData;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _updateLocationOnce();
      fetchNearbyUsers();
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        fetchNearbyUsers();
      });
      // Timer untuk update lokasi setiap 30 detik
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updateLocationOnce();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    _removeUserLocation();
    super.dispose();
  }

  Future<void> _removeUserLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'lat': null,
        'lng': null,
        'last_update': null,
      });
    }
  }

  Future<void> _updateLocationOnce() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await saveUserLocation(
          user.uid,
          userData?['name'] ?? 'User',
        );
      } catch (e) {
        debugPrint('Gagal update lokasi: $e');
      }
    }
  }

  Future<void> fetchNearbyUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    Position pos = await Geolocator.getCurrentPosition();
    final snapshot = await FirebaseDatabase.instance.ref('users').get();
    final unreadSnapshot = await FirebaseDatabase.instance
        .ref('users/${user.uid}/unread_chats')
        .get();

    List<Map<String, dynamic>> result = [];
    for (final child in snapshot.children) {
      if (child.key == user.uid) continue;
      final data = child.value as Map;

      // --- Deklarasi di sini! ---
      bool hasChatted = false;

      // Filter hanya user online (last_update < 1 menit)
      final lastUpdate = DateTime.tryParse(data['last_update'] ?? '') ?? DateTime(2000);
      if (DateTime.now().difference(lastUpdate).inMinutes > 1 && !hasChatted) continue;

      double lat = data['lat'];
      double lng = data['lng'];
      double distance = calculateDistance(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );
      bool hasNewChat = false;
      final chatId = _generateChatId(user.uid, child.key!);

      if (unreadSnapshot.exists && child.key != null) {
        final unreadData = Map<String, dynamic>.from(unreadSnapshot.value as Map);
        hasNewChat = unreadData[chatId] == true;
      }

      // Cek apakah sudah pernah chat
      final chatSnapshot = await FirebaseDatabase.instance.ref('chats/$chatId').get();
      if (chatSnapshot.exists) {
        // Cek apakah chat masih aktif (kurang dari 3 jam)
        final lastActivity = DateTime.tryParse(chatSnapshot.child('last_activity').value as String? ?? '') ?? DateTime(2000);
        if (DateTime.now().difference(lastActivity).inHours < 3) {
          hasChatted = true;
        }
      }

      result.add({
        'name': data['name'],
        'distance': distance,
        'uid': child.key,
        'hasNewChat': hasNewChat,
        'hasChatted': hasChatted,
        'photoUrl': data['photoUrl'] ?? '', // tambahkan ini
      });
    }
    setState(() {
      nearbyUsers = result;
    });
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // km
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double distanceFactor = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * distanceFactor;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  Future<void> saveUserLocation(String uid, String name) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }
    Position pos = await Geolocator.getCurrentPosition();
    await FirebaseDatabase.instance.ref('users/$uid').update({
      'name': name,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'last_update': DateTime.now().toIso8601String(),
    });
  }

  String _generateChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();
      if (snapshot.exists) {
        setState(() {
          userData = snapshot.value as Map;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userData?['name'] ?? 'User';
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Halo $displayName',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
              },
              child: CircleAvatar(
                radius: 22,
                backgroundImage: (userData?['photoUrl'] != null && userData?['photoUrl'] != '')
                    ? NetworkImage(transformCloudinaryUrl(userData!['photoUrl']))
                    : null,
                child: (userData?['photoUrl'] == null || userData?['photoUrl'] == '')
                    ? const Icon(Icons.person, size: 22)
                    : null,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Chart dari nilai quiz (dummy data)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Chart Nilai Quiz',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 60),
                              FlSpot(1, 70),
                              FlSpot(2, 80),
                              FlSpot(3, 90),
                              FlSpot(4, 85),
                            ],
                            isCurved: true,
                            barWidth: 4,
                            color: Colors.deepOrange,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const labels = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'Mei',
                                ];
                                return Text(
                                  labels[value.toInt() % labels.length],
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Materi & Quiz
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[200],
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MateriPage()),
                      );
                    },
                    child: const Text(
                      'materi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QuizPage()),
                      );
                    },
                    child: const Text(
                      'quiz',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'nearby',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 12),
            if (nearbyUsers.isEmpty) const Text('Tidak ada user di sekitar.'),
            ...nearbyUsers.map(
              (user) => GestureDetector(
                onTap: () {
                  final currentUser = FirebaseAuth.instance.currentUser!;
                  final otherUserUid = user['uid'];
                  final chatId = _generateChatId(currentUser.uid, otherUserUid);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(chatId: chatId, otherUserUid: otherUserUid),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: (user['photoUrl'] != null && user['photoUrl'] != '')
                                ? NetworkImage(transformCloudinaryUrl(user['photoUrl']))
                                : null,
                            child: (user['photoUrl'] == null || user['photoUrl'] == '')
                                ? const Icon(Icons.person, size: 28)
                                : null,
                          ),
                          if (user['hasNewChat'] == true)
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          if (user['hasChatted'] == true)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${user['distance'].toStringAsFixed(2)} km',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Container();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/${user.uid}').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const CircleAvatar(child: Icon(Icons.person));
        }
        final data = snapshot.data!.snapshot.value as Map;
        final photoUrl = data['photoUrl'] ?? '';
        return CircleAvatar(
          radius: 22,
          backgroundImage: (photoUrl != null && photoUrl != '')
              ? NetworkImage(transformCloudinaryUrl(photoUrl))
              : null,
          child: (photoUrl == null || photoUrl == '')
              ? const Icon(Icons.person, size: 22)
              : null,
        );
      },
    );
  }
}
