---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Type System

## Strict Mode

### DO: Enable strict and noUncheckedIndexedAccess

These are non-negotiable for type safety.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

```typescript
// With noUncheckedIndexedAccess
const arr = [1, 2, 3];
const val = arr[0]; // type is number | undefined — forces null check

// DO
if (val !== undefined) {
  console.log(val.toFixed(2));
}

// DON'T — runtime error without the flag
console.log(arr[10].toFixed(2));
```

## satisfies Operator

### DO: Use satisfies for type checking while preserving literal inference

```typescript
type Route = { path: string; component: string };

// DO — type-checked AND preserves literal types
const routes = {
  home: { path: "/", component: "HomePage" },
  about: { path: "/about", component: "AboutPage" },
} satisfies Record<string, Route>;

routes.home.path; // type: "/"

// DON'T — loses literal types
const routes2: Record<string, Route> = {
  home: { path: "/", component: "HomePage" },
};
routes2.home.path; // type: string
```

## Discriminated Unions

### DO: Use discriminated unions for state modeling

```typescript
// DO
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

function render(state: AsyncState<User>) {
  switch (state.status) {
    case "idle": return <Placeholder />;
    case "loading": return <Spinner />;
    case "success": return <Profile user={state.data} />;
    case "error": return <ErrorMessage error={state.error} />;
  }
}

// DON'T — optional fields lead to impossible states
type AsyncState2<T> = {
  isLoading: boolean;
  data?: T;
  error?: Error;
};
```

## as const and Union Literal Types

### DO: Use as const instead of enum

```typescript
// DO
const Status = {
  Pending: "pending",
  Active: "active",
  Inactive: "inactive",
} as const;

type Status = (typeof Status)[keyof typeof Status];
// "pending" | "active" | "inactive"

// DON'T — enums have runtime behavior and poor tree-shaking
enum StatusEnum {
  Pending = "pending",
  Active = "active",
  Inactive = "inactive",
}
```

## Utility Types

### DO: Use built-in utility types appropriately

```typescript
// DO — Pick/Omit for derived types
type UserSummary = Pick<User, "id" | "name">;
type CreateUserInput = Omit<User, "id" | "createdAt">;

// DO — Partial for optional updates
function updateUser(id: string, updates: Partial<User>): Promise<User> { ... }

// DO — Record for dictionaries
type FeatureFlags = Record<string, boolean>;

// DON'T — manually redefine fields
type UserSummary2 = {
  id: string;
  name: string;
};
```

### DON'T: Over-nest utility types

```typescript
// DON'T — unreadable
type Foo = Partial<Pick<Required<Omit<User, "id">>, "name" | "email">>;

// DO — break into named intermediate types
type UserFields = Omit<User, "id">;
type RequiredUserFields = Required<UserFields>;
type Foo = Partial<Pick<RequiredUserFields, "name" | "email">>;
```

## Type Narrowing

### DO: Prefer type predicates for reusable narrowing

```typescript
// DO
function isNonNullable<T>(value: T): value is NonNullable<T> {
  return value != null;
}

const results = [1, null, 2, undefined, 3];
const valid = results.filter(isNonNullable); // number[]

// DON'T — inline narrowing loses type info in callbacks
const valid2 = results.filter((v) => v != null); // (number | null | undefined)[]
```

### DON'T: Use type assertions (as) to bypass the compiler

```typescript
// DON'T
const user = fetchData() as User;

// DO — validate at runtime
const user = userSchema.parse(fetchData());
```
