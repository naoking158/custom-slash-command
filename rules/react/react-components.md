---
paths:
  - "**/*.tsx"
---

# React Components

## Function Components

### DO: Use function declarations with explicit Props type — not React.FC

`React.FC` adds implicit `children`, breaks generics, and hurts readability.

```typescript
// DO
type UserCardProps = {
  name: string;
  email: string;
  avatarUrl?: string;
};

function UserCard({ name, email, avatarUrl }: UserCardProps) {
  return (
    <div>
      {avatarUrl && <img src={avatarUrl} alt={name} />}
      <h2>{name}</h2>
      <p>{email}</p>
    </div>
  );
}

// DON'T — React.FC
const UserCard: React.FC<UserCardProps> = ({ name, email }) => { ... };
```

### DO: Define children explicitly when needed

```typescript
// DO
type LayoutProps = {
  children: React.ReactNode;
  sidebar?: React.ReactNode;
};

function Layout({ children, sidebar }: LayoutProps) {
  return (
    <div className="layout">
      {sidebar && <aside>{sidebar}</aside>}
      <main>{children}</main>
    </div>
  );
}
```

## Composition Patterns

### DO: Prefer composition over prop drilling

```typescript
// DO — compose via children / render slots
function Card({ children }: { children: React.ReactNode }) {
  return <div className="card">{children}</div>;
}

function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="card-header">{children}</div>;
}

// Usage
<Card>
  <CardHeader>Title</CardHeader>
  <p>Content</p>
</Card>

// DON'T — monolithic component with many props
<Card title="Title" content="Content" headerStyle="bold" showBorder />
```

### DO: Use render props or children-as-function for flexible rendering

```typescript
// DO
type ListProps<T> = {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
};

function List<T>({ items, renderItem }: ListProps<T>) {
  return <ul>{items.map((item, i) => <li key={i}>{renderItem(item)}</li>)}</ul>;
}

// Usage
<List items={users} renderItem={(user) => <UserCard {...user} />} />
```

## Custom Hooks

### DO: Extract reusable logic into custom hooks

Extract when logic is shared across components or when a component becomes complex.

```typescript
// DO
function useDebounce<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}

// Usage
function SearchBar() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);
  // fetch with debouncedQuery...
}
```

### DON'T: Create hooks that are just wrappers around a single useState

```typescript
// DON'T — unnecessary abstraction
function useToggle() {
  const [value, setValue] = useState(false);
  const toggle = () => setValue((v) => !v);
  return [value, toggle] as const;
}

// OK only if reused across many components
```

## Component Responsibility

### DO: Keep components small and focused — one responsibility per component

```typescript
// DO — separate data fetching from presentation
function UserProfilePage({ userId }: { userId: string }) {
  const { data: user, isLoading } = useUser(userId);
  if (isLoading) return <Spinner />;
  if (!user) return <NotFound />;
  return <UserProfileView user={user} />;
}

function UserProfileView({ user }: { user: User }) {
  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.bio}</p>
    </div>
  );
}

// DON'T — mixing concerns
function UserProfilePage({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch(`/api/users/${userId}`).then(...) }, [userId]);
  // 200 lines of rendering mixed with data logic...
}
```

## Props Design

### DON'T: Pass too many props — consider composition or context

```typescript
// DON'T — prop explosion
<Header
  userName={user.name}
  userAvatar={user.avatar}
  userRole={user.role}
  notificationCount={notifications.length}
  onLogout={handleLogout}
  onSearch={handleSearch}
  theme={theme}
/>

// DO — group related data
<Header user={user} notifications={notifications} onLogout={handleLogout}>
  <SearchBar onSearch={handleSearch} />
</Header>
```

### DO: Use discriminated union props for conditional rendering

```typescript
// DO
type ButtonProps =
  | { variant: "link"; href: string }
  | { variant: "button"; onClick: () => void };

function Action(props: ButtonProps) {
  if (props.variant === "link") {
    return <a href={props.href}>Click</a>;
  }
  return <button onClick={props.onClick}>Click</button>;
}
```
