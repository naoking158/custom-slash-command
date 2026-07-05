---
description: "Coding rules for TypeScript: type system, error handling, async patterns, style/naming, antipatterns. Loaded automatically when working with TypeScript files."
user-invocable: false
paths: ["**/*.ts", "**/*.tsx"]
---

# TypeScript Coding Rules

When editing TypeScript code, consult the relevant reference before writing non-trivial code; follow these rules over general habits.

## INDEX

- `references/antipatterns.md` — Avoid any (use unknown + narrowing/Zod), non-null assertion overuse, unsafe as casts (prefer type guards/satisfies), namespace, @ts-ignore, needless overloads, undefined-union instead of optional params, object/{} types.
- `references/async-patterns.md` — async/await over raw Promises, Promise.all vs Promise.allSettled, AbortController and AbortError handling, for-await-of, floating Promise prevention, no async/await + .then mixing, top-level await caveats.
- `references/error-handling.md` — catch variables as unknown, Result type for predictable failures, custom error classes with instanceof, error chaining via cause, early-return error flow, never for exhaustive switches.
- `references/style-naming.md` — camelCase/PascalCase/UPPER_SNAKE_CASE conventions, is/has/can/should boolean prefixes, kebab-case vs PascalCase file naming, import grouping, no barrel exports in large projects, no I/T type prefixes.
- `references/type-system.md` — strict + noUncheckedIndexedAccess, satisfies for literal-preserving checks, discriminated unions for state, as const over enum, built-in utility types, type predicates over assertions.
