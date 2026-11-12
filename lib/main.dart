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

  Future<void> openAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: ivory,
      builder: (_) => AddSheet(repo: widget.repo, accounts: accs.map((a) => a.name).toList(), expCats: expCats, incCats: incCats),
    );
    if (ok == true) load();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : openAdd,
        backgroundColor: gold, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('إضافة حركة'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(err!)))
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
  const AddSheet({super.key, required this.repo, required this.accounts, required this.expCats, required this.incCats});
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

  Future<void> save() async {
    final a = double.tryParse(amount.text.replaceAll(',', '.'));
    final tr = type == 'تحويل بين حسابات';
    if (a == null || a <= 0) return setState(() => err = 'أدخل مبلغاً صحيحاً');
    if (from == null) return setState(() => err = 'اختر الحساب');
    if (tr && (to == null || to == from)) return setState(() => err = 'اختر حسابين مختلفين');
    setState(() { busy = true; err = null; });
    try {
      await widget.repo.add(
        date: date, type: type, category: tr ? 'تحويل' : (cat ?? 'أخرى'),
        desc: desc.text.trim().isEmpty ? type : desc.text.trim(), from: from!, to: tr ? to! : '', amount: a);
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
            child: Text(busy ? 'جاري الحفظ...' : 'حفظ في الشيت', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}
