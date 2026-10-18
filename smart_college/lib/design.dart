import 'package:flutter/material.dart';

import 'theme.dart';

/// Neutral "react dashboard" design tokens layered on top of the college branding.
class Dash {
  const Dash._();

  static bool get dark => CollegeColors.dark;
  static Color get canvas => dark ? const Color(0xFF0A0F1C) : const Color(0xFFF1F5F9);
  static Color get surface => dark ? const Color(0xFF111827) : Colors.white;
  static Color get soft => dark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
  static Color get hover => dark ? const Color(0xFF182234) : const Color(0xFFF1F5F9);
  static Color get border => dark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
  static Color get ink => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get muted => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get faint => dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  static Color get brand => CollegeColors.primary;
  static Color get brandSoft => CollegeColors.primary.withValues(alpha: dark ? 0.24 : 0.10);
  static Color get success => dark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get successSoft => dark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  static Color get warning => dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get warningSoft => dark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
  static Color get danger => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get dangerSoft => dark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
  static Color get info => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get infoSoft => dark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);

  static double get radius => CollegeColors.radius.clamp(6, 14).toDouble();
  static double get radiusSm => (radius - 4).clamp(4, 10).toDouble();

  static List<BoxShadow> get shadow => dark
      ? const []
      : const [
          BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 4)),
        ];

  static BorderRadius get corners => BorderRadius.circular(radius);
  static BorderRadius get cornersSm => BorderRadius.circular(radiusSm);

  static InputDecoration input({String? hint, Widget? prefix, Widget? suffix, double height = 38}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Dash.faint, fontSize: 13),
      prefixIcon: prefix == null ? null : Padding(padding: const EdgeInsets.only(left: 11, right: 6), child: IconTheme(data: IconThemeData(size: 18, color: Dash.faint), child: prefix)),
      suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: 8), child: suffix),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Dash.dark ? const Color(0xFF0B1220) : Colors.white,
      border: OutlineInputBorder(borderRadius: cornersSm, borderSide: BorderSide(color: Dash.border)),
      enabledBorder: OutlineInputBorder(borderRadius: cornersSm, borderSide: BorderSide(color: Dash.border)),
      focusedBorder: OutlineInputBorder(borderRadius: cornersSm, borderSide: BorderSide(color: Dash.brand, width: 1.4)),
      constraints: BoxConstraints(minHeight: height),
    );
  }
}

enum DashTone { neutral, success, warning, danger, info, brand }

Color toneInk(DashTone tone) => switch (tone) {
      DashTone.success => Dash.success,
      DashTone.warning => Dash.warning,
      DashTone.danger => Dash.danger,
      DashTone.info => Dash.info,
      DashTone.brand => Dash.brand,
      DashTone.neutral => Dash.muted,
    };

Color toneWash(DashTone tone) => switch (tone) {
      DashTone.success => Dash.successSoft,
      DashTone.warning => Dash.warningSoft,
      DashTone.danger => Dash.dangerSoft,
      DashTone.info => Dash.infoSoft,
      DashTone.brand => Dash.brandSoft,
      DashTone.neutral => Dash.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
    };

DashTone toneForStatus(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return DashTone.neutral;
  const ok = {'paid', 'approved', 'present', 'active', 'published', 'passed', 'pass', 'verified', 'success', 'completed', 'registered', 'male', 'female', 'on_time'};
  const bad = {'absent', 'rejected', 'failed', 'fail', 'unpaid', 'overdue', 'inactive', 'expired', 'missing', 'blocked'};
  const warn = {'pending', 'late', 'partial', 'due', 'draft', 'warning'};
  if (ok.contains(value)) return DashTone.success;
  if (bad.contains(value)) return DashTone.danger;
  if (warn.contains(value)) return DashTone.warning;
  return DashTone.info;
}

enum DashVariant { primary, secondary, ghost, danger, success, soft }

enum DashSize { sm, md }

/// React-style button: square-ish, 1px borders, subtle shadow on the primary.
class DashButton extends StatelessWidget {
  const DashButton({
    this.label,
    this.onPressed,
    this.icon,
    this.variant = DashVariant.secondary,
    this.size = DashSize.md,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  final String? label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DashVariant variant;
  final DashSize size;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final height = size == DashSize.sm ? 32.0 : 38.0;
    final horizontal = size == DashSize.sm ? 10.0 : 14.0;
    final fontSize = size == DashSize.sm ? 12.5 : 13.5;

    late Color background;
    late Color foreground;
    late Color? borderColor;
    late List<BoxShadow> elevation;

    switch (variant) {
      case DashVariant.primary:
        background = Dash.brand;
        foreground = CollegeColors.onPrimary;
        borderColor = null;
        elevation = Dash.dark ? const [] : [BoxShadow(color: Dash.brand.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))];
      case DashVariant.danger:
        background = Dash.dangerSoft;
        foreground = Dash.danger;
        borderColor = Dash.danger.withValues(alpha: 0.35);
        elevation = const [];
      case DashVariant.success:
        background = Dash.successSoft;
        foreground = Dash.success;
        borderColor = Dash.success.withValues(alpha: 0.35);
        elevation = const [];
      case DashVariant.soft:
        background = Dash.hover;
        foreground = Dash.ink;
        borderColor = null;
        elevation = const [];
      case DashVariant.ghost:
        background = Colors.transparent;
        foreground = Dash.muted;
        borderColor = null;
        elevation = const [];
      case DashVariant.secondary:
        background = Dash.surface;
        foreground = Dash.ink;
        borderColor = Dash.border;
        elevation = Dash.shadow;
    }

    final enabled = onPressed != null && !loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (icon != null)
          Icon(icon, size: size == DashSize.sm ? 15 : 17, color: foreground),
        if (icon != null || loading) const SizedBox(width: 7),
        if (label != null)
          Flexible(
            child: Text(
              label!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: fontSize, fontWeight: FontWeight.w600, height: 1.1),
            ),
          ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: background,
        borderRadius: Dash.cornersSm,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: Dash.cornersSm,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: Dash.cornersSm,
              border: borderColor == null ? null : Border.all(color: borderColor),
              boxShadow: elevation,
            ),
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class DashIconButton extends StatelessWidget {
  const DashIconButton({required this.icon, this.onPressed, this.tooltip, this.tone = DashTone.neutral, this.size = 34, super.key});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final DashTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Dash.surface,
      borderRadius: Dash.cornersSm,
      child: InkWell(
        onTap: onPressed,
        borderRadius: Dash.cornersSm,
        child: Ink(
          decoration: BoxDecoration(borderRadius: Dash.cornersSm, border: Border.all(color: Dash.border), boxShadow: Dash.shadow),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.46, color: toneInk(tone)),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// White bordered container used for every block of the dashboard.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.padding = const EdgeInsets.all(16),
    this.footer,
    this.fill = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final EdgeInsets padding;
  final Widget? footer;

  /// Uses the full available height, required when the panel holds an Expanded.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final hasHead = title != null || actions != null;
    return Container(
      decoration: BoxDecoration(
        color: Dash.surface,
        borderRadius: Dash.corners,
        border: Border.all(color: Dash.border),
        boxShadow: Dash.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (hasHead)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Dash.border)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(Dash.radius)),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    IconSquare(icon: icon!, tone: DashTone.brand, size: 32),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title ?? '', style: TextStyle(color: Dash.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.muted, fontSize: 12.5, height: 1.3)),
                          ),
                      ],
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: actions!),
                  ],
                ],
              ),
            ),
          Padding(padding: padding, child: child),
          if (footer != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Dash.border)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(Dash.radius))),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class IconSquare extends StatelessWidget {
  const IconSquare({required this.icon, this.tone = DashTone.brand, this.size = 38, super.key});

  final IconData icon;
  final DashTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: toneWash(tone), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.48, color: toneInk(tone)),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, this.subtitle, this.breadcrumb, this.actions, super.key});

  final String title;
  final String? subtitle;
  final List<String>? breadcrumb;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 620;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (breadcrumb != null && breadcrumb!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < breadcrumb!.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.chevron_right_rounded, size: 14, color: Dash.faint),
                    ),
                  Text(
                    breadcrumb![i],
                    style: TextStyle(color: i == breadcrumb!.length - 1 ? Dash.muted : Dash.faint, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        Text(title, style: TextStyle(color: Dash.ink, fontSize: narrow ? 22 : 25, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2)),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!, style: TextStyle(color: Dash.muted, fontSize: 13.5, height: 1.4)),
          ),
      ],
    );

    final actionWrap = actions == null || actions!.isEmpty
        ? null
        : Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions!);

    if (narrow && actionWrap != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, const SizedBox(height: 12), actionWrap]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: heading), if (actionWrap != null) ...[const SizedBox(width: 14), actionWrap]]),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {this.tone, this.dense = false, super.key});

  final String text;
  final DashTone? tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final resolved = tone ?? toneForStatus(text);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: toneWash(resolved), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text.trim().isEmpty ? '—' : text.trim(),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: toneInk(resolved), fontSize: dense ? 11 : 11.5, fontWeight: FontWeight.w700, height: 1.25),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: TextStyle(color: Dash.faint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.icon,
    this.tone = DashTone.brand,
    this.hint,
    this.progress,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final DashTone tone;
  final String? hint;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Dash.surface,
      borderRadius: Dash.corners,
      child: InkWell(
        onTap: onTap,
        borderRadius: Dash.corners,
        child: Ink(
          decoration: BoxDecoration(borderRadius: Dash.corners, border: Border.all(color: Dash.border), boxShadow: Dash.shadow),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.muted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
                    ),
                    if (icon != null) IconSquare(icon: icon!, tone: tone, size: 34),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value.trim().isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Dash.ink, fontSize: 26, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -0.6),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 11),
                  DashProgress(value: progress!, tone: tone),
                ],
                if (hint != null && hint!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(hint!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.faint, fontSize: 11.5, height: 1.3)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashProgress extends StatelessWidget {
  const DashProgress({required this.value, this.tone = DashTone.brand, this.height = 6, super.key});

  final double value;
  final DashTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.isNaN ? 0 : value.clamp(0, 1),
          backgroundColor: toneWash(tone),
          valueColor: AlwaysStoppedAnimation(toneInk(tone)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({this.title = 'Nothing here yet', this.message, this.icon = Icons.inbox_rounded, this.action, super.key});

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconSquare(icon: icon, tone: DashTone.neutral, size: 52),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: Dash.ink, fontSize: 15, fontWeight: FontWeight.w700)),
          if (message != null && message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message!, textAlign: TextAlign.center, style: TextStyle(color: Dash.muted, fontSize: 13, height: 1.4)),
            ),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action!),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, this.title = 'Could not load this data', super.key});

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconSquare(icon: Icons.cloud_off_rounded, tone: DashTone.danger, size: 52),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: Dash.ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Dash.muted, fontSize: 13, height: 1.4)),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: DashButton(label: 'Try again', icon: Icons.refresh_rounded, variant: DashVariant.primary, onPressed: onRetry),
            ),
        ],
      ),
    );
  }
}

/// Neutral shimmer block used while data is loading.
class DashSkeleton extends StatefulWidget {
  const DashSkeleton({this.width, this.height = 14, this.radius = 6, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  State<DashSkeleton> createState() => _DashSkeletonState();
}

class _DashSkeletonState extends State<DashSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: Dash.hover, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

class TableSkeleton extends StatelessWidget {
  const TableSkeleton({this.rows = 6, this.columns = 5, super.key});

  final int rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              color: r.isEven ? Colors.transparent : Dash.soft,
              child: Row(
                children: [
                  for (var c = 0; c < columns; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: c == columns - 1 ? 0 : 16),
                        child: DashSkeleton(width: double.infinity, height: 12, radius: 4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class CardGridSkeleton extends StatelessWidget {
  const CardGridSkeleton({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < count; i++)
          SizedBox(
            width: 210,
            child: Panel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  DashSkeleton(height: 11, width: 90),
                  SizedBox(height: 12),
                  DashSkeleton(height: 24, width: 70),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Search box used in every toolbar.
class DashSearch extends StatelessWidget {
  const DashSearch({required this.onChanged, this.hint = 'Search…', this.width = 240, this.controller, super.key});

  final ValueChanged<String> onChanged;
  final String hint;
  final double width;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: Dash.input(hint: hint, prefix: const Icon(Icons.search_rounded), suffix: controller == null ? null : IconButton(onPressed: () { controller!.clear(); onChanged(''); }, icon: const Icon(Icons.close_rounded, size: 16))),
      ),
    );
  }
}

/// Menu button that looks like the export split button of a react dashboard.
class DashMenu extends StatelessWidget {
  const DashMenu({
    required this.items,
    this.label,
    this.icon = Icons.more_horiz_rounded,
    this.variant = DashVariant.secondary,
    this.size = DashSize.md,
    this.loading = false,
    this.onPressed,
    super.key,
  });

  final List<DashMenuItem> items;
  final String? label;
  final IconData icon;
  final DashVariant variant;
  final DashSize size;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (loading) return DashButton(label: label ?? '', variant: variant, size: size, loading: true);
    return PopupMenuButton<DashMenuItem>(
      tooltip: label ?? 'Menu',
      position: PopupMenuPosition.under,
      color: Dash.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: Dash.cornersSm, side: BorderSide(color: Dash.border)),
      onSelected: (item) => item.onSelected(),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<DashMenuItem>(
            value: item,
            height: 40,
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: item.tone == null ? Dash.muted : toneInk(item.tone!)),
                const SizedBox(width: 10),
                Expanded(child: Text(item.label, style: TextStyle(color: Dash.ink, fontSize: 13, fontWeight: FontWeight.w600))),
                if (item.hint != null) Text(item.hint!, style: TextStyle(color: Dash.faint, fontSize: 11)),
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: DashButton(label: label ?? '', icon: icon, variant: variant, size: size, onPressed: onPressed ?? () {}),
      ),
    );
  }
}

class DashMenuItem {
  const DashMenuItem({required this.label, required this.icon, required this.onSelected, this.hint, this.tone});

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final String? hint;
  final DashTone? tone;
}

class DashSelect<T> extends StatelessWidget {
  const DashSelect({required this.value, required this.items, required this.onChanged, this.label, this.width, this.icon, super.key});

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final double? width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: Dash.input(
          hint: label,
          prefix: icon == null ? null : Icon(icon!),
          suffix: const Icon(Icons.expand_more_rounded, size: 17),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            hint: Text(label ?? '', style: TextStyle(color: Dash.faint, fontSize: 13)),
            icon: const SizedBox.shrink(),
            borderRadius: Dash.cornersSm,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Read-only key/value list that shows every field returned by the API.
class KeyValueList extends StatelessWidget {
  const KeyValueList({required this.entries, this.columns = 2, super.key});

  final List<(String, String)> entries;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyState(title: 'No fields returned', icon: Icons.data_object_rounded);
    final width = MediaQuery.sizeOf(context).width;
    final count = width >= 1200 ? 4 : width >= 820 ? 3 : width >= 520 ? 2 : 1;
    final itemWidth = (width - (count - 1) * 10) / count;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          SizedBox(
            width: itemWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Dash.soft, borderRadius: Dash.cornersSm, border: Border.all(color: Dash.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(humanKey(entry.$1), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.faint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text(entry.$2.trim().isEmpty ? '—' : entry.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Dash.ink, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// `student.user.name` becomes `Student · User · Name`.
String humanKey(String key) {
  final parts = key.split('.').where((part) => part.isNotEmpty).toList();
  return parts.map((part) => _words(part).join(' ')).join(' · ');
}

List<String> _words(String raw) {
  final spaced = raw.replaceAll('_', ' ').replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1 $2').trim();
  if (spaced.isEmpty) return [raw];
  return spaced.split(RegExp(r'\s+')).map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').toList();
}

class DashDivider extends StatelessWidget {
  const DashDivider({this.vertical = false, super.key});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? Container(width: 1, color: Dash.border, margin: const EdgeInsets.symmetric(vertical: 4))
        : Container(height: 1, color: Dash.border);
  }
}

void dashToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: error ? const Color(0xFFB91C1C) : const Color(0xFF0F172A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 3),
    ),
  );
}