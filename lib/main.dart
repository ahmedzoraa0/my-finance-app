import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyFinanceApp());

const ink = Color(0xFF1C1711), gold = Color(0xFFB8862F), ivory = Color(0xFFF5F0E6);

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: gold),
      scaffoldBackgroundColor: ivory,
    );
    return MaterialApp(
      title: 'My Finance',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(textTheme: GoogleFonts.tajawalTextTheme(base.textTheme)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('أهلاً بك 👋', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF17120B), Color(0xFF2C2112), Color(0xFF7D5D22)],
                      ),
                      boxShadow: [BoxShadow(color: gold.withOpacity(.35), blurRadius: 40, offset: const Offset(0, 18))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي الأرصدة', style: t.bodyMedium?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('0.00 ج.م',
                            textDirection: TextDirection.ltr,
                            style: t.headlineLarge?.copyWith(color: const Color(0xFFF6E3B4), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('النسخة التجريبية 0.1 — خط البناء شغال ✅',
                      style: t.bodyMedium?.copyWith(color: ink.withOpacity(.6))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
