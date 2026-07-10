# Ochul Tablet

방과후/공부방 출결 체크용 Flutter 태블릿 앱입니다.

## Local Secrets

실제 키는 repo에 커밋하지 않습니다.

```bash
cp Secrets.dev.example.config Secrets.dev.config
```

`Secrets.dev.config`에 개발 Supabase URL과 anon key를 넣고 실행합니다.

```bash
flutter run --dart-define-from-file=Secrets.dev.config
```

앱용 Secrets 파일에는 다음 client-safe 값만 넣습니다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` 또는 `SUPABASE_PUBLISHABLE_KEY`
- `AUTH_REDIRECT_URL`
- `APP_ENV`

`SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_JWKS_URL` 같은 서버용 값은 Flutter 앱용 Secrets 파일에 넣지 않습니다. 서버용 값은 Supabase Edge Function secret 또는 `supabase/functions/.env` 로컬 파일에만 둡니다.

Supabase Auth provider 설정의 redirect URL에는 다음 값을 허용해야 합니다.

```text
ochul://auth-callback
```

앱에서 Supabase 사용은 Auth와 Edge Function 호출로 제한합니다. 테이블 조회, RPC 직접 호출, service role key 사용은 Flutter 코드에 넣지 않습니다.
