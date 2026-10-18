import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late Future<List<_Paper>> future;
  var started = false;
  var index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    future = _load();
  }

  Future<List<_Paper>> _load() async {
    final exams = await AppScope.of(context).api.exams();
    final papers = <_Paper>[];
    for (final exam in exams) {
      final name = textOf(exam['name']).ifBlank('Exam');
      final schedules = exam['schedules'];
      if (schedules is List && schedules.isNotEmpty) {
        for (final row in schedules) {
          if (row is! Map) continue;
          final subject = row['subject'];
          final subjectName = subject is Map ? textOf(subject['name']) : textOf(row['subject_name']);
          papers.add(_Paper(exam: name, subject: subjectName.ifBlank('Paper'), date: textOf(row['exam_date'])));
        }
      } else {
        papers.add(_Paper(exam: name, subject: name, date: textOf(exam['start_date'])));
      }
    }
    return papers;
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return FutureBuilder<List<_Paper>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const CollegeLoader();
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error.toString(), style: TextStyle(color: CollegeColors.danger))));
        final papers = snapshot.data ?? [];
        if (papers.isEmpty) {
          return Center(child: Text(model.t('No exam papers yet.', 'ابھی کوئی پیپر نہیں۔'), style: TextStyle(color: CollegeColors.muted)));
        }
        final safe = index.clamp(0, papers.length - 1);
        final paper = papers[safe];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text(model.t('Class test', 'کلاس ٹیسٹ'), style: TextStyle(color: CollegeColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            Text(paper.subject, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 6),
            Text('${paper.exam}${paper.date.isEmpty ? '' : ' · ${paper.date}'}', style: TextStyle(color: CollegeColors.muted)),
            const SizedBox(height: 8),
            Text(model.t('Paper ${safe + 1} of ${papers.length}', 'پیپر ${safe + 1} / ${papers.length}'), style: TextStyle(color: CollegeColors.muted, fontSize: 13)),
            const SizedBox(height: 18),
            for (var i = 0; i < papers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: i == safe ? CollegeColors.primary : CollegeColors.blueBg,
                      foregroundColor: i == safe ? Colors.white : CollegeColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => setState(() => index = i),
                    child: Text(papers[i].subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => model.go(Dest.results),
              child: Text(model.t('Open results', 'نتائج کھولیں')),
            ),
          ],
        );
      },
    );
  }
}

class _Paper {
  const _Paper({required this.exam, required this.subject, required this.date});
  final String exam;
  final String subject;
  final String date;
}

extension on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
