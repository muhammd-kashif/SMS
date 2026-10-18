import 'package:flutter/material.dart';
import '../data_table.dart';
import '../state.dart';
import '../widgets.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final staff = model.role == 'admin' || model.role == 'accountant' || model.role == 'teacher';
    final tabs = [
      model.t('Fees', 'فیس'),
      if (staff) model.t('Payments', 'ادائیگیاں'),
      if (staff) model.t('Defaulters', 'نادہندگان'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < tabs.length; i++)
                ChoiceChip(
                  label: Text(tabs[i]),
                  selected: tab == i,
                  onSelected: (_) => setState(() => tab = i),
                ),
              if (staff) TextButton(onPressed: () => model.go(Dest.collect), child: Text(model.t('Collect', 'وصول'))),
            ],
          ),
        ),
        Expanded(child: _feePage(model, staff)),
      ],
    );
  }

  Widget _feePage(AppModel model, bool staff) {
    if (!staff || tab == 0) {
      return RemoteTable(
        title: model.t('Student fees', 'طلبہ کی فیس'),
        subtitle: model.t('Same ledger as the website', 'ویب سائٹ والا کھاتہ'),
        load: () async {
          if (model.role == 'student' || model.role == 'parent') {
            final portal = await model.api.portal();
            final fees = portal['fees'];
            return model.api.asRows(fees is Map ? fees['items'] : fees);
          }
          return model.api.fees();
        },
        columns: [model.t('Student', 'طالب علم'), model.t('Fee', 'فیس'), model.t('Amount', 'رقم'), model.t('Pending', 'باقی'), model.t('Status', 'حالت')],
        cells: (row) => [
          Text(nested(row, ['student', 'user', 'name']).isEmpty ? textOf(row['title']) : nested(row, ['student', 'user', 'name'])),
          Text(textOf(row['title'])),
          Text(textOf(row['amount'])),
          Text(textOf(row['pending_amount'])),
          SoftBadge(textOf(row['status']), tone: textOf(row['status']) == 'paid' ? BadgeTone.ok : BadgeTone.warn),
        ],
      );
    }
    if (tab == 1) {
      return RemoteTable(
        title: model.t('Payments', 'ادائیگیاں'),
        subtitle: model.t('Receipts from the website ledger', 'ویب سائٹ کی رسیدیں'),
        load: model.api.payments,
        columns: [model.t('Receipt', 'رسید'), model.t('Student', 'طالب علم'), model.t('Amount', 'رقم'), model.t('Method', 'طریقہ')],
        cells: (row) => [
          Text(textOf(row['receipt_no'])),
          Text(nested(row, ['student', 'user', 'name'])),
          Text(textOf(row['amount'])),
          Text(textOf(row['method'])),
        ],
      );
    }
    return RemoteTable(
      title: model.t('Defaulters', 'نادہندگان'),
      subtitle: model.t('Fees past the due date', 'واجب الادا تاریخ گزر چکی'),
      load: model.api.defaulters,
      columns: [model.t('Student', 'طالب علم'), model.t('Fee', 'فیس'), model.t('Pending', 'باقی'), model.t('Due', 'واجب')],
      cells: (row) => [
        Text(nested(row, ['student', 'user', 'name'])),
        Text(textOf(row['title'])),
        Text(textOf(row['pending_amount'])),
        Text(textOf(row['due_date'])),
      ],
    );
  }
}

class CollectFeeScreen extends StatefulWidget {
  const CollectFeeScreen({super.key});

  @override
  State<CollectFeeScreen> createState() => _CollectFeeScreenState();
}

class _CollectFeeScreenState extends State<CollectFeeScreen> {
  List<Map<String, dynamic>> fees = [];
  int? feeId;
  final amount = TextEditingController();
  String method = 'cash';
  String? message;
  bool busy = false;
  var started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    AppScope.of(context).api.fees().then((rows) {
      final pending = rows.where((row) => textOf(row['status']) != 'paid').toList();
      if (!mounted) return;
      setState(() {
        fees = pending;
        feeId = pending.isEmpty ? null : pending.first['id'] as int?;
        if (pending.isNotEmpty) amount.text = textOf(pending.first['pending_amount']);
      });
    }).catchError((Object err) {
      if (mounted) setState(() => message = err.toString());
    });
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final model = AppScope.of(context);
    final id = feeId;
    final value = num.tryParse(amount.text);
    if (id == null || value == null) {
      setState(() => message = model.t('Choose a fee and an amount.', 'فیس اور رقم منتخب کریں۔'));
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await model.api.pay(id, value, method);
      if (mounted) setState(() => message = model.t('Payment recorded. Receipt is ready.', 'ادائیگی محفوظ ہو گئی۔ رسید تیار ہے۔'));
    } catch (err) {
      if (mounted) setState(() => message = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHead(title: model.t('Collect fee', 'فیس وصول کریں'), subtitle: model.t('Saved through POST /api/payments', 'POST /api/payments سے محفوظ')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: feeId,
                  decoration: InputDecoration(labelText: model.t('Voucher', 'واؤچر')),
                  items: [
                    for (final fee in fees)
                      DropdownMenuItem(
                        value: fee['id'] as int,
                        child: Text('${nested(fee, ['student', 'user', 'name'])} · ${textOf(fee['title'])} · ${textOf(fee['pending_amount'])}'),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    feeId = value;
                    final match = fees.where((fee) => fee['id'] == value);
                    if (match.isNotEmpty) amount.text = textOf(match.first['pending_amount']);
                  }),
                ),
                const SizedBox(height: 10),
                TextField(controller: amount, decoration: InputDecoration(labelText: model.t('Amount', 'رقم'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(labelText: model.t('Method', 'طریقہ')),
                  items: [
                    DropdownMenuItem(value: 'cash', child: Text(model.t('Cash', 'نقد'))),
                    DropdownMenuItem(value: 'bank', child: Text(model.t('Bank', 'بینک'))),
                    DropdownMenuItem(value: 'online', child: Text(model.t('Online', 'آن لائن'))),
                    DropdownMenuItem(value: 'other', child: Text(model.t('Other', 'دیگر'))),
                  ],
                  onChanged: (value) => setState(() => method = value ?? 'cash'),
                ),
                if (message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message!)),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: busy ? null : save, child: Text(model.t('Record payment', 'ادائیگی محفوظ کریں')))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
