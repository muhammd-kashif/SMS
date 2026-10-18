import 'package:flutter/material.dart';
import '../data_table.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
class OfficeScreens {
  static Widget exams(AppModel model) => RemoteTable(
        title: model.t('Examinations', 'امتحانات'),
        subtitle: model.t('Loaded from /api/exams', '/api/exams سے'),
        load: () => familyList(model, 'exams', model.api.exams),
        columns: [model.t('Exam', 'امتحان'), model.t('Class', 'کلاس'), model.t('Starts', 'آغاز'), model.t('Status', 'حالت')],
        cells: (row) => [
          Text(textOf(row['name'])),
          Text(nested(row, ['schoolClass', 'name'])),
          Text(textOf(row['start_date'])),
          SoftBadge(row['published'] == true ? model.t('Published', 'شائع') : model.t('Draft', 'مسودہ'), tone: BadgeTone.blue),
        ],
      );

  static Widget results(AppModel model) => ResultsScreen(model: model);

  static Widget resultsTable(AppModel model) => RemoteTable(
        title: model.t('Results', 'نتائج'),
        subtitle: model.t('First published exam from the API', 'API کا پہلا شائع امتحان'),
        load: () async {
          if (familyRole(model)) return familyList(model, 'results', model.api.exams);
          final exams = await model.api.exams();
          if (exams.isEmpty) return [];
          return model.api.results(exams.first['id'] as int);
        },
        columns: [model.t('Student', 'طالب علم'), model.t('Percent', 'فیصد'), model.t('Grade', 'گریڈ'), model.t('Result', 'نتیجہ')],
        cells: (row) => [
          Text(textOf(row['name'] ?? row['exam'])),
          Text(textOf(row['percentage'])),
          Text(textOf(row['grade'])),
          SoftBadge(textOf(row['result'])),
        ],
      );

  static Widget leaves(AppModel model) => LeavesScreen(model: model);

  static Widget leavesOld(AppModel model) => RemoteTable(
        title: model.t('Leaves', 'چھٹیاں'),
        subtitle: model.t('Loaded from /api/leaves', '/api/leaves سے'),
        load: () => familyList(model, 'leaves', model.api.leaves),
        columns: [model.t('Student', 'طالب علم'), model.t('Dates', 'تاریخ'), model.t('Days', 'دن'), model.t('Reason', 'وجہ'), model.t('Status', 'حالت')],
        cells: (row) => [
          Text(nested(row, ['student', 'user', 'name'])),
          Text('${textOf(row['start_date'])} – ${textOf(row['end_date'])}'),
          Text(textOf(row['days'])),
          Text(textOf(row['reason'])),
          SoftBadge(textOf(row['status']), tone: textOf(row['status']) == 'approved' ? BadgeTone.ok : BadgeTone.warn),
        ],
      );

  static Widget timetable(AppModel model) => RemoteTable(
        title: model.t('Timetable', 'ٹائم ٹیبل'),
        subtitle: model.t('Loaded from /api/timetable', '/api/timetable سے'),
        load: () => familyList(model, 'timetable', model.api.timetable),
        columns: [model.t('Time', 'وقت'), model.t('Subject', 'مضمون'), model.t('Teacher', 'استاد'), model.t('Class', 'کلاس')],
        cells: (row) => [
          Text(textOf(row['start_time'])),
          Text(nested(row, ['subject', 'name'])),
          Text(nested(row, ['teacher', 'user', 'name'])),
          Text(nested(row, ['schoolClass', 'name'])),
        ],
      );

  static Widget homework(AppModel model) => RemoteTable(
        title: model.t('Homework', 'ہوم ورک'),
        subtitle: model.t('Loaded from /api/homework', '/api/homework سے'),
        load: () => familyList(model, 'homework', model.api.homework),
        columns: [model.t('Class', 'کلاس'), model.t('Subject', 'مضمون'), model.t('Title', 'عنوان'), model.t('Due', 'آخری تاریخ')],
        cells: (row) => [
          Text(nested(row, ['schoolClass', 'name'])),
          Text(nested(row, ['subject', 'name'])),
          Text(textOf(row['title'])),
          Text(textOf(row['due_date'])),
        ],
      );

  static Widget assignments(AppModel model) => RemoteTable(
        title: model.t('Assignments', 'اسائنمنٹس'),
        subtitle: model.t('Loaded from /api/assignments', '/api/assignments سے'),
        load: () => familyList(model, 'assignments', model.api.assignments),
        columns: [model.t('Class', 'کلاس'), model.t('Subject', 'مضمون'), model.t('Title', 'عنوان'), model.t('Due', 'آخری تاریخ')],
        cells: (row) => [
          Text(nested(row, ['schoolClass', 'name'])),
          Text(nested(row, ['subject', 'name'])),
          Text(textOf(row['title'])),
          Text(textOf(row['due_date'])),
        ],
      );

  static Widget announcements(AppModel model) => AnnouncementsScreen(model: model);

  static Widget announcementsTable(AppModel model) => RemoteTable(
        title: model.t('Announcements', 'اعلانات'),
        subtitle: model.t('Loaded from the college API', 'کالج API سے'),
        load: () => familyList(model, 'announcements', model.api.announcements),
        columns: [model.t('Title', 'عنوان'), model.t('Audience', 'سامعین'), model.t('Status', 'حالت')],
        cells: (row) => [
          Text(textOf(row['title'])),
          Text(textOf(row['audience'])),
          SoftBadge(row['published'] == true ? model.t('Published', 'شائع') : model.t('Draft', 'مسودہ'), tone: BadgeTone.blue),
        ],
      );

  static Widget notifications(AppModel model) => RemoteTable(
        title: model.t('Notifications', 'اطلاعات'),
        subtitle: model.t('Loaded from /api/notifications', '/api/notifications سے'),
        load: model.api.notifications,
        columns: [model.t('Title', 'عنوان'), model.t('Message', 'پیغام'), model.t('Status', 'حالت')],
        cells: (row) => [
          Text(textOf(row['title'])),
          Text(textOf(row['body'] ?? row['message'])),
          SoftBadge(row['read_at'] == null ? model.t('Unread', 'ناخواندہ') : model.t('Read', 'پڑھی گئی'), tone: row['read_at'] == null ? BadgeTone.warn : BadgeTone.ok),
        ],
      );

  static Widget reports(AppModel model) => ReportsScreen(model: model);

  static Widget portal(AppModel model) => const PortalScreen();

  static Widget profile(AppModel model) => const ProfileScreen();

  static Widget settings(AppModel model) => const SettingsScreen();
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({required this.model, super.key});

  final AppModel model;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<List<Map<String, dynamic>>> examsFuture;
  int? examId;

  @override
  void initState() {
    super.initState();
    examsFuture = familyRole(widget.model) ? Future.value([]) : widget.model.api.exams();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    if (familyRole(model)) {
      return RemoteTable(
        title: model.t('Results', 'نتائج'),
        subtitle: model.t('From your portal', 'آپ کے پورٹل سے'),
        load: () => familyList(model, 'results', model.api.exams),
        columns: [model.t('Student', 'طالب علم'), model.t('Percent', 'فیصد'), model.t('Grade', 'گریڈ'), model.t('Result', 'نتیجہ')],
        cells: (row) => [
          Text(textOf(row['name'] ?? row['exam'])),
          Text(textOf(row['percentage'])),
          Text(textOf(row['grade'])),
          SoftBadge(textOf(row['result']), tone: BadgeTone.blue),
        ],
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: examsFuture,
      builder: (context, snapshot) {
        final exams = snapshot.data ?? [];
        final selected = examId ?? (exams.isEmpty ? null : exams.first['id'] as int?);
        return Column(
          children: [
            if (exams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<int>(
                  initialValue: selected,
                  decoration: InputDecoration(labelText: model.t('Exam', 'امتحان')),
                  items: [
                    for (final exam in exams)
                      DropdownMenuItem(value: exam['id'] as int, child: Text(textOf(exam['name']))),
                  ],
                  onChanged: (value) => setState(() => examId = value),
                ),
              ),
            Expanded(
              child: RemoteTable(
                key: ValueKey(selected),
                title: model.t('Results', 'نتائج'),
                subtitle: exams.isEmpty ? model.t('No exams yet', 'ابھی کوئی امتحان نہیں') : textOf(exams.where((exam) => exam['id'] == selected).map((exam) => exam['name']).firstOrNull),
                load: () => selected == null ? Future.value([]) : model.api.results(selected),
                columns: [model.t('Photo', 'تصویر'), model.t('Student', 'طالب علم'), model.t('Percent', 'فیصد'), model.t('Grade', 'گریڈ'), model.t('Result', 'نتیجہ')],
                cells: (row) => [
                  PersonAvatar(name: textOf(row['name']), url: textOf(row['face_photo_url']).isEmpty ? textOf(row['photo_url']) : textOf(row['face_photo_url']), size: 36),
                  Text(textOf(row['name'] ?? row['exam'])),
                  Text('${textOf(row['percentage'])}%'),
                  Text(textOf(row['grade'])),
                  SoftBadge(textOf(row['result']), tone: BadgeTone.blue),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.model, super.key});

  final AppModel model;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const types = ['students', 'attendance', 'fees', 'payments', 'defaulters', 'exams', 'leaves'];
  var type = 'students';

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: model.t('Report', 'رپورٹ')),
            items: [for (final item in types) DropdownMenuItem(value: item, child: Text(model.t(item, item)))],
            onChanged: (value) {
              if (value == null) return;
              setState(() => type = value);
            },
          ),
        ),
        Expanded(
          child: RemoteTable(
            key: ValueKey(type),
            title: model.t('Reports', 'رپورٹس'),
            subtitle: type,
            load: () => model.api.reports(type),
            columns: const [],
            cells: (row) {
              final bits = <Widget>[];
              for (final entry in row.entries) {
                if (entry.value is Map || entry.value is List) continue;
                final text = textOf(entry.value);
                if (text.isEmpty) continue;
                bits.add(Text(text, style: const TextStyle(fontSize: 13)));
                if (bits.length == 5) break;
              }
              return bits.isEmpty ? [const Text('—')] : bits;
            },
          ),
        ),
      ],
    );
  }
}

bool familyRole(AppModel model) => model.role == 'student' || model.role == 'parent';

Future<List<Map<String, dynamic>>> familyList(AppModel model, String key, Future<List<Map<String, dynamic>>> Function() staff) async {
  if (!familyRole(model)) return staff();
  final data = await model.api.portal();
  return model.api.asRows(data[key]);
}

class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  late Future<Map<String, dynamic>> future;
  var started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    future = AppScope.of(context).api.portal();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const CollegeLoader();
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final student = snapshot.data?['student'] is Map ? Map<String, dynamic>.from(snapshot.data!['student'] as Map) : <String, dynamic>{};
        final attendance = snapshot.data?['attendance'] is Map ? Map<String, dynamic>.from(snapshot.data!['attendance'] as Map) : <String, dynamic>{};
        final fees = snapshot.data?['fees'] is Map ? Map<String, dynamic>.from(snapshot.data!['fees'] as Map) : <String, dynamic>{};
        final photo = textOf(student['face_photo_url']).isEmpty ? textOf(student['photo_url']) : textOf(student['face_photo_url']);
        final name = textOf(student['name']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  PersonAvatar(name: name, url: photo, size: 84),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    Text('${textOf(student['student_code'])} · ${textOf(student['class_name'])} — ${textOf(student['section_name'])}', style: TextStyle(color: CollegeColors.muted)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 4 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(width: width, child: Kpi(model.t('Attendance', 'حاضری'), '${textOf(attendance['percentage'])}%')),
                SizedBox(width: width, child: Kpi(model.t('Present', 'حاضر'), textOf(attendance['present']))),
                SizedBox(width: width, child: Kpi(model.t('Pending fee', 'باقی فیس'), textOf(fees['pending']))),
                SizedBox(width: width, child: Kpi(model.t('Leave left', 'باقی چھٹی'), textOf(attendance['leave_left'] ?? attendance['leave']))),
              ]);
            }),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final name = model.displayName;
    final photo = textOf(model.user['face_photo_url']).isEmpty ? textOf(model.user['photo_url']) : textOf(model.user['face_photo_url']);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHead(title: model.t('Profile', 'پروفائل'), subtitle: model.t('Account loaded from /api/me', 'اکاؤنٹ /api/me سے')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              PersonAvatar(name: name, url: photo, size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SoftBadge(textOf(model.user['role']), tone: BadgeTone.blue),
                  const SizedBox(height: 8),
                  Text(textOf(model.user['email'])),
                  Text(model.user['face_registered'] == true ? model.t('Face · Saved', 'چہرہ · محفوظ') : model.t('Face · Not saved', 'چہرہ · محفوظ نہیں')),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final name = TextEditingController();
  final shortName = TextEditingController();
  final address = TextEditingController();
  final threshold = TextEditingController();
  final presentUntil = TextEditingController();
  String primary = '#1B4F9C';
  String secondary = '#F39200';
  String accent = '#F5A623';
  String sidebar = '#0E2A4A';
  String header = '#FFFDF8';
  String buttonStyle = 'rounded';
  String themeMode = 'light';
  String? message;
  bool busy = false;
  var loaded = false;
  var tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    AppScope.of(context).api.settings().then((data) {
      final settings = data['settings'] is Map ? Map<String, dynamic>.from(data['settings'] as Map) : data;
      if (!mounted) return;
      setState(() {
        name.text = textOf(settings['college_name']);
        shortName.text = textOf(settings['short_name']);
        address.text = textOf(settings['college_address']);
        threshold.text = textOf(settings['face_match_threshold']);
        presentUntil.text = textOf(settings['present_until']);
        primary = _color(settings['primary_color'], primary);
        secondary = _color(settings['secondary_color'], secondary);
        accent = _color(settings['accent_color'], accent);
        sidebar = _color(settings['sidebar_color'], sidebar);
        header = _color(settings['header_color'], header);
        final style = textOf(settings['button_style']);
        if (style == 'square' || style == 'pill' || style == 'rounded') buttonStyle = style;
        themeMode = textOf(settings['theme']) == 'dark' ? 'dark' : 'light';
      });
    }).catchError((Object err) {
      if (mounted) setState(() => message = err.toString());
    });
  }

  String _color(dynamic value, String fallback) {
    final hex = textOf(value).trim();
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex) ? hex.toUpperCase() : fallback;
  }

  @override
  void dispose() {
    name.dispose();
    shortName.dispose();
    address.dispose();
    threshold.dispose();
    presentUntil.dispose();
    super.dispose();
  }

  void preview() {
    AppScope.of(context).applyBrand({
      'name': name.text.trim(),
      'short_name': shortName.text.trim(),
      'primary_color': primary,
      'secondary_color': secondary,
      'accent_color': accent,
      'sidebar_color': sidebar,
      'header_color': header,
      'button_style': buttonStyle,
      'theme': themeMode,
    });
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final model = AppScope.of(context);
      final result = tab == 1
          ? await model.api.saveSettings({
              'primary_color': primary,
              'secondary_color': secondary,
              'accent_color': accent,
              'sidebar_color': sidebar,
              'header_color': header,
              'button_style': buttonStyle,
              'theme': themeMode,
            })
          : await model.api.saveSettings({
              'college_name': name.text.trim(),
              'short_name': shortName.text.trim(),
              'college_address': address.text.trim(),
              'face_match_threshold': double.tryParse(threshold.text) ?? 0.55,
              'present_until': presentUntil.text.trim(),
            });
      final brand = result['branding'];
      if (brand is Map) model.applyBrand(Map<String, dynamic>.from(brand));
      if (mounted) setState(() => message = model.t('Settings saved. The color scheme is applied.', 'ترتیبات محفوظ ہو گئیں اور رنگ لگ گئے۔'));
    } catch (err) {
      if (mounted) setState(() => message = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final matched = collegePalettes.where((item) => item.primary.toUpperCase() == primary && item.sidebar.toUpperCase() == sidebar).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHead(title: model.t('Settings', 'ترتیبات'), subtitle: model.t('School profile and the color scheme used across the app.', 'اسکول کا پروفائل اور ایپ کا رنگ۔')),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(model.t('School', 'اسکول'))),
            ButtonSegment(value: 1, label: Text(model.t('Appearance', 'رنگ'))),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        const SizedBox(height: 14),
        if (tab == 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: name, decoration: InputDecoration(labelText: model.t('College name', 'کالج کا نام'))),
                const SizedBox(height: 10),
                TextField(controller: shortName, decoration: InputDecoration(labelText: model.t('Short name', 'مختصر نام'))),
                const SizedBox(height: 10),
                TextField(controller: address, decoration: InputDecoration(labelText: model.t('Address', 'پتہ'))),
                const SizedBox(height: 10),
                TextField(controller: threshold, decoration: InputDecoration(labelText: model.t('Face match strictness', 'چہرے کے ملنے کی سختی'))),
                const SizedBox(height: 10),
                TextField(controller: presentUntil, decoration: InputDecoration(labelText: model.t('Present until', 'حاضر اس وقت تک'))),
              ]),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.t('Color combination', 'رنگوں کا مجموعہ'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(model.t('The same sets as the website. Primary colors buttons and bars. Sidebar colors the header.', 'ویب سائٹ والے ہی مجموعے۔'), style: TextStyle(color: CollegeColors.muted, height: 1.35)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 640 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.1,
                        children: [
                          for (final item in collegePalettes)
                            _PaletteTile(
                              palette: item,
                              selected: matched?.id == item.id,
                              onTap: () {
                                setState(() {
                                  primary = item.primary;
                                  secondary = item.secondary;
                                  accent = item.accent;
                                  sidebar = item.sidebar;
                                  header = item.header;
                                });
                                preview();
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(model.t('Button style', 'بٹن کی شکل'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final style in ['square', 'rounded', 'pill'])
                        ChoiceChip(
                          label: Text(style),
                          selected: buttonStyle == style,
                          onSelected: (_) {
                            setState(() => buttonStyle = style);
                            preview();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(model.t('Theme', 'تھیم'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in ['light', 'dark'])
                        ChoiceChip(
                          label: Text(mode),
                          selected: themeMode == mode,
                          onSelected: (_) {
                            setState(() => themeMode = mode);
                            preview();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: CollegeColors.line)),
                    child: Row(
                      children: [
                        Container(width: 18, color: CollegeColors.parse(sidebar, CollegeColors.sidebar)),
                        Expanded(
                          child: ColoredBox(
                            color: CollegeColors.parse(header, CollegeColors.header),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: CollegeColors.parse(primary, CollegeColors.primary), borderRadius: BorderRadius.circular(CollegeColors.radius.clamp(4, 20).toDouble())),
                                  child: Text(model.t('Button', 'بٹن'), style: TextStyle(color: CollegeColors.onPrimary, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                _Dot(CollegeColors.parse(secondary, CollegeColors.secondary)),
                                const SizedBox(width: 6),
                                _Dot(CollegeColors.parse(accent, CollegeColors.accent)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message!)),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: busy ? null : save, child: Text(busy ? model.t('Saving...', 'محفوظ ہو رہا ہے...') : model.t('Save', 'محفوظ کریں')))),
      ],
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({required this.palette, required this.selected, required this.onTap});

  final CollegePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CollegeColors.blueBg : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? CollegeColors.primary : CollegeColors.line, width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  for (final hex in [palette.primary, palette.secondary, palette.accent, palette.sidebar])
                    Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: CollegeColors.parse(hex, CollegeColors.primary), shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 6),
              Text(palette.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({required this.model, super.key});

  final AppModel model;

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  var token = 0;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final staff = model.role == 'admin' || model.role == 'teacher';
    return RemoteTable(
      key: ValueKey(token),
      title: model.t('Leaves', 'چھٹیاں'),
      subtitle: model.t('Review requests the same way as the website', 'ویب سائٹ کی طرح درخواستیں دیکھیں'),
      load: () => familyList(model, 'leaves', model.api.leaves),
      columns: [model.t('Student', 'طالب علم'), model.t('Dates', 'تاریخ'), model.t('Status', 'حالت'), if (staff) model.t('Action', 'عمل')],
      cells: (row) {
        final id = int.tryParse('${row['id']}');
        final pending = textOf(row['status']) == 'pending';
        return [
          Text(nested(row, ['student', 'user', 'name']).isEmpty ? textOf(row['name']) : nested(row, ['student', 'user', 'name'])),
          Text('${textOf(row['start_date'])} – ${textOf(row['end_date'])}'),
          SoftBadge(textOf(row['status']), tone: textOf(row['status']) == 'approved' ? BadgeTone.ok : BadgeTone.warn),
          if (staff)
            pending && id != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _review(id, 'approved'), child: Text(model.t('Approve', 'منظور'))),
                      TextButton(onPressed: () => _review(id, 'rejected'), child: Text(model.t('Reject', 'رد'))),
                    ],
                  )
                : const Text('—'),
        ];
      },
    );
  }

  Future<void> _review(int id, String status) async {
    try {
      await widget.model.api.reviewLeave(id, status);
      if (mounted) setState(() => token++);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({required this.model, super.key});

  final AppModel model;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  var audience = 'all';
  var token = 0;
  String? message;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final staff = model.role == 'admin' || model.role == 'teacher';
    return Column(
      children: [
        if (staff)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(controller: title, decoration: InputDecoration(labelText: model.t('Title', 'عنوان'))),
                    const SizedBox(height: 8),
                    TextField(controller: body, decoration: InputDecoration(labelText: model.t('Message', 'پیغام'))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: audience,
                          items: [
                            for (final item in ['all', 'parents', 'teachers'])
                              DropdownMenuItem(value: item, child: Text(model.t(item, item))),
                          ],
                          onChanged: (value) => setState(() => audience = value ?? 'all'),
                        ),
                        const Spacer(),
                        FilledButton(onPressed: _send, child: Text(model.t('Publish', 'شائع کریں'))),
                      ],
                    ),
                    if (message != null) Text(message!, style: TextStyle(color: CollegeColors.danger)),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: RemoteTable(
            key: ValueKey(token),
            title: model.t('Announcements', 'اعلانات'),
            subtitle: model.t('Published for the college', 'کالج کے لیے شائع'),
            load: () => familyList(model, 'announcements', model.api.announcements),
            columns: [model.t('Title', 'عنوان'), model.t('Audience', 'سامعین'), model.t('Status', 'حالت')],
            cells: (row) => [
              Text(textOf(row['title'])),
              Text(textOf(row['audience'])),
              SoftBadge(row['published'] == true ? model.t('Published', 'شائع') : model.t('Draft', 'مسودہ'), tone: BadgeTone.blue),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    setState(() => message = null);
    try {
      await widget.model.api.postAnnouncement(title.text.trim(), body.text.trim(), audience);
      title.clear();
      body.clear();
      if (mounted) setState(() => token++);
    } catch (err) {
      if (mounted) setState(() => message = err.toString());
    }
  }
}
