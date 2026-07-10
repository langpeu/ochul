import 'package:supabase_flutter/supabase_flutter.dart';

enum EdgeHttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const EdgeHttpMethod(this.value);

  final String value;
}

class EdgeFunctionClient {
  const EdgeFunctionClient({this.client, this.functionName = 'edge-api'});

  final SupabaseClient? client;
  final String functionName;

  Future<Map<String, dynamic>> call(
    String path, {
    EdgeHttpMethod method = EdgeHttpMethod.get,
    Map<String, dynamic> body = const {},
  }) async {
    final supabase = client ?? Supabase.instance.client;
    final response = await supabase.functions.invoke(
      functionName,
      body: <String, dynamic>{
        'method': method.value,
        'path': path,
        'body': body,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        throw EdgeFunctionException(
          error['message'] as String? ?? 'API 요청에 실패했습니다.',
        );
      }
      return data;
    }
    return <String, dynamic>{'data': data};
  }
}

class EdgeFunctionException implements Exception {
  const EdgeFunctionException(this.message);

  final String message;

  @override
  String toString() => message;
}
