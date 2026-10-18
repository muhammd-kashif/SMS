import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

String mediaUrl(dynamic value) {
  final raw = textOf(value);
  if (raw.isEmpty) return '';
  final base = apiRoot.replaceFirst(RegExp(r'/api$'), '');
  final host = Uri.parse(base);
  if (raw.startsWith('http')) {
    final uri = Uri.parse(raw);
    return uri.replace(scheme: host.scheme, host: host.host, port: host.hasPort ? host.port : null).toString();
  }
  if (raw.startsWith('/')) return '$base$raw';
  return raw;
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({required this.name, this.url, this.size = 40, super.key});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    final photo = mediaUrl(url);
    if (!photo.startsWith('http')) return FaceMark(letter, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 60 ? 18 : size / 2),
      child: Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).round(),
        errorBuilder: (_, _, _) => FaceMark(letter, size: size),
      ),
    );
  }
}

class CollegeLogo extends StatelessWidget {
  const CollegeLogo({this.height = 72, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SchoolMark(size: height);
  }
}

class SchoolMark extends StatelessWidget {
  const SchoolMark({this.size = 112, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: CollegeColors.secondary, width: size > 80 ? 4 : 3),
        boxShadow: [BoxShadow(color: CollegeColors.sidebar.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }
}

class TealWave extends StatelessWidget {
  const TealWave({required this.height, this.flip = false, super.key});

  final double height;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: _WaveClip(flip: flip),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [CollegeColors.sidebarTop, CollegeColors.sidebar, CollegeColors.primary],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveClip extends CustomClipper<Path> {
  const _WaveClip({required this.flip});

  final bool flip;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (!flip) {
      path.lineTo(0, size.height * 0.72);
      path.quadraticBezierTo(size.width * 0.5, size.height * 1.08, size.width, size.height * 0.62);
      path.lineTo(size.width, 0);
      path.close();
    } else {
      path.moveTo(0, size.height * 0.38);
      path.quadraticBezierTo(size.width * 0.5, -size.height * 0.08, size.width, size.height * 0.42);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _WaveClip oldClipper) => oldClipper.flip != flip;
}

class BlueBar extends StatelessWidget {
  const BlueBar({required this.title, this.onBack, this.trailing, super.key});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CollegeColors.primary,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(onPressed: onBack, icon: Icon(Icons.arrow_back, color: CollegeColors.onPrimary))
              else
                const SizedBox(width: 16),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: CollegeColors.onPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class CollegeLoader extends StatelessWidget {
  const CollegeLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: CircularProgressIndicator(strokeWidth: 3, color: CollegeColors.primary),
            ),
            Padding(
              padding: EdgeInsets.all(22),
              child: Image(image: AssetImage('assets/logo.png'), fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}

class SoftBadge extends StatelessWidget {
  const SoftBadge(this.text, {this.tone = BadgeTone.ok, super.key});

  final String text;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      BadgeTone.ok => (CollegeColors.okBg, CollegeColors.ok),
      BadgeTone.warn => (CollegeColors.warnBg, CollegeColors.warn),
      BadgeTone.bad => (CollegeColors.dangerBg, CollegeColors.danger),
      BadgeTone.blue => (CollegeColors.blueBg, CollegeColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: colors.$2, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

enum BadgeTone { ok, warn, bad, blue }

class FaceMark extends StatelessWidget {
  const FaceMark(this.letter, {this.size = 36, super.key});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 60 ? 18 : 8),
        gradient: const LinearGradient(colors: [Color(0xFFDBE7F5), Color(0xFF8EAFD8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(letter, style: TextStyle(color: CollegeColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.38)),
    );
  }
}

class PageHead extends StatelessWidget {
  const PageHead({required this.title, required this.subtitle, this.action, super.key});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: narrow ? 24 : 30, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: CollegeColors.muted, height: 1.35)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                if (action != null) ...[const SizedBox(height: 10), action!],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                if (action != null) action!,
              ],
            ),
    );
  }
}

class Kpi extends StatelessWidget {
  const Kpi(this.label, this.value, {this.accent, super.key});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CollegeColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Container(
        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: accent ?? CollegeColors.primary, width: 4))),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: CollegeColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1)),
          ],
        ),
      ),
    );
  }
}

class DataCard extends StatelessWidget {
  const DataCard({required this.columns, required this.rows, super.key});

  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columns: [for (final column in columns) DataColumn(label: Text(column, style: TextStyle(color: CollegeColors.muted, fontSize: 12)))],
          rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(cell)])],
        ),
      ),
    );
  }
}

class FilterBar extends StatelessWidget {
  const FilterBar(this.labels, {super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: CollegeColors.line)),
              child: Text(label, style: TextStyle(color: CollegeColors.muted)),
            ),
        ],
      ),
    );
  }
}

String textOf(dynamic value) => value == null ? '' : value.toString();

String nested(Map row, List<String> path) {
  dynamic current = row;
  for (final key in path) {
    if (current is Map && current[key] != null) {
      current = current[key];
    } else if (current is Map && key == 'schoolClass' && current['school_class'] != null) {
      current = current['school_class'];
    } else {
      return '';
    }
  }
  return current?.toString() ?? '';
}

class BarChart extends StatelessWidget {
  const BarChart(this.heights, {this.fee = false, super.key});

  final List<double> heights;
  final bool fee;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final height in heights)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fee ? const Color(0xFFF6C27A) : const Color(0xFF8EAFD8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
