import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final List<Map<String, dynamic>> questions = [
    {
      'q': 'Apa ibu kota Indonesia?',
      'options': ['Bandung', 'Surabaya', 'Jakarta', 'Medan'],
      'answer': 2,
    },
    {
      'q': '2 + 2 = ?',
      'options': ['2', '3', '4', '5'],
      'answer': 2,
    },
    {
      'q': 'Warna bendera Indonesia?',
      'options': ['Merah Kuning', 'Merah Putih', 'Putih Biru', 'Hijau Merah'],
      'answer': 1,
    },
    {
      'q': 'Siapa presiden pertama RI?',
      'options': ['Soekarno', 'Soeharto', 'Habibie', 'Jokowi'],
      'answer': 0,
    },
    {
      'q': 'Lambang negara Indonesia?',
      'options': ['Harimau', 'Elang', 'Garuda', 'Rajawali'],
      'answer': 2,
    },
  ];

  List<int?> selected = List.filled(5, null);
  int? score;

  void _submitQuiz() async {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selected[i] == questions[i]['answer']) correct++;
    }
    setState(() {
      score = correct;
    });

    // Push hasil ke Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance
          .ref('quiz_results/${user.uid}')
          .push()
          .set({
            'score': correct,
            'total': questions.length,
            'timestamp': DateTime.now().toIso8601String(),
          });
    }

    // Kembali ke main_page.dart setelah submit
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${questions[i]['q']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(4, (j) {
                          final abcd = ['a', 'b', 'c', 'd'];
                          return RadioListTile<int>(
                            value: j,
                            groupValue: selected[i],
                            onChanged: (val) {
                              setState(() {
                                selected[i] = val;
                              });
                            },
                            title: Text(
                              '${abcd[j]}. ${questions[i]['options'][j]}',
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (score != null)
              Text(
                'Skor kamu: $score / ${questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: selected.contains(null) ? null : _submitQuiz,
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}
