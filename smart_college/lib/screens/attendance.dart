import 'package:flutter/material.dart';
import '../data_table.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  late Future<Map<String, dynamic>> health;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    health = AppScope.of(context).api.faceHealth();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final camera = _Camera(status: model.t('Camera scan runs in the web desk', 'کیمرہ اسکین ویب ڈیسک پر چلتا ہے'), detail: model.t('This app checks the face service, then the web desk marks the matching person.', 'یہ ایپ فیس سروس چیک کرتی ہے، پھر ویب ڈیسک ملتے ہوئے شخص کی حاضری لگاتی ہے۔'));
    final side = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: health,
          builder: (context, snapshot) {
            final ok = snapshot.data?['ok'] == true || snapshot.data?['status'] == 'ok';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model.t('Face service', 'فیس سروس'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (snapshot.connectionState != ConnectionState.done) const CircularProgressIndicator(),
                if (snapshot.hasError) Text(snapshot.error.toString(), style: TextStyle(color: CollegeColors.danger)),
                if (snapshot.hasData) SoftBadge(ok ? model.t('Online', 'آن لائن') : model.t('Offline', 'آف لائن'), tone: ok ? BadgeTone.ok : BadgeTone.bad),
                const SizedBox(height: 12),
                Text(model.t('A different face stays unrecognized and does not mark this person.', 'دوسرا چہرہ پہچانا نہیں جاتا اور اس شخص کی حاضری نہیں لگتی۔'), style: TextStyle(color: CollegeColors.muted)),
              ],
            );
          },
        ),
      ),
    );
    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHead(title: model.t('Face attendance', 'چہرے سے حاضری'), subtitle: model.t('Attendance is marked only after the live face matches a saved face', 'حاضری صرف اس وقت لگتی ہے جب زندہ چہرہ محفوظ چہرے سے ملے')),
          Expanded(child: _Split(primary: camera, secondary: side)),
        ],
      ),
    );
  }
}

class FaceRegisterScreen extends StatefulWidget {
  const FaceRegisterScreen({super.key});

  @override
  State<FaceRegisterScreen> createState() => _FaceRegisterScreenState();
}

class _FaceRegisterScreenState extends State<FaceRegisterScreen> {
  int samples = 0;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final steps = [
      model.t('Look straight', 'سیدھا دیکھیں'),
      model.t('Turn slightly left', 'تھوڑا بائیں مڑیں'),
      model.t('Turn slightly right', 'تھوڑا دائیں مڑیں'),
      model.t('Tilt slightly up', 'تھوڑا اوپر جھکائیں'),
      model.t('Tilt slightly down', 'تھوڑا نیچے جھکائیں'),
    ];
    final camera = _Camera(status: model.t('Use the web desk camera to save a face', 'چہرہ محفوظ کرنے کے لیے ویب ڈیسک کا کیمرہ استعمال کریں'), detail: model.t('Nothing is stored until Save this face is pressed there.', 'وہاں محفوظ کریں دبانے سے پہلے کچھ محفوظ نہیں ہوتا۔'));
    final side = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.displayName.isEmpty ? model.t('Choose a person on the web desk', 'ویب ڈیسک پر شخص منتخب کریں') : model.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${steps[i]}', style: TextStyle(color: i < samples ? CollegeColors.ok : CollegeColors.muted, fontWeight: i < samples ? FontWeight.w700 : FontWeight.w400)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: null,
              child: Text(model.t('Save this face', 'یہ چہرہ محفوظ کریں')),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHead(title: model.t('Face registration', 'چہرہ رجسٹریشن'), subtitle: model.t('Five views, then Save this face', 'پانچ تصاویر، پھر یہ چہرہ محفوظ کریں')),
          Expanded(child: _Split(primary: camera, secondary: side)),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    if (!wide) {
      return Column(
        children: [
          Expanded(child: primary),
          const SizedBox(height: 12),
          secondary,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 11, child: primary),
        const SizedBox(width: 12),
        Expanded(flex: 8, child: secondary),
      ],
    );
  }
}

class _Camera extends StatelessWidget {
  const _Camera({required this.status, required this.detail});

  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0B1C33), borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Center(child: SizedBox(width: 180, height: 230, child: DecoratedBox(decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: CollegeColors.secondary, width: 3)), borderRadius: const BorderRadius.all(Radius.elliptical(90, 115)))))),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(status, style: const TextStyle(fontWeight: FontWeight.w700)), if (detail.isNotEmpty) Text(detail)]),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return RemoteTable(
      title: model.t('Student attendance', 'طلبہ کی حاضری'),
      subtitle: model.t('Arrival by 08:15 is Present. A later arrival is Late.', '08:15 تک آمد حاضر ہے۔ اس کے بعد دیر ہے۔'),
      load: () async {
        if (model.role == 'student' || model.role == 'parent') {
          final portal = await model.api.portal();
          return model.api.asRows(portal['attendance_history']);
        }
        return model.api.attendance();
      },
      columns: [model.t('Name', 'نام'), model.t('Date', 'تاریخ'), model.t('Status', 'حالت'), model.t('Check in', 'آمد')],
      cells: (row) => [
        Text(textOf(row['name']).isEmpty ? textOf(row['date']) : textOf(row['name'])),
        Text(textOf(row['date'])),
        SoftBadge(textOf(row['status']), tone: textOf(row['status']) == 'absent' ? BadgeTone.bad : textOf(row['status']) == 'late' ? BadgeTone.warn : BadgeTone.ok),
        Text(textOf(row['check_in'])),
      ],
    );
  }
}
