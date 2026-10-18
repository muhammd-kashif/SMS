import 'package:flutter/material.dart';

import '../api.dart';
import '../data_table.dart';
import '../design.dart';
import '../export_service.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).api.dashboard();
  }

  void _reload() {
    setState(() => future = AppScope.of(context).api.dashboard());
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashSkeleton(width: 240, height: 22),
                SizedBox(height: 16),
                CardGridSkeleton(count: 6),
                SizedBox(height: 16),
                TableSkeleton(rows: 8, columns: 6),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorState(message: snapshot.error.toString(), onRetry: _reload),
          );
        }
        return _DashboardBody(model: model, data: snapshot.data ?? {}, onReload: _reload);
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.model, required this.data, required this.onReload});

  final AppModel model;
  final Map<String, dynamic> data;
  final VoidCallback onReload;

  Map<String, dynamic> get _attendance => _map(data['attendance']);
  Map<String, dynamic> get _fees => _map(data['fees']);
  List get _exams => _list(data['upcoming_exams']);
  List get _classes => _list(data['class_attendance']);
  List get _trend => _list(data['trend']);
  List get _feeTrend => _list(data['fee_trend']);

  int get _present => _int(_attendance['present']);
  int get _late => _int(_attendance['late']);
  int get _absent => _int(_attendance['absent']);
  int get _pendingFees => _int(_fees['pending']);

  double get _attendanceRate {
    final marked = _present + _absent;
    return marked == 0 ? 0 : _present / marked;
  }

  @override
  Widget build(BuildContext context) {
    final staff = model.role == 'admin' || model.role == 'teacher';
    final finance = model.role == 'admin' || model.role == 'accountant';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final mid = constraints.maxWidth >= 820;
        final metrics = _metrics(context);

        return ListView(
          padding: pagePadding(context),
          children: [
            PageHeader(
              title: model.t('Dashboard', 'ڈیش بورڈ'),
              subtitle: model.t('Students, attendance, fees and the work waiting today.', 'طلبہ، حاضری، فیس اور آج کے کام'),
              breadcrumb: [model.t('Overview', 'تعارف'), model.t('Dashboard', 'ڈیش بورڈ')],
              actions: [
                DashIconButton(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: onReload),
                ExportButton(
                  compact: true,
                  bundle: () => _bundle(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _quickActions(context, staff: staff, finance: finance),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: metrics),
                ],
              )
            else if (mid)
              Column(children: [metrics, const SizedBox(height: 14)])
            else
              Column(children: [metrics, const SizedBox(height: 14)]),
            const SizedBox(height: 14),
            if (mid)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _attendanceTrend()),
                  const SizedBox(width: 14),
                  Expanded(child: _feeTrendPanel()),
                ],
              )
            else ...[
              _attendanceTrend(),
              const SizedBox(height: 14),
              _feeTrendPanel(),
            ],
            const SizedBox(height: 14),
            if (mid)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _classAttendance()),
                  const SizedBox(width: 14),
                  Expanded(child: _upcomingExams()),
                ],
              )
            else ...[
              _classAttendance(),
              const SizedBox(height: 14),
              _upcomingExams(),
            ],
          ],
        );
      },
    );
  }

  Widget _metrics(BuildContext context) {
    final cards = [
      MetricCard(
        label: model.t('Total students', 'کل طلبہ'),
        value: textOf(data['students']),
        icon: Icons.groups_rounded,
        tone: DashTone.brand,
        hint: model.t('Enrolled in the college', 'کالج میں رجسٹرڈ'),
        onTap: () => model.go(Dest.students),
      ),
      MetricCard(
        label: model.t('Total teachers', 'کل اساتذہ'),
        value: textOf(data['teachers']),
        icon: Icons.school_rounded,
        tone: DashTone.info,
        hint: model.t('Teaching staff', 'تدریسی اساتذہ'),
        onTap: () => model.go(Dest.teachers),
      ),
      MetricCard(
        label: model.t('Present today', 'آج حاضر'),
        value: '$_present',
        icon: Icons.how_to_reg_rounded,
        tone: DashTone.success,
        progress: _attendanceRate,
        hint: '${(_attendanceRate * 100).toStringAsFixed(0)}% ${model.t('of marked students', 'نشان زد طلبہ میں سے')}',
        onTap: () => model.go(Dest.attendance),
      ),
      MetricCard(
        label: model.t('Late today', 'آج دیر'),
        value: '$_late',
        icon: Icons.schedule_rounded,
        tone: DashTone.warning,
        hint: model.t('Marked late', 'دیر سے آئے'),
      ),
      MetricCard(
        label: model.t('Fee pending', 'فیس باقی'),
        value: '$_pendingFees',
        icon: Icons.payments_rounded,
        tone: DashTone.danger,
        hint: model.t('Students with dues', 'فیس بقایا طلبہ'),
        onTap: () => model.go(Dest.fees),
      ),
      MetricCard(
        label: model.t('Upcoming exams', 'قریبی امتحانات'),
        value: '${_exams.length}',
        icon: Icons.quiz_rounded,
        tone: DashTone.brand,
        hint: model.t('Scheduled papers', 'مقررہ کاغذات'),
        onTap: () => model.go(Dest.exams),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 6
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns >= 3 ? 1.45 : columns == 2 ? 1.7 : 3,
          children: cards,
        );
      },
    );
  }

  Widget _quickActions(BuildContext context, {required bool staff, required bool finance}) {
    final actions = <({String label, IconData icon, DashTone tone, VoidCallback onTap})>[
      if (staff) (label: model.t('Add student', 'نیا طالب'), icon: Icons.person_add_alt_1_rounded, tone: DashTone.brand, onTap: () => model.go(Dest.studentForm)),
      if (staff) (label: model.t('Take attendance', 'حاضری لیں'), icon: Icons.photo_camera_rounded, tone: DashTone.info, onTap: () => model.go(Dest.scan)),
      if (staff) (label: model.t('Register face', 'چہرہ رجسٹر'), icon: Icons.face_rounded, tone: DashTone.brand, onTap: () => model.go(Dest.register)),
      if (finance) (label: model.t('Collect fee', 'فیس وصول'), icon: Icons.point_of_sale_rounded, tone: DashTone.success, onTap: () => model.go(Dest.collect)),
      if (model.role == 'admin') (label: model.t('Announcement', 'اعلان'), icon: Icons.campaign_rounded, tone: DashTone.warning, onTap: () => model.go(Dest.announcements)),
      (label: model.t('Timetable', 'ٹائم ٹیبل'), icon: Icons.calendar_month_rounded, tone: DashTone.neutral, onTap: () => model.go(Dest.timetable)),
    ];

    return Panel(
      title: model.t('Quick actions', 'فوری اقدامات'),
      subtitle: model.t('Jump straight into the daily work.', 'روزانہ کام فوراً شروع کریں۔'),
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final action in actions)
            DashButton(
              label: action.label,
              icon: action.icon,
              variant: action.tone == DashTone.brand ? DashVariant.primary : DashVariant.secondary,
              onPressed: action.onTap,
            ),
        ],
      ),
    );
  }

  Widget _attendanceTrend() {
    return Panel(
      title: model.t('Attendance trend', 'حاضری کا رجحان'),
      subtitle: model.t('Present and late, last days', 'حاضر، دیر — گزشتہ دن'),
      actions: [
        DashButton(
          label: model.t('Attendance', 'حاضری'),
          icon: Icons.how_to_reg_rounded,
          size: DashSize.sm,
          onPressed: () => model.go(Dest.attendance),
        ),
      ],
      child: _TrendChart(
        values: [for (final day in _trend) (_presentOf(day) + _lateOf(day)).toDouble()],
        labels: _dayLabels(_trend),
        color: Dash.brand,
        emptyLabel: model.t('No attendance trend yet.', 'ابھی حاضری کا رجحان نہیں۔'),
      ),
    );
  }

  Widget _feeTrendPanel() {
    return Panel(
      title: model.t('Fee collection', 'فیس کی وصولی'),
      subtitle: model.t('Posted payments', 'پوسٹ شدہ ادائیگیاں'),
      actions: [
        DashButton(
          label: model.t('Fees', 'فیس'),
          icon: Icons.payments_rounded,
          size: DashSize.sm,
          onPressed: () => model.go(Dest.fees),
        ),
      ],
      child: _TrendChart(
        values: [for (final item in _feeTrend) _double(item['amount'])],
        labels: [for (final item in _feeTrend) textOf(item['label'])],
        color: Dash.success,
        prefix: _feeTrend.isEmpty ? null : 'PKR ',
        emptyLabel: model.t('No fee trend yet.', 'ابھی فیس کا رجحان نہیں۔'),
      ),
    );
  }

  Widget _classAttendance() {
    if (_classes.isEmpty) {
      return Panel(
        title: model.t('Class-wise today', 'آج کلاس بنیٹ پر حاضری'),
        child: EmptyState(title: model.t('No classes yet', 'ابھی کوئی کلاس نہیں'), message: model.t('Add classes to see today\'s attendance.', 'کلاس بنائیں تاکہ آج کی حاضری دکھائی دے۔'), icon: Icons.class_rounded),
      );
    }
    return Panel(
      title: model.t('Class-wise today', 'آج کلاس بنیٹ پر حاضری'),
      subtitle: model.t('${_classes.length} ${model.t('classes', 'کلاسز')}', '${_classes.length} کلاسز'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < _classes.length; i++) ...[
            if (i > 0) const DashDivider(),
            _classRow(_map(_classes[i])),
          ],
        ],
      ),
    );
  }

  Widget _classRow(Map<String, dynamic> row) {
    final present = _int(row['present']);
    final absent = _int(row['absent']);
    final total = present + absent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textOf(row['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                DashProgress(value: total == 0 ? 0 : present / total, tone: DashTone.success, height: 5),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill('$present${total > 0 ? ' / $total' : ''} ${model.t('present', 'حاضر')}', tone: DashTone.success, dense: true),
          const SizedBox(width: 6),
          StatusPill('$absent ${model.t('absent', 'غیر حاضر')}', tone: DashTone.danger, dense: true),
        ],
      ),
    );
  }

  Widget _upcomingExams() {
    if (_exams.isEmpty) {
      return Panel(
        title: model.t('Upcoming exams', 'قریبی امتحانات'),
        child: EmptyState(title: model.t('No upcoming exams', 'کوئی امتحان درکار نہیں'), message: model.t('Scheduled papers appear here.', 'مقررہ کاغذات یہاں دکھائی دیں گے۔'), icon: Icons.quiz_rounded),
      );
    }
    return Panel(
      title: model.t('Upcoming exams', 'قریبی امتحانات'),
      subtitle: model.t('${_exams.length} ${model.t('scheduled', 'مقررہ')}', '${_exams.length} مقررہ'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < _exams.length && i < 6; i++) ...[
            if (i > 0) const DashDivider(),
            _examRow(_map(_exams[i])),
          ],
        ],
      ),
    );
  }

  Widget _examRow(Map<String, dynamic> exam) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          IconSquare(icon: Icons.description_rounded, tone: exam['published'] == true ? DashTone.success : DashTone.neutral, size: 34),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textOf(exam['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  [textOf(exam['class_name']), textOf(exam['start_date'])].where((part) => part.isNotEmpty).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Dash.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            exam['published'] == true ? model.t('Published', 'شائع') : model.t('Draft', 'مسودہ'),
            tone: exam['published'] == true ? DashTone.success : DashTone.neutral,
            dense: true,
          ),
        ],
      ),
    );
  }

  ExportBundle _bundle(BuildContext context) {
    final rows = <List<String>>[
      [model.t('Total students', 'کل طلبہ'), textOf(data['students'])],
      [model.t('Total teachers', 'کل اساتذہ'), textOf(data['teachers'])],
      [model.t('Present today', 'آج حاضر'), '$_present'],
      [model.t('Late today', 'آج دیر'), '$_late'],
      [model.t('Absent today', 'آج غیر حاضر'), '$_absent'],
      [model.t('Fee pending', 'فیس باقی'), '$_pendingFees'],
      [model.t('Attendance rate', 'حاضری کا رجحان'), '${(_attendanceRate * 100).toStringAsFixed(1)}%'],
      [model.t('Upcoming exams', 'قریبی امتحانات'), '${_exams.length}'],
    ];
    for (final day in _trend) {
      final map = _map(day);
      rows.add([textOf(map['date']), textOf(map['present']), textOf(map['late']), textOf(map['absent'])]);
    }
    for (final item in _feeTrend) {
      final map = _map(item);
      rows.add([textOf(map['label']), textOf(map['amount'])]);
    }
    for (final item in _classes) {
      final map = _map(item);
      rows.add([model.t('Class', 'کلاس'), textOf(map['name']), model.t('Present', 'حاضر'), textOf(map['present']), model.t('Absent', 'غیر حاضر'), textOf(map['absent'])]);
    }
    for (final exam in _exams) {
      final map = _map(exam);
      rows.add([model.t('Exam', 'امتحان'), textOf(map['name']), model.t('Class', 'کلاس'), textOf(map['class_name']), model.t('Starts', 'آغاز'), textOf(map['start_date'])]);
    }
    return ExportBundle(
      title: model.t('Dashboard', 'ڈیش بورڈ'),
      subtitle: CollegeColors.schoolName,
      headers: [
        model.t('Item', 'چیز'),
        model.t('Value', 'قدر'),
        model.t('Detail', 'تفصیل'),
        model.t('Present', 'حاضر'),
        model.t('Absent', 'غیر حاضر'),
        model.t('Amount', 'رقم'),
      ],
      rows: rows,
      meta: [
        (model.t('Students', 'طلبہ'), textOf(data['students'])),
        (model.t('Teachers', 'اساتذہ'), textOf(data['teachers'])),
        (model.t('Fee pending', 'فیس باقی'), '$_pendingFees'),
      ],
      sheetName: 'Dashboard',
      landscape: true,
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.values,
    required this.labels,
    required this.color,
    required this.emptyLabel,
    this.prefix,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final String emptyLabel;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: 148, child: Center(child: Text(emptyLabel, style: TextStyle(color: Dash.faint, fontSize: 12.5))));
    }
    final max = values.fold<double>(1, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 148,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Tooltip(
                      message: '${labels[i].isEmpty ? i + 1 : labels[i]}\n${prefix ?? ''}${_compact(values[i] * max)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (values[i] / max).clamp(0.03, 1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0.55)]),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(i < labels.length ? labels[i] : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.faint, fontSize: 9.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List _list(dynamic value) => value is List ? value : const [];

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _presentOf(dynamic day) => _int(_map(day)['present']);

int _lateOf(dynamic day) => _int(_map(day)['late']);

List<String> _dayLabels(List trend) {
  return [
    for (final day in trend)
      () {
        final raw = textOf(_map(day)['date']);
        return raw.length >= 10 ? raw.substring(8) : raw;
      }(),
  ];
}

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return RemoteTable(
      title: model.t('Students', 'طلبہ'),
      subtitle: model.t('Loaded from the college API', 'کالج API سے'),
      load: model.api.students,
      columns: [model.t('Name', 'نام'), model.t('ID', 'شناخت'), model.t('Class', 'کلاس'), model.t('Face', 'چہرہ'), model.t('Status', 'حالت')],
      cells: (row) => [
        InkWell(
          onTap: () => model.go(Dest.studentProfile, student: int.tryParse('${row['id']}')),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(name: textOf(row['name']), url: textOf(row['face_photo_url']).isEmpty ? textOf(row['photo_url']) : textOf(row['face_photo_url']), size: 36),
              const SizedBox(width: 8),
              Text(textOf(row['name']), style: TextStyle(color: CollegeColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Text(textOf(row['student_code'])),
        Text('${textOf(row['class_name'])} ${textOf(row['section_name'])}'),
        SoftBadge(row['face_registered'] == true ? model.t('Registered', 'رجسٹرڈ') : model.t('Missing', 'غائب'), tone: row['face_registered'] == true ? BadgeTone.ok : BadgeTone.bad),
        SoftBadge(textOf(row['status']), tone: BadgeTone.blue),
      ],
    );
  }
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late Future<Map<String, dynamic>> future;
  int? loadedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppScope.of(context).openStudent;
    if (id == loadedId) return;
    loadedId = id;
    future = id == null ? Future.error(ApiException('Choose a student.')) : AppScope.of(context).api.student(id);
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CollegeLoader();
        }
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final student = snapshot.data ?? {};
        final photo = textOf(student['face_photo_url']).isEmpty ? textOf(student['photo_url']) : textOf(student['face_photo_url']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHead(title: textOf(student['name']), subtitle: '${textOf(student['student_code'])} · ${textOf(student['class_name'])} — ${textOf(student['section_name'])}'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    PersonAvatar(name: textOf(student['name']), url: photo, size: 84),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(textOf(student['name']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          Text('${textOf(student['phone'])} · ${textOf(student['address'])}', style: TextStyle(color: CollegeColors.muted)),
                          const SizedBox(height: 8),
                          SoftBadge(student['face_registered'] == true ? model.t('Registered', 'رجسٹرڈ') : model.t('Missing', 'غائب'), tone: student['face_registered'] == true ? BadgeTone.ok : BadgeTone.bad),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController(text: 'College@123');
  final roll = TextEditingController();
  List<Map<String, dynamic>> classes = [];
  int? classId;
  int? sectionId;
  String? error;
  bool busy = false;

  var loadedStructure = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loadedStructure) return;
    loadedStructure = true;
    AppScope.of(context).api.structure().then((data) {
      final rows = data['classes'];
      if (!mounted || rows is! List) return;
      setState(() => classes = [for (final row in rows) if (row is Map) Map<String, dynamic>.from(row)]);
    }).catchError((Object err) {
      if (mounted) setState(() => error = err.toString());
    });
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    roll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final model = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await model.api.createStudent({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'roll_number': roll.text.trim(),
        'class_id': classId,
        'section_id': sectionId,
      });
      if (mounted) model.go(Dest.students);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    Map<String, dynamic>? selected;
    for (final row in classes) {
      if (row['id'] == classId) selected = row;
    }
    final sections = selected?['sections'] is List ? (selected!['sections'] as List) : const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHead(title: model.t('Add student', 'طالب علم شامل کریں'), subtitle: model.t('Saved through POST /api/students', 'POST /api/students سے محفوظ')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: model.t('Name', 'نام'))),
                const SizedBox(height: 10),
                TextField(controller: email, decoration: InputDecoration(labelText: model.t('Email', 'ای میل'))),
                const SizedBox(height: 10),
                TextField(controller: password, decoration: InputDecoration(labelText: model.t('Password', 'پاس ورڈ'))),
                const SizedBox(height: 10),
                TextField(controller: roll, decoration: InputDecoration(labelText: model.t('Roll', 'رول'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: classId,
                  decoration: InputDecoration(labelText: model.t('Class', 'کلاس')),
                  items: [for (final item in classes) DropdownMenuItem(value: item['id'] as int, child: Text(textOf(item['name'])))],
                  onChanged: (value) => setState(() {
                    classId = value;
                    sectionId = null;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: sectionId,
                  decoration: InputDecoration(labelText: model.t('Section', 'سیکشن')),
                  items: [
                    for (final item in sections)
                      if (item is Map) DropdownMenuItem(value: item['id'] as int, child: Text(textOf(item['name']))),
                  ],
                  onChanged: (value) => setState(() => sectionId = value),
                ),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: CollegeColors.danger))),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: busy ? null : save, child: Text(model.t('Save', 'محفوظ کریں')))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TeachersScreen extends StatelessWidget {
  const TeachersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return RemoteTable(
      title: model.t('Teachers', 'اساتذہ'),
      subtitle: model.t('Loaded from the college API', 'کالج API سے'),
      load: model.api.teachers,
      columns: [model.t('Name', 'نام'), model.t('Code', 'کوڈ'), model.t('Role', 'کردار'), model.t('Face', 'چہرہ'), model.t('Status', 'حالت')],
      cells: (row) => [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(name: textOf(row['name']), url: textOf(row['face_photo_url']).isEmpty ? textOf(row['photo_url']) : textOf(row['face_photo_url']), size: 36),
            const SizedBox(width: 8),
            Text(textOf(row['name'])),
          ],
        ),
        Text(textOf(row['employee_code'])),
        Text(textOf(row['designation'])),
        SoftBadge(row['face_registered'] == true ? model.t('Registered', 'رجسٹرڈ') : model.t('Missing', 'غائب'), tone: row['face_registered'] == true ? BadgeTone.ok : BadgeTone.bad),
        SoftBadge(textOf(row['status']), tone: BadgeTone.blue),
      ],
    );
  }
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<Map<String, dynamic>> future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future = AppScope.of(context).api.structure();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final classes = snapshot.data?['classes'] is List ? snapshot.data!['classes'] as List : const [];
        final subjects = snapshot.data?['subjects'] is List ? snapshot.data!['subjects'] as List : const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHead(title: model.t('Classes', 'کلاسز'), subtitle: model.t('Classes, sections, and subjects', 'کلاس، سیکشن اور مضامین')),
            if (snapshot.hasError) Text(snapshot.error.toString(), style: TextStyle(color: CollegeColors.danger)),
            for (final item in classes)
              if (item is Map)
                Card(
                  child: ListTile(
                    title: Text(textOf(item['name'])),
                    subtitle: Text((item['sections'] as List?)?.map((section) => section is Map ? section['name'] : '').join(', ') ?? ''),
                  ),
                ),
            const SizedBox(height: 12),
            Text(subjects.map((item) => item is Map ? item['name'] : '').join(', ')),
          ],
        );
      },
    );
  }
}
