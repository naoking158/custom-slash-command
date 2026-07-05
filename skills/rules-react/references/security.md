---
paths:
  - "**/*.tsx"
---

# React Security

## XSS Prevention

### DON'T: Use dangerouslySetInnerHTML without sanitization

Always sanitize HTML with DOMPurify before rendering.

```typescript
import DOMPurify from "dompurify";

// DO — sanitize with DOMPurify
function RichContent({ html }: { html: string }) {
  const sanitized = DOMPurify.sanitize(html);
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
}

// DON'T — unsanitized HTML injection
function RichContent({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
```

### DO: Prefer React's built-in escaping over raw HTML

```typescript
// DO — React escapes this automatically
function Comment({ text }: { text: string }) {
  return <p>{text}</p>;
}

// DON'T — bypasses React's escaping for no reason
function Comment({ text }: { text: string }) {
  return <p dangerouslySetInnerHTML={{ __html: text }} />;
}
```

## URL Validation

### DON'T: Allow javascript: protocol in dynamic URLs

```typescript
// DO
function isValidUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ["http:", "https:", "mailto:"].includes(parsed.protocol);
  } catch {
    return false;
  }
}

function SafeLink({ href, children }: { href: string; children: React.ReactNode }) {
  if (!isValidUrl(href)) {
    return <span>{children}</span>;
  }
  return <a href={href} rel="noopener noreferrer">{children}</a>;
}

// DON'T — allows javascript:alert('XSS')
function UnsafeLink({ href, children }: { href: string; children: React.ReactNode }) {
  return <a href={href}>{children}</a>;
}
```

### DO: Add rel="noopener noreferrer" to external links

```typescript
// DO
<a href={externalUrl} target="_blank" rel="noopener noreferrer">
  External Link
</a>

// DON'T — allows reverse tabnabbing
<a href={externalUrl} target="_blank">
  External Link
</a>
```

## Runtime Validation with Zod

### DO: Validate all external input at system boundaries

```typescript
import { z } from "zod";

// DO — validate API responses
const UserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1),
  email: z.string().email(),
  role: z.enum(["admin", "user", "viewer"]),
});

type User = z.infer<typeof UserSchema>;

async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  const data: unknown = await response.json();
  return UserSchema.parse(data);
}

// DON'T — trust API response blindly
async function fetchUser2(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  return response.json() as Promise<User>;
}
```

### DO: Validate URL parameters and form input

```typescript
// DO
const SearchParamsSchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  q: z.string().max(200).optional(),
  sort: z.enum(["name", "date", "relevance"]).default("relevance"),
});

function parseSearchParams(params: URLSearchParams) {
  return SearchParamsSchema.parse(Object.fromEntries(params));
}
```

## CSP Compliance

### DON'T: Use inline styles or scripts that violate CSP

```typescript
// DON'T — inline event handlers
<button onclick="handleClick()">Click</button>

// DO — React event handlers are CSP-safe
<button onClick={handleClick}>Click</button>

// DON'T — dynamic style strings
<div style="color: red; font-size: 16px">Text</div>

// DO — React style objects
<div style={{ color: "red", fontSize: 16 }}>Text</div>
```

### DON'T: Dynamically create script tags or use eval

```typescript
// DON'T
function loadScript(src: string) {
  const script = document.createElement("script");
  script.src = src;
  document.body.appendChild(script);
}

// DON'T
eval(userInput);
new Function(userInput)();
```

## State Secrets

### DON'T: Expose secrets in client-side code

```typescript
// DON'T — API keys in frontend code
const API_KEY = "sk-1234567890abcdef";
fetch(`/api/data?key=${API_KEY}`);

// DO — proxy through your backend
fetch("/api/proxy/data", {
  headers: { Authorization: `Bearer ${sessionToken}` },
});
```

### DON'T: Store sensitive data in localStorage

```typescript
// DON'T — accessible to XSS
localStorage.setItem("authToken", token);

// DO — use httpOnly cookies set by the server
// The token is managed server-side and sent via secure cookies
```
