import 'package:supabase_flutter/supabase_flutter.dart';

class EdgeFunctionClient {
  const EdgeFunctionClient({this.client});

  final SupabaseClient? client;

  Future<Map<String, dynamic>> call(
    String functionName, {
    Map<String, dynamic> body = const {},
  }) async {
    final supabase = client ?? Supabase.instance.client;
    final response = await supabase.functions.invoke(functionName, body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{'data': data};
  }
}
