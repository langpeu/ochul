import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochul_tablet/main.dart' as app;

void main() {
  testWidgets('shows login screen in design mode', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Ochul'), findsOneWidget);
    expect(find.text('이메일로 시작'), findsOneWidget);
    expect(find.text('Supabase 설정 없이 화면 설계 모드로 실행 중입니다.'), findsOneWidget);
  });

  testWidgets('requires six digit attendance pin', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('이메일로 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이서연'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '123');
    await tester.tap(find.widgetWithText(FilledButton, '출석'));
    await tester.pumpAndSettle();

    expect(find.text('출결 비밀번호는 숫자 6자리여야 합니다.'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '출석'));
    await tester.pumpAndSettle();

    expect(find.text('이서연 출석 요청을 보냈습니다.'), findsOneWidget);
  });
}
