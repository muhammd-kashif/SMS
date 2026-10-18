import 'dart:async';

import 'package:flutter/material.dart';

import 'data_table.dart';
import 'design.dart';
import 'nav.dart';
import 'screens/camera_page.dart';
import 'screens/home.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class CollegeShell extends StatefulWidget {
  const CollegeShell({super.key});

  @override
  State<CollegeShell> createState() => _CollegeShellState();
}

class _CollegeShellState extends State<CollegeShell> {
  bool wide = true;
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 1024;
    final camera = model.dest == Dest.scan || model.dest == Dest.register;

    wide = desktop;

    return Directionality(
      textDirection: model.urdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Dash.canvas,
        drawer: desktop ? null : _SideDrawer(onPick: () => Navigator.of(context).pop()),
        body: camera
            ? CameraPage(key: ValueKey(model.dest), registering: model.dest == Dest.register)
            : desktop
                ? Row(
                    children: [
                      _Sidebar(collapsed: collapsed, onToggle: () => setState(() => collapsed = !collapsed)),
                      Expanded(
                        child: Builder(
                          builder: (context) => _Workspace(onMenu: () => Scaffold.of(context).openDrawer()),
                        ),
                      ),
                    ],
                  )
                : Builder(
                    builder: (context) => _Workspace(onMenu: () => Scaffold.of(context).openDrawer()),
                  ),
        bottomNavigationBar: camera || desktop ? null : _BottomBar(),
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.onMenu});

  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(onMenu: onMenu),
        const DashDivider(),
        Expanded(
          child: ColoredBox(
            color: Dash.canvas,
            child: const DetailScreen(),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onMenu});

  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final photo = textOf(model.user['face_photo_url']).isEmpty ? textOf(model.user['photo_url']) : textOf(model.user['face_photo_url']);
    final canGoBack = !rootDests.contains(model.dest);

    return Container(
      height: 62,
      color: Dash.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (onMenu != null)
            DashIconButton(icon: Icons.menu_rounded, onPressed: onMenu)
          else if (canGoBack)
            DashIconButton(
              icon: model.urdu ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
              onPressed: () => model.go(backTo(model)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(pageTitle(model), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.ink, fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                Text(CollegeColors.schoolName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.faint, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (!narrow) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: TextField(
                onSubmitted: (value) => _openSearch(context, value),
                style: const TextStyle(fontSize: 13),
                decoration: Dash.input(
                  hint: 'Search students, teachers…',
                  prefix: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          DashIconButton(
            icon: model.urdu ? Icons.translate_rounded : Icons.translate_rounded,
            tooltip: model.urdu ? 'Switch to English' : 'اردو میں دیکھیں',
            onPressed: model.toggleLanguage,
          ),
          const SizedBox(width: 8),
          DashIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onPressed: () => model.go(Dest.notifications),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => model.go(Dest.profile),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(color: Dash.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: Dash.border)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PersonAvatar(name: model.displayName.isEmpty ? model.role : model.displayName, url: photo, size: 28),
                  const SizedBox(width: 8),
                  if (!narrow)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model.displayName.isEmpty ? model.role : model.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        Text(model.role.toUpperCase(), style: TextStyle(color: Dash.faint, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ],
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 16, color: Dash.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearch(BuildContext context, String term) async {
    if (term.trim().isEmpty) return;
    await showDialog<void>(context: context, builder: (context) => _GlobalSearch(initial: term.trim()));
  }
}

class _GlobalSearch extends StatefulWidget {
  const _GlobalSearch({required this.initial});

  final String initial;

  @override
  State<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<_GlobalSearch> {
  final controller = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> people = [];
  bool busy = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    controller.text = widget.initial;
    _run(widget.initial);
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _run(String term) {
    if (term.trim().length < 2) {
      setState(() => people = []);
      return;
    }
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => busy = true);
      try {
        final api = AppScope.of(context).api;
        final students = await api.students();
        final teachers = await api.teachers();
        final needle = term.trim().toLowerCase();
        bool hit(Map<String, dynamic> row) => readValue(row, 'name').toLowerCase().contains(needle) ||
            readValue(row, 'student_code').toLowerCase().contains(needle) ||
            readValue(row, 'employee_code').toLowerCase().contains(needle) ||
            readValue(row, 'email').toLowerCase().contains(needle);
        setState(() {
          people = [
            for (final row in students)
              if (hit(row)) {...row, '_type': 'student'},
            for (final row in teachers)
              if (hit(row)) {...row, '_type': 'teacher'},
          ];
          busy = false;
          message = people.isEmpty ? 'No match in students or teachers.' : '';
        });
      } catch (error) {
        setState(() {
          busy = false;
          message = error.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 620,
        decoration: BoxDecoration(color: Dash.surface, borderRadius: Dash.corners, border: Border.all(color: Dash.border), boxShadow: Dash.shadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: _run,
                style: const TextStyle(fontSize: 14),
                decoration: Dash.input(hint: 'Type at least two letters…', prefix: const Icon(Icons.search_rounded)),
              ),
            ),
            const DashDivider(),
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              child: _results(model),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border))),
              child: Row(
                children: [
                  Expanded(child: Text('${people.length} result${people.length == 1 ? '' : 's'}', style: TextStyle(color: Dash.muted, fontSize: 12, fontWeight: FontWeight.w600))),
                  DashButton(label: 'Close', size: DashSize.sm, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _results(AppModel model) {
    if (busy) return const Center(child: CircularProgressIndicator());
    if (message.isNotEmpty) {
      return Center(child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Dash.muted, fontSize: 13)));
    }
    if (people.isEmpty) {
      return const EmptyState(title: 'Search the college', message: 'Students, teachers, codes and emails are matched.', icon: Icons.person_search_rounded);
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: people.length,
      itemBuilder: (context, index) {
        final row = people[index];
        final isStudent = row['_type'] == 'student';
        final photo = textOf(row['face_photo_url']).isEmpty ? textOf(row['photo_url']) : textOf(row['face_photo_url']);
        final code = readValue(row, 'student_code').isEmpty ? readValue(row, 'employee_code') : readValue(row, 'student_code');
        final detail = [code, readValue(row, 'class_name'), readValue(row, 'email')].where((part) => part.isNotEmpty).join(' · ');
        return ListTile(
          dense: true,
          leading: PersonAvatar(name: readValue(row, 'name'), url: photo, size: 32),
          title: Text(readValue(row, 'name'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          subtitle: Text(detail, style: TextStyle(color: Dash.muted, fontSize: 12)),
          trailing: StatusPill(isStudent ? 'Student' : 'Teacher', tone: DashTone.brand, dense: true),
          onTap: () {
            Navigator.of(context).pop();
            model.go(Dest.students);
          },
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final width = collapsed ? 74.0 : 268.0;

    return Container(
      width: width,
      color: CollegeColors.sidebar,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(model, collapsed),
            const DashDivider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(collapsed ? 10 : 12, 14, collapsed ? 10 : 12, 12),
                children: [
                  for (final group in navGroups(model)) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                        child: Text(
                          group.label.toUpperCase(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                        ),
                      ),
                    for (final item in group.items) _navItem(context, model, item, collapsed),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            const DashDivider(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: collapsed
                  ? DashIconButton(icon: collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, onPressed: onToggle)
                  : Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: model.signOut,
                            icon: const Icon(Icons.logout_rounded, size: 17),
                            label: Text(model.t('Sign out', 'سائن آؤٹ')),
                            style: TextButton.styleFrom(foregroundColor: Colors.white70, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 10)),
                          ),
                        ),
                        DashIconButton(icon: Icons.chevron_left_rounded, onPressed: onToggle),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand(AppModel model, bool isCollapsed) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isCollapsed ? 14 : 16, 16, isCollapsed ? 14 : 16, 14),
      child: Row(
        children: [
          SchoolMark(size: isCollapsed ? 34 : 40),
          if (!isCollapsed) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(CollegeColors.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  Text('Admin desk', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, AppModel model, NavEntry item, bool isCollapsed) {
    final active = _isActive(model.dest, item.dest);
    final content = Material(
      color: active ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => model.go(item.dest),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10),
          alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? Colors.white.withValues(alpha: 0.16) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: isCollapsed ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(item.icon, size: 18, color: active ? Colors.white : Colors.white.withValues(alpha: 0.62)),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : Colors.white.withValues(alpha: 0.72), fontSize: 12.8, fontWeight: active ? FontWeight.w700 : FontWeight.w600))),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: CollegeColors.secondary, borderRadius: BorderRadius.circular(999)),
                    child: Text(item.badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    final item2 = Padding(padding: const EdgeInsets.only(bottom: 3), child: content);
    return isCollapsed ? Tooltip(message: item.label, child: item2) : item2;
  }
}

class _SideDrawer extends StatelessWidget {
  const _SideDrawer({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return Drawer(
      backgroundColor: CollegeColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
              child: Row(
                children: [
                  SchoolMark(size: 38),
                  const SizedBox(width: 11),
                  Expanded(child: Text(CollegeColors.schoolName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800))),
                  IconButton(onPressed: onPick, icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                ],
              ),
            ),
            const DashDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  for (final group in navGroups(model)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                      child: Text(group.label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                    ),
                    for (final item in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Material(
                          color: _isActive(model.dest, item.dest) ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                            onTap: () {
                              onPick();
                              model.go(item.dest);
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(item.icon, size: 18, color: _isActive(model.dest, item.dest) ? Colors.white : Colors.white.withValues(alpha: 0.62)),
                                  const SizedBox(width: 11),
                                  Expanded(child: Text(item.label, style: TextStyle(color: _isActive(model.dest, item.dest) ? Colors.white : Colors.white.withValues(alpha: 0.72), fontSize: 12.8, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const DashDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton.icon(
                onPressed: model.signOut,
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: Text(model.t('Sign out', 'سائن آؤٹ')),
                style: TextButton.styleFrom(foregroundColor: Colors.white70, alignment: Alignment.centerLeft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final family = model.role == 'student' || model.role == 'parent';
    final items = <NavEntry>[
      NavEntry(label: model.t('Home', 'ہوم'), icon: Icons.dashboard_rounded, dest: family ? Dest.portal : Dest.dashboard),
      if (model.role == 'admin' || model.role == 'teacher') NavEntry(label: model.t('Scan', 'اسکین'), icon: Icons.photo_camera_rounded, dest: Dest.scan),
      NavEntry(label: model.t('People', 'لوگ'), icon: Icons.groups_rounded, dest: Dest.students),
      if (model.role == 'admin' || model.role == 'accountant' || family) NavEntry(label: model.t('Fees', 'فیس'), icon: Icons.payments_rounded, dest: Dest.fees),
      NavEntry(label: model.t('More', 'مزید'), icon: Icons.grid_view_rounded, dest: Dest.more),
    ];

    return Container(
      decoration: BoxDecoration(color: Dash.surface, border: Border(top: BorderSide(color: Dash.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: InkWell(
                    onTap: () => model.go(item.dest),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 20, color: _isActive(model.dest, item.dest) ? Dash.brand : Dash.faint),
                        const SizedBox(height: 3),
                        Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _isActive(model.dest, item.dest) ? Dash.brand : Dash.faint)),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    ),
    );
  }

}

bool _isActive(Dest current, Dest item) {
  if (item == Dest.dashboard || item == Dest.portal) return current == Dest.dashboard || current == Dest.portal;
  if (item == Dest.students) {
    return current == Dest.students || current == Dest.teachers || current == Dest.classes || current == Dest.studentProfile || current == Dest.studentForm;
  }
  if (item == Dest.fees) return current == Dest.fees || current == Dest.collect;
  if (item == Dest.more) return !rootDests.contains(current) && current != Dest.students && current != Dest.teachers && current != Dest.classes && current != Dest.studentProfile && current != Dest.studentForm && current != Dest.fees && current != Dest.collect && current != Dest.scan && current != Dest.register;
  return current == item;
}

Dest backTo(AppModel model) {
  if (model.dest == Dest.studentProfile || model.dest == Dest.studentForm) return Dest.students;
  if (model.dest == Dest.collect) return Dest.fees;
  if (model.dest == Dest.teachers || model.dest == Dest.classes) return Dest.students;
  return Dest.more;
}

String pageTitle(AppModel model) => switch (model.dest) {
      Dest.dashboard => model.t('Dashboard', 'ڈیش بورڈ'),
      Dest.portal => model.t('My portal', 'میرا پورٹل'),
      Dest.students => model.t('Students', 'طلبہ'),
      Dest.studentProfile => model.t('Student profile', 'طالب علم کی تفصیل'),
      Dest.studentForm => model.t('Admission', 'داخلہ'),
      Dest.teachers => model.t('Teachers', 'اساتذہ'),
      Dest.classes => model.t('Classes', 'کلاسز'),
      Dest.timetable => model.t('Timetable', 'ٹائم ٹیبل'),
      Dest.scan => model.t('Face scan', 'چہرہ اسکین'),
      Dest.register => model.t('Face register', 'چہرہ رجسٹر'),
      Dest.attendance => model.t('Attendance', 'حاضری'),
      Dest.fees => model.t('Fees', 'فیس'),
      Dest.collect => model.t('Collect fee', 'فیس وصول'),
      Dest.exams => model.t('Exams', 'امتحانات'),
      Dest.test => model.t('Class test', 'کلاس ٹیسٹ'),
      Dest.results => model.t('Results', 'نتائج'),
      Dest.leaves => model.t('Leaves', 'چھٹیاں'),
      Dest.homework => model.t('Homework', 'ہوم ورک'),
      Dest.assignments => model.t('Assignments', 'اسائنمنٹس'),
      Dest.announcements => model.t('Announcements', 'اعلانات'),
      Dest.notifications => model.t('Notifications', 'اطلاعات'),
      Dest.reports => model.t('Reports', 'رپورٹس'),
      Dest.more => model.t('All modules', 'تمام ماڈیولز'),
      Dest.profile => model.t('Profile', 'پروفائل'),
      Dest.settings => model.t('Settings', 'ترتیبات'),
    };
