---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Async Patterns

## async/await

### DO: Use async/await over raw Promises

```typescript
// DO
async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch user: ${response.status}`);
  }
  return response.json();
}

// DON'T — nested .then chains
function fetchUser2(id: string): Promise<User> {
  return fetch(`/api/users/${id}`)
    .then((res) => {
      if (!res.ok) throw new Error("Failed");
      return res.json();
    })
    .then((data) => data as User);
}
```

### DO: Use Promise.all for independent concurrent operations

```typescript
// DO — runs in parallel
const [users, posts, comments] = await Promise.all([
  fetchUsers(),
  fetchPosts(),
  fetchComments(),
]);

// DON'T — sequential when they could be parallel
const users = await fetchUsers();
const posts = await fetchPosts();
const comments = await fetchComments();
```

## Promise.allSettled

### DO: Use Promise.allSettled when partial failure is acceptable

```typescript
// DO
const results = await Promise.allSettled([
  sendEmail(user1),
  sendEmail(user2),
  sendEmail(user3),
]);

const failures = results.filter(
  (r): r is PromiseRejectedResult => r.status === "rejected",
);
if (failures.length > 0) {
  console.error("Some emails failed:", failures.map((f) => f.reason));
}

// DON'T — Promise.all fails fast, losing partial results
try {
  await Promise.all([sendEmail(user1), sendEmail(user2), sendEmail(user3)]);
} catch {
  // which ones failed? which succeeded? unknown
}
```

## AbortController

### DO: Use AbortController for cancellable operations

```typescript
// DO
async function fetchWithTimeout(url: string, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { signal: controller.signal });
    return response;
  } finally {
    clearTimeout(timeoutId);
  }
}

// DO — cancel on component unmount (React)
useEffect(() => {
  const controller = new AbortController();

  fetchData(controller.signal).then(setData).catch((error: unknown) => {
    if (!controller.signal.aborted) {
      setError(error instanceof Error ? error : new Error(String(error)));
    }
  });

  return () => controller.abort();
}, []);
```

### DON'T: Ignore AbortError in catch blocks

```typescript
// DO — check for abort before handling error
try {
  const data = await fetch(url, { signal });
} catch (error: unknown) {
  if (error instanceof DOMException && error.name === "AbortError") {
    return; // expected cancellation, not an error
  }
  throw error;
}
```

## Async Iteration

### DO: Use for-await-of for async iterables

```typescript
// DO
async function processStream(stream: ReadableStream<Uint8Array>): Promise<string> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  return new TextDecoder().decode(Buffer.concat(chunks));
}
```

## Error Handling in Async Code

### DON'T: Use floating (unhandled) Promises

```typescript
// DON'T — unhandled rejection
async function save(): Promise<void> {
  await db.save(data);
}
save(); // no catch — crashes silently

// DO
save().catch((error: unknown) => {
  console.error("Failed to save:", error);
});

// DO — or use void to explicitly discard
void save();
```

### DON'T: Mix async/await with .then/.catch in the same function

```typescript
// DON'T
async function loadData(): Promise<Data> {
  const response = await fetch(url);
  return response.json().then((data) => transform(data));
}

// DO — use await consistently
async function loadData(): Promise<Data> {
  const response = await fetch(url);
  const data = await response.json();
  return transform(data);
}
```

## Top-level Await

### DO: Use top-level await only in modules, with caution

```typescript
// OK — in a module entry point
const config = await loadConfig();
const db = await connectDatabase(config.dbUrl);

export { db };

// DON'T — in a file that might be imported synchronously
// This blocks all importing modules
```
