import 'package:flutter/material.dart';

class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    final questions = [
      'Apa ibu kota Indonesia?',
      '2 + 2 = ?',
      'Warna bendera Indonesia?',
      'Siapa presiden pertama RI?',
      'Lambang negara Indonesia?',
    ];
    final answers = [
      'Jakarta',
      '4',
      'Merah Putih',
      'Soekarno',
      'Garuda',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(questions[i]),
            subtitle: Text('Jawaban: ${answers[i]}'),
          ),
        ),
      ),
    );
  }
}