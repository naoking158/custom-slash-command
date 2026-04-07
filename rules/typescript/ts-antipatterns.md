---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Antipatterns

## any

### DON'T: Use any — use unknown with type narrowing

`any` disables all type checking and propagates silently through the codebase.

```typescript
// DON'T
function parse(input: any): string {
  return input.name.toUpperCase(); // no safety
}

// DO — use unknown + narrowing
function parse(input: unknown): string {
  if (typeof input === "object" && input !== null && "name" in input) {
    const { name } = input as { name: unknown };
    if (typeof name === "string") {
      return name.toUpperCase();
    }
  }
  throw new Error("Invalid input");
}
```

### DO: Use Zod or similar for runtime validation of unknown data

```typescript
import { z } from "zod";

const UserSchema = z.object({
  name: z.string(),
  age: z.number(),
});

// DO
function parseUser(input: unknown): User {
  return UserSchema.parse(input);
}

// DON'T
function parseUser2(input: any): User {
  return input as User;
}
```

## Non-null Assertion

### DON'T: Overuse non-null assertion (!)

The `!` operator tells the compiler to trust you — but you might be wrong.

```typescript
// DON'T
const el = document.getElementById("root")!;
el.innerHTML = "hello";

// DO — handle the null case
const el = document.getElementById("root");
if (!el) {
  throw new Error("Root element not found");
}
el.innerHTML = "hello";
```

### DON'T: Chain non-null assertions

```typescript
// DON'T
const name = user!.profile!.name!;

// DO — use optional chaining + explicit check
const name = user?.profile?.name;
if (!name) {
  throw new Error("User name is required");
}
```

## Type Assertions

### DON'T: Use as for unsafe casts — prefer type guards

```typescript
// DON'T
const response = await fetch("/api/user");
const user = (await response.json()) as User;

// DO — validate the shape
const UserSchema = z.object({ id: z.string(), name: z.string() });
const response = await fetch("/api/user");
const user = UserSchema.parse(await response.json());
```

### DO: Use satisfies instead of as for compile-time checks

```typescript
// DON'T — as silently ignores extra/missing fields
const config = { timeout: 3000, retries: "three" } as Config;

// DO — satisfies catches type errors at compile time
const config = { timeout: 3000, retries: 3 } satisfies Config;
```

## namespace

### DON'T: Use namespace — use ES modules

```typescript
// DON'T
namespace Validation {
  export function isEmail(s: string): boolean { ... }
}

// DO — use ES module exports
// validation.ts
export function isEmail(s: string): boolean { ... }
```

## @ts-ignore / @ts-expect-error

### DON'T: Use @ts-ignore — use @ts-expect-error if absolutely necessary

`@ts-ignore` hides errors silently. `@ts-expect-error` at least fails when the error is fixed.

```typescript
// DON'T
// @ts-ignore
const result = brokenApi();

// DO — only if no other option, with explanation
// @ts-expect-error — upstream type is wrong, tracked in ISSUE-123
const result = brokenApi();
```

## Overloads

### DON'T: Use function overloads when a union or generics suffice

```typescript
// DON'T — unnecessary overload
function getItem(id: string): Item;
function getItem(id: number): Item;
function getItem(id: string | number): Item { ... }

// DO — simple union
function getItem(id: string | number): Item { ... }
```

## Optional Parameters

### DON'T: Use undefined union instead of optional parameter

```typescript
// DON'T
function greet(name: string | undefined): string { ... }

// DO
function greet(name?: string): string { ... }
```

## Overly Loose Types

### DON'T: Use object, Object, or {} as types

```typescript
// DON'T
function process(data: object): void { ... }
function handle(data: {}): void { ... }

// DO — define the expected shape
function process(data: Record<string, unknown>): void { ... }
function handle(data: { id: string; name: string }): void { ... }
```
