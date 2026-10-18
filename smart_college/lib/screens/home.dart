import 'package:flutter/material.dart';

import '../design.dart';
import '../nav.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'office.dart';
import 'people.dart';
import 'records.dart';
import 'attendance.dart';
import 'test_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> future;
  var started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final model = AppScope.of(context);
    final family = model.role == 'student' || model.role == 'parent';
    future = family ? model.api.portal() : model.api.dashboard();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final family = model.role == 'student' || model.role == 'parent';
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final attendance = data['attendance'] is Map ? Map<String, dynamic>.from(data['attendance'] as Map) : <String, dynamic>{};
        final fees = data['fees'] is Map ? Map<String, dynamic>.from(data['fees'] as Map) : <String, dynamic>{};
        final student = data['student'] is Map ? Map<String, dynamic>.from(data['student'] as Map) : <String, dynamic>{};
        if (snapshot.connectionState != ConnectionState.done) return const CollegeLoader();
        final name = family ? textOf(student['name']).ifEmpty(model.displayName) : model.displayName;
        final modules = _modules(model, family);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: 236,
              child: Stack(
                children: [
                  Align(alignment: Alignment.topCenter, child: TealWave(height: 210)),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 4,
                    right: 8,
                    child: IconButton(
                      onPressed: () => model.go(Dest.profile),
                      icon: PersonAvatar(name: name, url: textOf(model.user['face_photo_url']).isEmpty ? textOf(model.user['photo_url']) : textOf(model.user['face_photo_url']), size: 36),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: MediaQuery.paddingOf(context).top + 28,
                    child: Column(
                      children: [
                        const SchoolMark(size: 96),
                        const SizedBox(height: 8),
                        Text(CollegeColors.shortName, style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(child: _Stat(model.t('Present', 'حاضر'), textOf(attendance['present']), const Color(0xFF166534), const Color(0xFFE8F6EE))),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(model.t('Late', 'دیر'), textOf(attendance['late']), const Color(0xFF1565C0), const Color(0xFFE8F1FB))),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(model.t('Pending', 'باقی'), textOf(fees['pending']), const Color(0xFF9F1239), const Color(0xFFFFF1F2))),
                ],
              ),
            ),
            if (snapshot.hasError) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(snapshot.error.toString(), style: TextStyle(color: CollegeColors.danger))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(model.t('School desk', 'اسکول ڈیسک'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980 ? 6 : constraints.maxWidth >= 640 ? 4 : 3;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.86,
                    children: [for (final item in modules) _ModuleTile(item: item, onTap: () => model.go(item.dest))],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.ink, this.wash);

  final String label;
  final String value;
  final Color ink;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(99)),
              child: Text(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: CollegeColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Mod {
  const _Mod(this.icon, this.label, this.dest);
  final IconData icon;
  final String label;
  final Dest dest;
}

List<_Mod> _modules(AppModel model, bool family) {
  return [
    if (!family) _Mod(Icons.groups, model.t('Students', 'طلبہ'), Dest.students),
    if (model.role == 'admin') _Mod(Icons.school, model.t('Teachers', 'اساتذہ'), Dest.teachers),
    if (!family) _Mod(Icons.class_outlined, model.t('Classes', 'کلاسز'), Dest.classes),
    _Mod(Icons.fact_check, model.t('Attendance', 'حاضری'), family ? Dest.attendance : Dest.scan),
    if (model.role == 'admin' || model.role == 'teacher') _Mod(Icons.how_to_reg, model.t('Register', 'رجسٹر'), Dest.register),
    if (model.role == 'admin' || model.role == 'accountant' || family) _Mod(Icons.payments, model.t('Fees', 'فیس'), Dest.fees),
    if (model.role == 'admin' || model.role == 'accountant') _Mod(Icons.point_of_sale, model.t('Collect', 'وصول'), Dest.collect),
    if (model.role == 'admin') _Mod(Icons.person_add_alt_1, model.t('Admit', 'داخلہ'), Dest.studentForm),
    _Mod(Icons.quiz_outlined, model.t('Exams', 'امتحانات'), Dest.exams),
    _Mod(Icons.rule, model.t('Test', 'ٹیسٹ'), Dest.test),
    _Mod(Icons.emoji_events_outlined, model.t('Results', 'نتائج'), Dest.results),
    _Mod(Icons.menu_book, model.t('Homework', 'ہوم ورک'), Dest.homework),
    _Mod(Icons.assignment_outlined, model.t('Tasks', 'کام'), Dest.assignments),
    _Mod(Icons.calendar_month, model.t('Timetable', 'ٹائم ٹیبل'), Dest.timetable),
    _Mod(Icons.event_busy, model.t('Leaves', 'چھٹیاں'), Dest.leaves),
    _Mod(Icons.campaign_outlined, model.t('Notices', 'اعلانات'), Dest.announcements),
    _Mod(Icons.notifications_none, model.t('Alerts', 'اطلاعات'), Dest.notifications),
    if (model.role == 'admin' || model.role == 'accountant') _Mod(Icons.bar_chart, model.t('Reports', 'رپورٹس'), Dest.reports),
    if (model.role == 'admin') _Mod(Icons.settings, model.t('Settings', 'ترتیبات'), Dest.settings),
    _Mod(Icons.person_outline, model.t('Profile', 'پروفائل'), Dest.profile),
  ];
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.item, required this.onTap});

  final _Mod item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: CollegeColors.dark ? const Color(0xFF162033) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CollegeColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: CollegeColors.blueBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(item.icon, color: CollegeColors.primary, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.15)),
            ),
          ],
        ),
      ),
    );
  }
}


class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final groups = navGroups(model)
        .where((group) => group.label != 'Overview' && group.label != 'System')
        .toList();

    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: model.t('All modules', 'تمام ماڈیولز'),
          subtitle: model.t('Every part of the college, grouped the way the desk works.', 'ڈیسک کی طرح ترتیب شدہ تمام ماڈیولز۔'),
          breadcrumb: [model.t('Overview', 'تعارف'), model.t('All modules', 'تمام ماڈیولز')],
        ),
        const SizedBox(height: 14),
        for (final group in groups) ...[
          Panel(
            title: group.label,
            icon: _groupIcon(group.label),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < group.items.length; i++) ...[
                  if (i > 0) const DashDivider(),
                  _MoreRow(item: group.items[i], onTap: () => model.go(group.items[i].dest)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Panel(
          title: model.t('Session', 'سیشن'),
          icon: Icons.logout_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${model.displayName.isEmpty ? model.role : model.displayName}  ·  ${model.role.toUpperCase()}',
                style: TextStyle(color: Dash.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              DashButton(
                label: model.t('Sign out', 'سائن آؤٹ'),
                icon: Icons.logout_rounded,
                variant: DashVariant.danger,
                onPressed: model.signOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _groupIcon(String label) => switch (label) {
        'People' => Icons.groups_rounded,
        'Academics' => Icons.school_rounded,
        'Operations' => Icons.settings_suggest_rounded,
        'Communication' => Icons.campaign_rounded,
        _ => Icons.grid_view_rounded,
      };
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.item, required this.onTap});

  final NavEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Dash.cornersSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              IconSquare(icon: item.icon, tone: DashTone.brand, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Dash.ink, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Dash.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final page = switch (model.dest) {
      Dest.students => const StudentsScreen(),
      Dest.studentProfile => const StudentProfileScreen(),
      Dest.studentForm => const StudentFormScreen(),
      Dest.teachers => const TeachersScreen(),
      Dest.classes => const ClassesScreen(),
      Dest.timetable => OfficeScreens.timetable(model),
      Dest.attendance => const AttendanceScreen(),
      Dest.fees => const FeesScreen(),
      Dest.collect => const CollectFeeScreen(),
      Dest.exams => OfficeScreens.exams(model),
      Dest.test => const TestScreen(),
      Dest.results => OfficeScreens.results(model),
      Dest.leaves => OfficeScreens.leaves(model),
      Dest.homework => OfficeScreens.homework(model),
      Dest.assignments => OfficeScreens.assignments(model),
      Dest.announcements => OfficeScreens.announcements(model),
      Dest.notifications => OfficeScreens.notifications(model),
      Dest.reports => OfficeScreens.reports(model),
      Dest.profile => OfficeScreens.profile(model),
      Dest.settings => OfficeScreens.settings(model),
      _ => const MoreScreen(),
    };
    return page;
  }

}
