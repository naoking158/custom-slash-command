---
description: "Coding rules for Rails: ActiveRecord, architecture, API design, migrations, security, performance, testing, Ruby style, antipatterns. Loaded automatically when working with Rails files."
user-invocable: false
paths: ["**/*.rb", "**/Gemfile", "**/*.rake", "**/config/routes.rb"]
---

# Rails Coding Rules

When editing Rails code, consult the relevant reference before writing non-trivial code; follow these rules over general habits.

## INDEX

- `references/activerecord.md` — N+1 prevention with includes/preload/eager_load and strict_loading, batch processing via find_each/find_in_batches, efficient queries with pluck.
- `references/antipatterns.md` — Fat controllers, god models, excessive callbacks with side effects, -er/-or service naming, concerns used only to hide a single model's line count.
- `references/api.md` — API versioning via URL prefix + module namespace, dedicated API base controller, semantic HTTP status codes, serializers (jsonapi-serializer/jbuilder), error response format.
- `references/architecture.md` — Skinny controller/fat model, strong parameters (params.expect in Rails 8, require/permit in 7.x), when concerns are appropriate, domain-oriented service objects, validation placement.
- `references/migrations.md` — One logical change per migration, reversible change methods, descriptive naming, NOT NULL with defaults for production safety, explicit foreign keys.
- `references/performance.md` — Eager loading, fragment caching, low-level caching with TTL and race_condition_ttl, Solid Cache configuration (Rails 8).
- `references/ruby-style.md` — 2-space indentation, snake_case/PascalCase/SCREAMING_SNAKE_CASE naming, underscore-prefixed unused variables, no get_/set_ accessor prefixes.
- `references/security.md` — SQL injection prevention via parameterized/hash conditions, strong parameters, ERB auto-escaping for XSS, CSRF protection, Rails 8 built-in authentication.
- `references/testing.md` — Test pyramid, Minitest for Rails 8 defaults, RSpec describe/context/it structure, FactoryBot build/build_stubbed over create with minimal factories, WebMock/VCR for external APIs.
