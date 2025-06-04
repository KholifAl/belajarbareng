import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';
import 'main_page.dart';
import 'package:belajarbersama/utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<String?> uploadToCloudinary(XFile file) async {
  const cloudName = 'dc3c8a2rv'; // ganti dengan cloud_name milikmu dari Cloudinary
  const uploadPreset = 'belajarbersama';

  final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final bytes = await file.readAsBytes();
  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));

  final response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    final data = json.decode(respStr);
    return data['secure_url'];
  } else {
    return null;
  }
}

Future<String?> uploadToCloudinaryBytes(List<int> bytes, String filename) async {
  const cloudName = 'dc3c8a2rv';
  const uploadPreset = 'belajarbersama';

  final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

  final response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    final data = json.decode(respStr);
    return data['secure_url'];
  } else {
    return null;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          loading = false;
        });
      } else {
        setState(() {
          userData = {};
          loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    List<int> bytes = await picked.readAsBytes();

    // Jika file > 500 KB, kompres dulu
    if (bytes.length > 500 * 1024) {
      int quality = 80;
      List<int>? compressedBytes;
      do {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          picked.path,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        quality -= 10;
      } while (compressedBytes != null && compressedBytes.length > 500 * 1024 && quality > 10);

      if (compressedBytes != null && compressedBytes.length < bytes.length) {
        bytes = compressedBytes;
      }
    }

    // Upload ke Cloudinary
    final url = await uploadToCloudinaryBytes(bytes, picked.name);
    if (url != null) {
      await FirebaseDatabase.instance.ref('users/${user.uid}/photoUrl').set(url);
      setState(() {
        userData?['photoUrl'] = url;
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload ke Cloudinary gagal!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: (userData?['photoUrl'] != null && userData?['photoUrl'] != '')
                      ? NetworkImage(userData!['photoUrl'])
                      : null,
                  child: (userData?['photoUrl'] == null || userData?['photoUrl'] == '')
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickAndUploadPhoto,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.edit, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              userData?['name'] ?? user?.displayName ?? 'User',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              userData?['email'] ?? user?.email ?? '-',
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainPage()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
