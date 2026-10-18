import 'package:flutter/material.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'admin@smartcollege.test');
  final password = TextEditingController(text: 'College@123');
  String? error;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final model = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await model.signIn(email.text, password.text);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _SignInCard(model: model, email: email, password: password, error: error, busy: busy, onSubmit: submit, boxed: wide);
    if (!wide) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Align(alignment: Alignment.topCenter, child: TealWave(height: 210)),
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: SchoolMark(size: 108)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text(CollegeColors.schoolName, textAlign: TextAlign.center, style: TextStyle(color: CollegeColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(model.t('Sign in to continue', 'جاری رکھنے کے لیے سائن ان کریں'), textAlign: TextAlign.center, style: TextStyle(color: CollegeColors.muted)),
                  const SizedBox(height: 16),
                  form,
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: CollegeColors.paper,
      body: Row(
        children: [
          Expanded(flex: 11, child: _BrandPanel(model: model)),
          Expanded(flex: 9, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: form))),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CollegeColors.sidebar, CollegeColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SchoolMark(size: 120),
          const Spacer(),
          Text(model.t('SCHOOL MANAGEMENT', 'اسکول مینجمنٹ'), style: const TextStyle(color: Colors.white, letterSpacing: 1.6, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(CollegeColors.schoolName, style: const TextStyle(color: Colors.white, fontSize: 40, height: 1.05, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            model.t('Attendance, fees, exams, and daily college work in one place.', 'حاضری، فیس، امتحان اور روزمرہ کام ایک جگہ۔'),
            style: const TextStyle(color: Color(0xFFFAF7F2), fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final line in [
            model.t('Attendance is marked only after a live face match', 'حاضری صرف زندہ چہرے کے ملنے کے بعد'),
            model.t('Fees, vouchers, and receipts stay in one ledger', 'فیس، واؤچر اور رسیدیں ایک کھاتے میں'),
            model.t('English and Urdu for every role', 'ہر کردار کے لیے انگریزی اور اردو'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: const TextStyle(color: Color(0xFFFAF7F2), height: 1.35))),
                ],
              ),
            ),
          const Spacer(),
          const Text('2026–2027', style: TextStyle(color: Color(0xFFFAF7F2))),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.model,
    required this.email,
    required this.password,
    required this.error,
    required this.busy,
    required this.onSubmit,
    required this.boxed,
  });

  final AppModel model;
  final TextEditingController email;
  final TextEditingController password;
  final String? error;
  final bool busy;
  final VoidCallback onSubmit;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (boxed) Text(model.t('Login', 'لاگ ان'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CollegeColors.primary)),
        if (boxed) const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: model.t('Email', 'ای میل')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) onSubmit();
                },
                decoration: InputDecoration(labelText: model.t('Password', 'پاس ورڈ')),
              ),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: TextStyle(color: CollegeColors.danger))),
              const SizedBox(height: 16),
              FilledButton(onPressed: busy ? null : onSubmit, child: Text(busy ? model.t('Signing in...', 'سائن ان ہو رہا ہے...') : model.t('Sign in', 'سائن ان'))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  model.t('Demo password for every account: College@123\nadmin · teacher · accountant · student · parent', 'ہر اکاؤنٹ کا ڈیمو پاس ورڈ: College@123'),
                  style: TextStyle(color: CollegeColors.muted, fontSize: 13, height: 1.45),
                ),
              ),
      ],
    );
    if (!boxed) return fields;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CollegeColors.line),
        ),
        child: Padding(padding: const EdgeInsets.all(24), child: fields),
      ),
    );
  }
}
