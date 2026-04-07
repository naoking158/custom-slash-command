---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Style & Naming Conventions

## Naming Rules

### DO: Use camelCase for variables and functions

```typescript
// DO
const maxRetryCount = 3;
function getUserById(id: string): User { ... }

// DON'T
const max_retry_count = 3;
function get_user_by_id(id: string): User { ... }
```

### DO: Use PascalCase for types, interfaces, classes, and components

```typescript
// DO
type UserProfile = { name: string; email: string };
interface AuthService { login(token: string): Promise<void> }
class HttpClient { ... }

// DON'T
type userProfile = { name: string; email: string };
interface authService { login(token: string): Promise<void> }
```

### DO: Use UPPER_SNAKE_CASE for constants

```typescript
// DO
const MAX_RETRY_COUNT = 3;
const API_BASE_URL = "/api/v1";

// DON'T
const maxRetryCount_Constant = 3;
const apibaseurl = "/api/v1";
```

### DO: Prefix boolean variables with is, has, can, should

```typescript
// DO
const isLoading = true;
const hasPermission = checkPermission(user);
const canEdit = user.role === "admin";

// DON'T
const loading = true;
const permission = checkPermission(user);
```

## File Naming

### DO: Use kebab-case for .ts files, PascalCase for .tsx component files

```
// DO
utils/
  parse-config.ts
  http-client.ts
components/
  UserProfile.tsx
  SearchBar.tsx

// DON'T
utils/
  parseConfig.ts
  HttpClient.ts
components/
  userProfile.tsx
  search-bar.tsx
```

## Import Organization

### DO: Use named imports and group by origin

Prefer named imports over default imports for better refactoring support.

```typescript
// DO
import { useState, useEffect } from "react";

import { clsx } from "clsx";
import { z } from "zod";

import { UserProfile } from "@/components/UserProfile";
import { useAuth } from "@/hooks/useAuth";

// DON'T - unorganized, default imports where named is better
import React from "react";
import useAuth from "@/hooks/useAuth";
import { z } from "zod";
import { useState } from "react";
```

### DON'T: Use barrel exports (index.ts) in large projects

Barrel exports can cause circular dependencies and slow build times.

```typescript
// DON'T - barrel re-export
// index.ts
export { UserProfile } from "./UserProfile";
export { SearchBar } from "./SearchBar";
export { Modal } from "./Modal";

// DO - import directly from source
import { UserProfile } from "@/components/UserProfile";
```

## Type Naming

### DO: Prefix generic type parameters descriptively

```typescript
// DO
function merge<TSource, TTarget>(source: TSource, target: TTarget): TSource & TTarget { ... }
type ApiResponse<TData> = { data: TData; status: number };

// DON'T - single-letter generics without context
function merge<A, B>(source: A, target: B): A & B { ... }
type ApiResponse<T> = { data: T; status: number };
```

### DON'T: Prefix interfaces with I or types with T

```typescript
// DO
interface AuthService { ... }
type UserProfile = { ... };

// DON'T - Hungarian notation
interface IAuthService { ... }
type TUserProfile = { ... };
```
