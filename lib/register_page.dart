import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController namaController = TextEditingController();
  String? errorMessage;

  Future<void> register() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Setelah register berhasil:
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Simpan ke Realtime Database (sudah ada)
        await FirebaseDatabase.instance.ref('users/${user.uid}').set({
          'name': namaController.text.trim(),
          'email': user.email,
          'created_at': DateTime.now().toIso8601String(),
          'photoUrl': null, // tambahkan baris ini
        });

        // Simpan ke Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nama': namaController.text.trim(),
          'uid': user.uid,
          'created': FieldValue.serverTimestamp(),
        });
      }

      Navigator.of(context).pop(); // Kembali ke login setelah register
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (errorMessage != null)
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: namaController,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: register, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}
