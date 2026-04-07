---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Error Handling

## Catch with unknown

### DO: Always type catch variables as unknown

TypeScript 4.4+ allows `useUnknownInCatchVariables`, and `strict` enables it.

```typescript
// DO
try {
  await fetchData();
} catch (error: unknown) {
  if (error instanceof Error) {
    console.error(error.message);
  } else {
    console.error("Unexpected error:", String(error));
  }
}

// DON'T — assumes error is Error
try {
  await fetchData();
} catch (error) {
  console.error(error.message); // might crash if error is not Error
}
```

## Result Type Pattern

### DO: Use a Result type for operations that can fail predictably

Explicit success/failure in the type system avoids forgotten try-catch.

```typescript
// DO
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function parseConfig(raw: string): Result<Config> {
  try {
    const data = JSON.parse(raw);
    return { ok: true, value: data as Config };
  } catch (e) {
    return { ok: false, error: new Error(`Invalid config: ${String(e)}`) };
  }
}

// Usage
const result = parseConfig(input);
if (!result.ok) {
  console.error(result.error.message);
  return;
}
console.log(result.value);

// DON'T — caller might forget try-catch
function parseConfig2(raw: string): Config {
  return JSON.parse(raw); // throws on invalid JSON
}
```

## Custom Error Classes

### DO: Define custom errors for domain-specific failure modes

```typescript
// DO
class ValidationError extends Error {
  constructor(
    public readonly field: string,
    message: string,
  ) {
    super(message);
    this.name = "ValidationError";
  }
}

class NotFoundError extends Error {
  constructor(
    public readonly resource: string,
    public readonly id: string,
  ) {
    super(`${resource} not found: ${id}`);
    this.name = "NotFoundError";
  }
}

// Usage
function getUser(id: string): User {
  const user = db.find(id);
  if (!user) throw new NotFoundError("User", id);
  return user;
}
```

### DO: Check custom errors with instanceof

```typescript
try {
  const user = getUser(id);
} catch (error: unknown) {
  if (error instanceof NotFoundError) {
    return res.status(404).json({ message: error.message });
  }
  if (error instanceof ValidationError) {
    return res.status(400).json({ field: error.field, message: error.message });
  }
  throw error; // re-throw unexpected errors
}
```

## Error Cause

### DO: Use the cause option to chain errors

```typescript
// DO — preserves the original error for debugging
try {
  const data = await fetchData(url);
} catch (error: unknown) {
  throw new Error("Failed to load user data", { cause: error });
}

// Access the chain
catch (error: unknown) {
  if (error instanceof Error) {
    console.error(error.message);       // "Failed to load user data"
    console.error(error.cause);          // original fetch error
  }
}
```

## Error Flow

### DO: Handle errors early, keep happy path unindented

```typescript
// DO
function processOrder(order: Order): Result<Receipt> {
  if (!order.items.length) {
    return { ok: false, error: new Error("Order has no items") };
  }
  if (!order.paymentMethod) {
    return { ok: false, error: new Error("No payment method") };
  }

  const total = calculateTotal(order.items);
  const receipt = chargePayment(order.paymentMethod, total);
  return { ok: true, value: receipt };
}

// DON'T — deeply nested
function processOrder2(order: Order): Receipt {
  if (order.items.length) {
    if (order.paymentMethod) {
      const total = calculateTotal(order.items);
      return chargePayment(order.paymentMethod, total);
    }
  }
  throw new Error("Invalid order");
}
```

## Exhaustive Error Handling

### DO: Use never for exhaustive switch checks

```typescript
function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${String(value)}`);
}

type ApiError = { code: "NOT_FOUND" } | { code: "UNAUTHORIZED" } | { code: "RATE_LIMITED" };

function handleError(error: ApiError): string {
  switch (error.code) {
    case "NOT_FOUND": return "Resource not found";
    case "UNAUTHORIZED": return "Please log in";
    case "RATE_LIMITED": return "Too many requests";
    default: return assertNever(error);
  }
}
```
