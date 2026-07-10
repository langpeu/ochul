# Supabase Cloud MCP Workflow

## 원칙

- 이 프로젝트는 Supabase 로컬 스택이 아니라 Supabase Cloud 프로젝트를 사용한다.
- Codex는 Supabase MCP를 통해 Cloud 프로젝트 상태를 확인하고 필요한 SQL 적용을 진행한다.
- `supabase start`, `supabase db reset` 등 로컬 컨테이너 기반 명령은 기본 workflow에서 사용하지 않는다.
- Cloud 대상 프로젝트를 확인하지 않은 상태에서 schema 변경을 적용하지 않는다.

## 작업 순서

1. Supabase MCP 연결과 대상 프로젝트를 확인한다.
2. 변경할 SQL을 `supabase/migrations`에 작성한다.
3. 적용 전 SQL의 위험도를 검토한다.
4. 개발용 Cloud 프로젝트에 먼저 적용한다.
5. RLS, Auth, 정책 동작을 검증한다.
6. 운영 반영이 필요하면 사용자 확인 후 진행한다.

## 금지

- service role key를 repo에 저장하지 않는다.
- 운영 DB에 검토되지 않은 SQL을 바로 적용하지 않는다.
- 로컬 Supabase 스택 검증 결과를 Cloud 검증으로 간주하지 않는다.
