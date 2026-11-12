import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'auth.dart';
import 'sheets.dart';

void main() => runApp(const MyFinanceApp());

const ink = Color(0xFF1C1711), gold = Color(0xFFB8862F), ivory = Color(0xFFF5F0E6);
const goodC = Color(0xFF0F8A5F), badC = Color(0xFFC43D4B);

String money(double v) => v.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: gold), scaffoldBackgroundColor: ivory);
    return MaterialApp(
      title: 'My Finance',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: base.copyWith(textTheme: GoogleFonts.tajawalTextTheme(base.textTheme)),
      home: const Boot(),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  SheetsRepo? repo;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    restoreSession().then((c) {
      if (mounted) setState(() { repo = c == null ? null : SheetsRepo(c); loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (repo == null) return LoginPage(onDone: (c) => setState(() => repo = SheetsRepo(c)));
    return HomePage(repo: repo!, onLogout: () async { await signOut(); setState(() => repo = null); });
  }
}

BoxDecoration goldCard() => BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF17120B), Color(0xFF2C2112), Color(0xFF7D5D22)]),
      boxShadow: [BoxShadow(color: gold.withOpacity(.35), blurRadius: 40, offset: const Offset(0, 18))],
    );

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onDone});
  final void Function(AuthClient) onDone;
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  bool busy = false;
  String? err;
  Future<void> go() async {
    setState(() { busy = true; err = null; });
    try {
      widget.onDone(await signIn());
    } catch (e) {
      if (mounted) setState(() { busy = false; err = 'تعذر تسجيل الدخول: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: goldCard(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('My Finance', style: t.headlineMedium?.copyWith(color: const Color(0xFFF6E3B4), fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('إدارة مالية شخصية، بياناتك في حسابك أنت', textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE0BB6A), foregroundColor: ink, minimumSize: const Size.fromHeight(52)),
                onPressed: busy ? null : go,
                child: Text(busy ? 'في انتظار جوجل...' : 'تسجيل الدخول بجوجل', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.redAccent))),
            ]),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repo, required this.onLogout});
  final SheetsRepo repo;
  final VoidCallback onLogout;
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  List<Account> accs = [];
  List<Tx> txs = [];
  List<String> expCats = [], incCats = [];
  int tab = 0;
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; err = null; });
    try {
      await widget.repo.init();
      accs = await widget.repo.accounts();
      txs = await widget.repo.transactions();
      final c = await widget.repo.categories();
      expCats = c.$1;
      incCats = c.$2;
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() { loading = false; err = 'تعذر تحميل البيانات: $e'; });
    }
  }

  Future<void> openAdd({Tx? edit}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: ivory,
      builder: (_) => AddSheet(repo: widget.repo, accounts: accs.map((a) => a.name).toList(), expCats: expCats, incCats: incCats, edit: edit),
    );
    if (ok == true) load();
  }

  Future<void> openTx(Tx x) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ivory,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(x.desc.isEmpty ? x.category : x.desc, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${x.type} • ${x.category} • ${x.date} • ${money(x.amount)} ج.م'),
            const SizedBox(height: 16),
            FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: gold),
                onPressed: () => Navigator.pop(ctx, 'edit'),
                icon: const Icon(Icons.edit),
                label: const Text('تعديل')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'del'),
                icon: const Icon(Icons.delete_outline, color: badC),
                label: const Text('حذف', style: TextStyle(color: badC))),
          ]),
        ),
      ),
    );
    if (act == 'edit') {
      await openAdd(edit: x);
    } else if (act == 'del') {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('حذف الحركة؟'),
          content: const Text('هتتمسح من الشيت نهائياً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: badC))),
          ],
        ),
      );
      if (ok == true) {
        try {
          await widget.repo.delete(x.id);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
        }
        load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    double inc = 0, out = 0;
    for (final x in txs) {
      if (!x.date.startsWith(key)) continue;
      if (x.type == 'قبض') inc += x.amount;
      if (x.type == 'صرف') out += x.amount;
    }
    final total = accs.fold<double>(0, (p, a) => p + a.balance);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('My Finance', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ink)),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : openAdd,
        backgroundColor: gold, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('إضافة حركة'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(err!)))
              : tab == 1
                  ? StatsView(txs: txs)
                  : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: goldCard(),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('إجمالي الأرصدة', style: t.bodyMedium?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 6),
                          Text('${money(total)} ج.م', textDirection: TextDirection.ltr, style: t.headlineLarge?.copyWith(color: const Color(0xFFF6E3B4), fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: Text('دخل الشهر\n${money(inc)}', style: t.bodyMedium?.copyWith(color: const Color(0xFF6EE7B7)))),
                            Expanded(child: Text('مصروف الشهر\n${money(out)}', style: t.bodyMedium?.copyWith(color: const Color(0xFFFDA4AF)))),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Text('الحسابات', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final a in accs)
                          Container(
                            width: 160, padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9DFCC))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.name, style: t.bodySmall?.copyWith(color: ink.withOpacity(.6))),
                              const SizedBox(height: 4),
                              Text(money(a.balance), textDirection: TextDirection.ltr, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 20),
                      Text('آخر الحركات', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      if (txs.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد حركات بعد. اضغط "إضافة حركة" للبدء.')),
                      for (final x in txs.take(25))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => openTx(x),
                          leading: CircleAvatar(
                            backgroundColor: (x.type == 'قبض' ? goodC : x.type == 'صرف' ? badC : gold).withOpacity(.12),
                            child: Icon(x.type == 'قبض' ? Icons.south_west : x.type == 'صرف' ? Icons.north_east : Icons.swap_horiz,
                                color: x.type == 'قبض' ? goodC : x.type == 'صرف' ? badC : gold),
                          ),
                          title: Text(x.desc.isEmpty ? x.category : x.desc, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${x.category} • ${x.from}${x.to.isEmpty ? '' : ' ← ${x.to}'} • ${x.date}'),
                          trailing: Text('${x.type == 'صرف' ? '-' : x.type == 'قبض' ? '+' : ''}${money(x.amount)}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(fontWeight: FontWeight.w800, color: x.type == 'قبض' ? goodC : x.type == 'صرف' ? badC : ink)),
                        ),
                    ]),
                  ),
                ),
    );
  }
}

class AddSheet extends StatefulWidget {
  const AddSheet({super.key, required this.repo, required this.accounts, required this.expCats, required this.incCats, this.edit});
  final Tx? edit;
  final SheetsRepo repo;
  final List<String> accounts, expCats, incCats;
  @override
  State<AddSheet> createState() => _AddState();
}

class _AddState extends State<AddSheet> {
  String type = 'صرف';
  final amount = TextEditingController(), desc = TextEditingController();
  String? cat, from, to;
  DateTime date = DateTime.now();
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e == null) return;
    type = e.type;
    amount.text = e.amount.toString();
    desc.text = e.desc;
    date = DateTime.tryParse(e.date) ?? DateTime.now();
    final cats = type == 'قبض' ? widget.incCats : widget.expCats;
    cat = cats.contains(e.category) ? e.category : null;
    from = widget.accounts.contains(e.from) ? e.from : null;
    to = widget.accounts.contains(e.to) ? e.to : null;
  }

  Future<void> save() async {
    final a = double.tryParse(amount.text.replaceAll(',', '.'));
    final tr = type == 'تحويل بين حسابات';
    if (a == null || a <= 0) return setState(() => err = 'أدخل مبلغاً صحيحاً');
    if (from == null) return setState(() => err = 'اختر الحساب');
    if (tr && (to == null || to == from)) return setState(() => err = 'اختر حسابين مختلفين');
    setState(() { busy = true; err = null; });
    try {
      final cat0 = tr ? 'تحويل' : (cat ?? 'أخرى');
      final d0 = desc.text.trim().isEmpty ? type : desc.text.trim();
      if (widget.edit == null) {
        await widget.repo.add(date: date, type: type, category: cat0, desc: d0, from: from!, to: tr ? to! : '', amount: a);
      } else {
        await widget.repo.update(widget.edit!.id, date: date, type: type, category: cat0, desc: d0, from: from!, to: tr ? to! : '', amount: a);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { busy = false; err = 'تعذر الحفظ: $e'; });
    }
  }

  Widget dd(String label, String? v, List<String> items, void Function(String?) f) => DropdownButtonFormField<String>(
        value: v,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
        onChanged: f,
      );

  @override
  Widget build(BuildContext context) {
    final tr = type == 'تحويل بين حسابات';
    final cats = type == 'قبض' ? widget.incCats : widget.expCats;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'صرف', label: Text('صرف')),
              ButtonSegment(value: 'قبض', label: Text('قبض')),
              ButtonSegment(value: 'تحويل بين حسابات', label: Text('تحويل')),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() { type = s.first; cat = null; }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amount, autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'ج.م', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (!tr) ...[dd('التصنيف', cat, cats, (v) => setState(() => cat = v)), const SizedBox(height: 12)],
          dd(tr ? 'من حساب' : 'الحساب', from, widget.accounts, (v) => setState(() => from = v)),
          const SizedBox(height: 12),
          if (tr) ...[dd('إلى حساب', to, widget.accounts, (v) => setState(() => to = v)), const SizedBox(height: 12)],
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'البيان (اختياري)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('التاريخ: ${ymd(date)}'),
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => date = p);
            },
          ),
          if (err != null) Text(err!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: gold, minimumSize: const Size.fromHeight(52)),
            onPressed: busy ? null : save,
            child: Text(busy ? 'جاري الحفظ...' : (widget.edit == null ? 'حفظ في الشيت' : 'حفظ التعديل'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.txs});
  final List<Tx> txs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    String mk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final cats = <String, double>{};
    for (final x in txs) {
      if (x.type == 'صرف' && x.date.startsWith(mk(now))) cats[x.category] = (cats[x.category] ?? 0) + x.amount;
    }
    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (p, e) => p + e.value);
    final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
    double sum(String type, DateTime m) =>
        txs.where((x) => x.type == type && x.date.startsWith(mk(m))).fold<double>(0, (p, x) => p + x.amount);
    var maxV = 1.0;
    for (final m in months) {
      maxV = math.max(maxV, math.max(sum('قبض', m), sum('صرف', m)));
    }
    BoxDecoration box() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE9DFCC)));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: box(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مصروف الشهر حسب التصنيف', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${money(total)} ج.م', style: t.bodyMedium?.copyWith(color: badC, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (sorted.isEmpty) const Text('لا توجد مصروفات هذا الشهر بعد.'),
              for (final e in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${money(e.value)} (${(e.value / total * 100).round()}%)', textDirection: TextDirection.ltr),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: e.value / total, minHeight: 8, color: gold, backgroundColor: const Color(0xFFF1EADB)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: box(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('آخر 6 شهور: دخل ومصروف', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final m in months)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mk(m), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: LinearProgressIndicator(value: sum('قبض', m) / maxV, minHeight: 8, color: goodC, backgroundColor: const Color(0xFFE7F5EE))),
                      const SizedBox(width: 10),
                      SizedBox(width: 90, child: Text(money(sum('قبض', m)), textDirection: TextDirection.ltr, style: const TextStyle(color: goodC))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: LinearProgressIndicator(value: sum('صرف', m) / maxV, minHeight: 8, color: badC, backgroundColor: const Color(0xFFFBEBEC))),
                      const SizedBox(width: 10),
                      SizedBox(width: 90, child: Text(money(sum('صرف', m)), textDirection: TextDirection.ltr, style: const TextStyle(color: badC))),
                    ]),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
