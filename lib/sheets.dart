import 'package:googleapis/drive/v3.dart' as d;
import 'package:googleapis/sheets/v4.dart' as s;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

String ymd(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
double _n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '')) ?? 0;

class Account {
  final String name;
  final double balance;
  const Account(this.name, this.balance);
}

class Tx {
  final String date, type, category, desc, from, to;
  final double amount;
  const Tx(this.date, this.type, this.category, this.desc, this.from, this.to, this.amount);
}

class SheetsRepo {
  SheetsRepo(AuthClient c) : api = s.SheetsApi(c), drive = d.DriveApi(c);
  final s.SheetsApi api;
  final d.DriveApi drive;
  String? id;
  static const _title = 'My Finance';
  static const _tabs = ['المعاملات', 'الحسابات', 'التصنيفات', 'المستحقات', 'الالتزامات', 'الإعدادات'];

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    id = p.getString('sheet_id');
    if (id == null) {
      final found = await drive.files.list(
        q: "name = '$_title' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        pageSize: 1,
      );
      id = (found.files?.isNotEmpty ?? false) ? found.files!.first.id : await _create();
      await p.setString('sheet_id', id!);
    }
  }

  String _bal(int r) {
    String sf(String key, String type) =>
        "SUMIFS('المعاملات'!\$H:\$H,'المعاملات'!\$$key:\$$key,A$r,'المعاملات'!\$C:\$C,\"$type\")";
    return '=IF(A$r="","",B$r+${sf('F', 'قبض')}-${sf('F', 'صرف')}-${sf('F', 'تحويل بين حسابات')}+${sf('G', 'تحويل بين حسابات')})';
  }

  s.ValueRange _vr(String tab, String cell, List<List<Object?>> v) => s.ValueRange(range: "'$tab'!$cell", values: v);

  Future<String> _create() async {
    final created = await api.spreadsheets.create(s.Spreadsheet(
      properties: s.SpreadsheetProperties(title: _title),
      sheets: [
        for (var i = 0; i < _tabs.length; i++)
          s.Sheet(properties: s.SheetProperties(
            sheetId: i, title: _tabs[i], rightToLeft: true,
            gridProperties: s.GridProperties(frozenRowCount: 1)))
      ],
    ));
    final sid = created.spreadsheetId!;
    const exp = ['مأكولات ومشروبات', 'مواصلات', 'تسوق', 'فواتير', 'سكن', 'صحة', 'ترفيه', 'تعليم', 'هدايا', 'أخرى'];
    const inc = ['راتب', 'عمل حر', 'استثمار', 'هدية', 'أخرى'];
    await api.spreadsheets.values.batchUpdate(
      s.BatchUpdateValuesRequest(valueInputOption: 'USER_ENTERED', data: [
        _vr('المعاملات', 'A1', [['المعرّف', 'التاريخ', 'النوع', 'التصنيف', 'البيان', 'من حساب', 'إلى حساب', 'المبلغ', 'ملاحظات', 'وقت الإنشاء']]),
        _vr('الحسابات', 'A1', [['الحساب', 'الرصيد الافتتاحي', 'الرصيد الحالي']]),
        _vr('الحسابات', 'A2', [['كاش', 0], ['حساب بنكي', 0], ['ادخار', 0], ['محفظة إلكترونية', 0]]),
        _vr('الحسابات', 'C2', [for (var r = 2; r <= 21; r++) [_bal(r)]]),
        _vr('التصنيفات', 'A1', [['تصنيفات المصروفات', 'تصنيفات الدخل']]),
        _vr('التصنيفات', 'A2', [for (var i = 0; i < exp.length; i++) [exp[i], i < inc.length ? inc[i] : '']]),
        _vr('المستحقات', 'A1', [['المعرّف', 'التاريخ', 'النوع', 'البيان', 'المبلغ', 'الحالة', 'ملاحظات']]),
        _vr('الالتزامات', 'A1', [['المعرّف', 'تاريخ الاستحقاق', 'البيان', 'المبلغ', 'التكرار', 'الحالة', 'ملاحظات']]),
        _vr('الإعدادات', 'A1', [['المفتاح', 'القيمة'], ['إصدار القالب', '1.0'], ['العملة', 'ج.م']]),
      ]),
      sid,
    );
    await api.spreadsheets.batchUpdate(
      s.BatchUpdateSpreadsheetRequest(requests: [
        for (var i = 0; i < _tabs.length; i++)
          s.Request(repeatCell: s.RepeatCellRequest(
            range: s.GridRange(sheetId: i, startRowIndex: 0, endRowIndex: 1),
            cell: s.CellData(userEnteredFormat: s.CellFormat(
              backgroundColor: s.Color(red: .11, green: .09, blue: .07),
              horizontalAlignment: 'CENTER',
              textFormat: s.TextFormat(bold: true, foregroundColor: s.Color(red: .96, green: .89, blue: .71)))),
            fields: 'userEnteredFormat(backgroundColor,horizontalAlignment,textFormat)')),
        s.Request(repeatCell: s.RepeatCellRequest(
          range: s.GridRange(sheetId: 0, startRowIndex: 1, startColumnIndex: 1, endColumnIndex: 2),
          cell: s.CellData(userEnteredFormat: s.CellFormat(numberFormat: s.NumberFormat(type: 'DATE', pattern: 'yyyy-mm-dd'))),
          fields: 'userEnteredFormat.numberFormat')),
      ]),
      sid,
    );
    return sid;
  }

  Future<List<Account>> accounts() async {
    final r = await api.spreadsheets.values.get(id!, "'الحسابات'!A2:C21", valueRenderOption: 'UNFORMATTED_VALUE');
    return [
      for (final row in r.values ?? const <List<Object?>>[])
        if (row.isNotEmpty && '${row[0]}'.trim().isNotEmpty) Account('${row[0]}', row.length > 2 ? _n(row[2]) : 0)
    ];
  }

  Future<(List<String>, List<String>)> categories() async {
    final r = await api.spreadsheets.values.get(id!, "'التصنيفات'!A2:B60");
    final e = <String>[], i = <String>[];
    for (final row in r.values ?? const <List<Object?>>[]) {
      if (row.isNotEmpty && '${row[0]}'.trim().isNotEmpty) e.add('${row[0]}');
      if (row.length > 1 && '${row[1]}'.trim().isNotEmpty) i.add('${row[1]}');
    }
    return (e, i);
  }

  Future<List<Tx>> transactions() async {
    final r = await api.spreadsheets.values.get(id!, "'المعاملات'!A2:J");
    String c(List<Object?> row, int i) => i < row.length ? '${row[i]}' : '';
    return [
      for (final row in (r.values ?? const <List<Object?>>[]).reversed)
        if (row.length > 7) Tx(c(row, 1), c(row, 2), c(row, 3), c(row, 4), c(row, 5), c(row, 6), _n(row[7]))
    ];
  }

  Future<void> add({required DateTime date, required String type, required String category, required String desc,
      required String from, required String to, required double amount}) async {
    final now = DateTime.now();
    await api.spreadsheets.values.append(
      s.ValueRange(values: [
        [now.millisecondsSinceEpoch.toRadixString(36), ymd(date), type, category, desc, from, to, amount, '',
          '${ymd(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}']
      ]),
      id!, "'المعاملات'!A:J",
      valueInputOption: 'USER_ENTERED', insertDataOption: 'INSERT_ROWS',
    );
  }
}
