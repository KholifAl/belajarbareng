import 'package:flutter/material.dart';

class MateriPage extends StatelessWidget {
  const MateriPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Materi Pembelajaran',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '1. Indonesia adalah negara kepulauan.\n'
              '2. Ibu kota Indonesia adalah Jakarta.\n'
              '3. Bendera Indonesia berwarna Merah Putih.\n'
              '4. Lambang negara adalah Garuda Pancasila.\n'
              '5. Presiden pertama adalah Ir. Soekarno.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}