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
}
