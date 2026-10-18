import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({required this.registering, super.key});

  final bool registering;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? camera;
  String? error;
  String status = '';
  bool busy = false;
  int samples = 0;
  final shots = <String>[];
  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? person;
  String personType = 'student';
  Map<String, dynamic>? result;
  var started = false;

  static const steps = [
    ('Look straight', 'سیدھا دیکھیں'),
    ('Turn slightly left', 'تھوڑا بائیں مڑیں'),
    ('Turn slightly right', 'تھوڑا دائیں مڑیں'),
    ('Tilt slightly up', 'تھوڑا اوپر جھکائیں'),
    ('Tilt slightly down', 'تھوڑا نیچے جھکائیں'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = AppScope.of(context);
    status = widget.registering
        ? model.t('Choose a person. The camera will take five photos.', 'شخص منتخب کریں۔ کیمرہ پانچ تصاویر لے گا۔')
        : model.t('Hold still. Attendance starts automatically.', 'رکے رہیں۔ حاضری خود لگے گی۔');
    if (started) return;
    started = true;
    _open();
  }

  Future<void> _open() async {
    final granted = await Permission.camera.request();
    if (!granted.isGranted) {
      if (mounted) setState(() => error = 'Camera permission is required.');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => error = 'No camera was found on this phone.');
        return;
      }
      final front = cameras.where((item) => item.lensDirection == CameraLensDirection.front);
      final chosen = front.isEmpty ? cameras.first : front.first;
      final controller = CameraController(chosen, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => camera = controller);
      if (widget.registering) {
        await _loadPeople();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await _captureAttendance();
      }
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    }
  }

  Future<void> _loadPeople() async {
    final api = AppScope.of(context).api;
    final rows = personType == 'teacher' ? await api.teachers() : await api.students();
    if (!mounted) return;
    setState(() {
      people = rows;
      person = null;
      shots.clear();
      samples = 0;
    });
  }

  Future<String?> _shot() async {
    final controller = camera;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return null;
    final file = await controller.takePicture();
    final bytes = await File(file.path).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _captureAttendance() async {
    if (busy || !mounted) return;
    final model = AppScope.of(context);
    setState(() {
      busy = true;
      result = null;
      error = null;
      status = model.t('Reading the face...', 'چہرہ پڑھا جا رہا ہے...');
    });
    try {
      final image = await _shot();
      if (image == null) return;
      final data = await model.api.faceScan(image);
      if (!mounted) return;
      setState(() {
        result = data;
        status = textOf(data['message']);
      });
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _captureSamples() async {
    final model = AppScope.of(context);
    if (person == null || busy) return;
    setState(() {
      busy = true;
      shots.clear();
      samples = 0;
      error = null;
    });
    try {
      for (var i = 0; i < steps.length; i++) {
        if (!mounted) return;
        setState(() => status = model.t(steps[i].$1, steps[i].$2));
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final image = await _shot();
        if (image == null) continue;
        shots.add(image);
        if (mounted) setState(() => samples = shots.length);
      }
      if (mounted) {
        setState(() => status = model.t('Five samples captured. Press save.', 'پانچ تصاویر لے لی گئیں۔ محفوظ کریں دبائیں۔'));
      }
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final model = AppScope.of(context);
    final chosen = person;
    if (chosen == null || shots.length < 3 || busy) return;
    setState(() {
      busy = true;
      error = null;
      status = model.t('Saving this face...', 'چہرہ محفوظ ہو رہا ہے...');
    });
    try {
      final data = await model.api.faceRegister(
        personType: personType,
        personId: chosen['id'] as int,
        images: shots,
      );
      if (!mounted) return;
      setState(() => status = textOf(data['message']));
      model.go(Dest.scan);
    } catch (err) {
      if (mounted) {
        setState(() {
          error = err.toString();
          status = err.toString();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final controller = camera;
    final personMap = result?['person'];
    final personName = personMap is Map ? textOf(personMap['name']) : '';
    final marked = result?['verified'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: controller.value.previewSize?.height ?? 1, height: controller.value.previewSize?.width ?? 1, child: CameraPreview(controller)),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent, Colors.black.withValues(alpha: 0.72)],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(140),
                border: Border.all(color: marked ? CollegeColors.ok : CollegeColors.secondary, width: 4),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(onPressed: () => model.go(model.role == 'student' || model.role == 'parent' ? Dest.portal : Dest.dashboard), icon: const Icon(Icons.close, color: Colors.white)),
                      Expanded(
                        child: Text(
                          widget.registering ? model.t('Register face', 'چہرہ رجسٹر کریں') : model.t('Mark attendance', 'حاضری لگائیں'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.registering) Text('$samples/5', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Spacer(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD0D8))),
                  ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (personName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('$personName · ${personMap is Map ? textOf(personMap['status']) : ''}'),
                      ],
                      if (widget.registering) ...[
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'student', label: Text(model.t('Student', 'طالب علم'))),
                            ButtonSegment(value: 'teacher', label: Text(model.t('Teacher', 'استاد'))),
                          ],
                          selected: {personType},
                          onSelectionChanged: busy
                              ? null
                              : (value) {
                                  setState(() => personType = value.first);
                                  _loadPeople();
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: person?['id'] as int?,
                          decoration: InputDecoration(labelText: model.t('Person', 'شخص')),
                          items: [
                            for (final row in people)
                              DropdownMenuItem(
                                value: row['id'] as int,
                                child: Text('${textOf(row['name'])} · ${textOf(row['student_code']).isEmpty ? textOf(row['employee_code']) : textOf(row['student_code'])}', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) {
                                  final match = people.where((row) => row['id'] == value);
                                  setState(() => person = match.isEmpty ? null : match.first);
                                  _captureSamples();
                                },
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: busy || shots.length < 3 ? null : _save,
                          child: Text(model.t('Save this face', 'یہ چہرہ محفوظ کریں')),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: busy ? null : _captureAttendance,
                          child: Text(busy ? model.t('Checking...', 'دیکھا جا رہا ہے...') : model.t('Scan again', 'دوبارہ اسکین')),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
