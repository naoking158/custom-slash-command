---
description: "Coding rules for React: components, state management, performance, testing, accessibility, security. Loaded automatically when working with React files."
user-invocable: false
paths: ["**/*.jsx", "**/*.tsx"]
---

# React Coding Rules

When editing React code, consult the relevant reference before writing non-trivial code; follow these rules over general habits.

## INDEX

- `references/accessibility.md` — Semantic HTML over divs, button vs a, ARIA only when native semantics fall short, keyboard navigation and native dialog for modals, label association and accessible error messages, alt text rules.
- `references/components.md` — Function declarations with explicit Props (not React.FC), composition over prop drilling, render props, custom hook extraction, single-responsibility components, discriminated union props.
- `references/performance.md` — React.memo and stable references, useMemo/useCallback only where warranted, React.lazy + Suspense code splitting, key prop pitfalls, moving state down / lifting content up, list virtualization.
- `references/security.md` — dangerouslySetInnerHTML sanitization, javascript: URL and noopener/noreferrer handling, Zod validation at boundaries, CSP compliance (no eval/dynamic scripts), keeping secrets out of client code and localStorage.
- `references/state.md` — useState vs useReducer, computing derived values during render instead of storing them, useEffect antipatterns (sync/event logic), Context splitting by update frequency, lazy state initializers.
- `references/testing.md` — Role-based Testing Library queries, userEvent over fireEvent, findBy/waitFor for async, renderHook, avoiding manual act(), behavior-over-implementation testing, MSW for API mocking.
