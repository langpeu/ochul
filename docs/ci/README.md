# CI Workflow Template

`github-actions-ci.yml` is the GitHub Actions workflow intended for this repo.

It is stored here because the current GitHub OAuth token cannot create or update
files under `.github/workflows` without the `workflow` scope.

To activate it after granting the correct GitHub permission, move it to:

```text
.github/workflows/ci.yml
```

The workflow checks:

- Flutter formatting, analysis, and tests
- Supabase Edge Function formatting and Deno type checks
- Public repository guardrails for local secrets, direct Flutter DB calls, and
  secret-like values
