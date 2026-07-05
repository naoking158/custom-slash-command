---
paths:
  - "**/*.tsx"
---

# React Performance

## React.memo

### DO: Use React.memo for components that re-render often with same props

```typescript
// DO — expensive component with stable props
const ExpensiveChart = React.memo(function ExpensiveChart({ data }: { data: DataPoint[] }) {
  // Heavy rendering logic
  return <canvas>{/* ... */}</canvas>;
});

// DON'T — memo on every component "just in case"
const SimpleText = React.memo(({ text }: { text: string }) => <span>{text}</span>);
// Memo has overhead — only use when profiling shows a problem
```

### DON'T: Pass new object/array/function references to memoized components

```typescript
// DON'T — defeats memo because style is a new object every render
<MemoizedChild style={{ color: "red" }} />

// DO — stable reference
const style = useMemo(() => ({ color: "red" }), []);
<MemoizedChild style={style} />
```

## useMemo and useCallback

### DO: Use useMemo for expensive computations, not trivial ones

```typescript
// DO — expensive: sorting a large list
const sorted = useMemo(
  () => largeList.slice().sort((a, b) => a.name.localeCompare(b.name)),
  [largeList],
);

// DON'T — trivial: string concatenation
const greeting = useMemo(() => `Hello, ${name}`, [name]);
// Just write: const greeting = `Hello, ${name}`;
```

### DO: Use useCallback when passing callbacks to memoized children

```typescript
// DO — stable callback for memoized child
const handleClick = useCallback((id: string) => {
  setSelected(id);
}, []);

<MemoizedList items={items} onItemClick={handleClick} />

// DON'T — useCallback without a memoized consumer
const handleClick = useCallback(() => {
  doSomething();
}, []);
// If the consumer isn't memoized, useCallback is wasted overhead
```

## Code Splitting

### DO: Use React.lazy + Suspense for route-level splitting

```typescript
// DO
const Dashboard = React.lazy(() => import("./pages/Dashboard"));
const Settings = React.lazy(() => import("./pages/Settings"));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}

// DON'T — lazy load tiny components
const SmallIcon = React.lazy(() => import("./SmallIcon"));
// Network overhead > bundle savings for small components
```

## key Prop

### DON'T: Use array index as key for dynamic lists

```typescript
// DON'T — index keys cause bugs when list items are reordered/removed
{items.map((item, index) => (
  <ListItem key={index} item={item} />
))}

// DO — use a stable, unique identifier
{items.map((item) => (
  <ListItem key={item.id} item={item} />
))}
```

### DO: Use key to force remount when identity changes

```typescript
// DO — reset component state when user changes
<UserProfile key={userId} userId={userId} />

// Without key, React reuses the component instance and state persists
```

## Avoiding Unnecessary Re-renders

### DO: Move state down to where it's needed

```typescript
// DO — only SearchBar re-renders on input change
function Page() {
  return (
    <div>
      <SearchBar />
      <ExpensiveList items={items} />
    </div>
  );
}

function SearchBar() {
  const [query, setQuery] = useState("");
  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}

// DON'T — state in parent re-renders everything
function Page() {
  const [query, setQuery] = useState("");
  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <ExpensiveList items={items} /> {/* re-renders on every keystroke */}
    </div>
  );
}
```

### DO: Lift content up to avoid re-rendering children

```typescript
// DO — children are passed as props and don't re-render
function ScrollTracker({ children }: { children: React.ReactNode }) {
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handler = () => setScrollY(window.scrollY);
    window.addEventListener("scroll", handler);
    return () => window.removeEventListener("scroll", handler);
  }, []);

  return (
    <div>
      <ScrollIndicator position={scrollY} />
      {children}
    </div>
  );
}
```

## Virtualization

### DO: Virtualize long lists instead of rendering all items

```typescript
// DO — render only visible items
import { useVirtualizer } from "@tanstack/react-virtual";

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
  });

  return (
    <div ref={parentRef} style={{ height: 400, overflow: "auto" }}>
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((vItem) => (
          <div key={vItem.key} style={{ transform: `translateY(${vItem.start}px)` }}>
            {items[vItem.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}

// DON'T — render 10,000 items at once
{items.map((item) => <div key={item.id}>{item.name}</div>)}
```
