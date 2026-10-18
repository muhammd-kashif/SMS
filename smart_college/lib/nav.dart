import 'package:flutter/material.dart';

import 'state.dart';

class NavEntry {
  const NavEntry({required this.label, required this.icon, required this.dest, this.badge});

  final String label;
  final IconData icon;
  final Dest dest;
  final String? badge;
}

class NavGroup {
  const NavGroup(this.label, this.items);

  final String label;
  final List<NavEntry> items;
}

List<NavGroup> navGroups(AppModel model) {
  final family = model.role == 'student' || model.role == 'parent';
  final admin = model.role == 'admin';
  final teacher = model.role == 'teacher';
  final accountant = model.role == 'accountant';
  final staff = admin || teacher || accountant;

  final groups = <NavGroup>[
    NavGroup('Overview', [
      NavEntry(label: model.t(family ? 'My portal' : 'Dashboard', family ? 'میرا پورٹل' : 'ڈیش بورڈ'), icon: Icons.dashboard_rounded, dest: family ? Dest.portal : Dest.dashboard),
    ]),
    if (!family && !accountant)
      NavGroup('People', [
        NavEntry(label: model.t('Students', 'طلبہ'), icon: Icons.groups_rounded, dest: Dest.students),
        if (admin) NavEntry(label: model.t('Teachers', 'اساتذہ'), icon: Icons.school_rounded, dest: Dest.teachers),
        NavEntry(label: model.t('Classes', 'کلاسز'), icon: Icons.class_rounded, dest: Dest.classes),
        if (admin) NavEntry(label: model.t('Admission', 'داخلہ'), icon: Icons.person_add_alt_1_rounded, dest: Dest.studentForm),
      ]),
    NavGroup('Academics', [
      NavEntry(label: model.t('Timetable', 'ٹائم ٹیبل'), icon: Icons.calendar_month_rounded, dest: Dest.timetable),
      if (staff || family) NavEntry(label: model.t('Exams', 'امتحانات'), icon: Icons.quiz_rounded, dest: Dest.exams),
      NavEntry(label: model.t('Results', 'نتائج'), icon: Icons.emoji_events_rounded, dest: Dest.results),
      NavEntry(label: model.t('Homework', 'ہوم ورک'), icon: Icons.menu_book_rounded, dest: Dest.homework),
      NavEntry(label: model.t('Assignments', 'اسائنمنٹس'), icon: Icons.assignment_rounded, dest: Dest.assignments),
      if (staff) NavEntry(label: model.t('Class test', 'کلاس ٹیسٹ'), icon: Icons.fact_check_rounded, dest: Dest.test),
    ]),
    NavGroup('Operations', [
      NavEntry(label: model.t('Attendance', 'حاضری'), icon: Icons.how_to_reg_rounded, dest: Dest.attendance),
      if (admin || teacher) NavEntry(label: model.t('Face scan', 'اسکین'), icon: Icons.photo_camera_rounded, dest: Dest.scan),
      if (admin || teacher) NavEntry(label: model.t('Face register', 'چہرہ رجسٹر'), icon: Icons.face_rounded, dest: Dest.register),
      if (admin || accountant || family) NavEntry(label: model.t('Fees', 'فیس'), icon: Icons.payments_rounded, dest: Dest.fees),
      if (admin || accountant) NavEntry(label: model.t('Collect fee', 'فیس وصول'), icon: Icons.point_of_sale_rounded, dest: Dest.collect),
      if (staff) NavEntry(label: model.t('Leaves', 'چھٹیاں'), icon: Icons.event_busy_rounded, dest: Dest.leaves),
    ]),
    NavGroup('Communication', [
      NavEntry(label: model.t('Announcements', 'اعلانات'), icon: Icons.campaign_rounded, dest: Dest.announcements),
      NavEntry(label: model.t('Notifications', 'اطلاعات'), icon: Icons.notifications_rounded, dest: Dest.notifications),
    ]),
    NavGroup('System', [
      if (admin || accountant) NavEntry(label: model.t('Reports', 'رپورٹس'), icon: Icons.insights_rounded, dest: Dest.reports),
      NavEntry(label: model.t('All modules', 'تمام ماڈیولز'), icon: Icons.grid_view_rounded, dest: Dest.more),
      if (admin) NavEntry(label: model.t('Settings', 'ترتیبات'), icon: Icons.settings_rounded, dest: Dest.settings),
      NavEntry(label: model.t('Profile', 'پروفائل'), icon: Icons.person_rounded, dest: Dest.profile),
    ]),
  ];
  return groups.where((group) => group.items.isNotEmpty).toList();
}

const rootDests = <Dest>{Dest.dashboard, Dest.portal, Dest.more};

