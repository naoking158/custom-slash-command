---
paths:
  - "**/*.tsx"
---

# React State Management

## useState vs useReducer

### DO: Use useReducer for complex state with multiple sub-values

```typescript
// DO — useReducer for related state transitions
type FormState = {
  values: Record<string, string>;
  errors: Record<string, string>;
  isSubmitting: boolean;
};

type FormAction =
  | { type: "SET_FIELD"; field: string; value: string }
  | { type: "SET_ERROR"; field: string; error: string }
  | { type: "SUBMIT" }
  | { type: "SUBMIT_SUCCESS" }
  | { type: "SUBMIT_FAILURE"; errors: Record<string, string> };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case "SET_FIELD":
      return { ...state, values: { ...state.values, [action.field]: action.value } };
    case "SUBMIT":
      return { ...state, isSubmitting: true, errors: {} };
    case "SUBMIT_SUCCESS":
      return { ...state, isSubmitting: false };
    case "SUBMIT_FAILURE":
      return { ...state, isSubmitting: false, errors: action.errors };
    default:
      return state;
  }
}

// DON'T — multiple useState for tightly coupled state
const [values, setValues] = useState({});
const [errors, setErrors] = useState({});
const [isSubmitting, setIsSubmitting] = useState(false);
```

## Derived Values

### DO: Compute derived values during render — not in state

```typescript
// DO — derive from existing state
function TodoList({ todos }: { todos: Todo[] }) {
  const completedCount = todos.filter((t) => t.done).length;
  const pendingCount = todos.length - completedCount;

  return (
    <div>
      <p>Done: {completedCount} / Pending: {pendingCount}</p>
      {todos.map((todo) => <TodoItem key={todo.id} todo={todo} />)}
    </div>
  );
}

// DON'T — redundant state that can go out of sync
function TodoList({ todos }: { todos: Todo[] }) {
  const [completedCount, setCompletedCount] = useState(0);

  useEffect(() => {
    setCompletedCount(todos.filter((t) => t.done).length);
  }, [todos]);

  return <p>Done: {completedCount}</p>;
}
```

### DO: Use useMemo only when derivation is expensive

```typescript
// DO — expensive computation
const sortedItems = useMemo(
  () => items.slice().sort((a, b) => a.score - b.score),
  [items],
);

// DON'T — trivial computation wrapped in useMemo
const fullName = useMemo(() => `${first} ${last}`, [first, last]);
// Just write: const fullName = `${first} ${last}`;
```

## useEffect Antipatterns

### DON'T: Use useEffect for state synchronization

```typescript
// DON'T — state sync via effect
const [items, setItems] = useState<Item[]>([]);
const [filteredItems, setFilteredItems] = useState<Item[]>([]);
const [filter, setFilter] = useState("");

useEffect(() => {
  setFilteredItems(items.filter((item) => item.name.includes(filter)));
}, [items, filter]);

// DO — derive directly
const [items, setItems] = useState<Item[]>([]);
const [filter, setFilter] = useState("");
const filteredItems = items.filter((item) => item.name.includes(filter));
```

### DON'T: Use useEffect for event-driven logic

```typescript
// DON'T — effect triggered by a flag
const [submitted, setSubmitted] = useState(false);
useEffect(() => {
  if (submitted) {
    sendAnalytics("form_submitted");
    setSubmitted(false);
  }
}, [submitted]);

// DO — call directly in the event handler
function handleSubmit() {
  submitForm(data);
  sendAnalytics("form_submitted");
}
```

## Context

### DO: Split Context by update frequency

```typescript
// DO — separate static config from frequently changing state
const ThemeContext = createContext<Theme>(defaultTheme);
const AuthContext = createContext<AuthState>(defaultAuth);
const ToastContext = createContext<ToastState>(defaultToast);

// DON'T — one giant context that causes unnecessary re-renders
type AppState = {
  theme: Theme;
  auth: AuthState;
  toasts: Toast[];
  sidebar: SidebarState;
  // ... everything
};
const AppContext = createContext<AppState>(defaultState);
```

### DON'T: Use Context for high-frequency updates

```typescript
// DON'T — mouse position in context re-renders all consumers
const MouseContext = createContext({ x: 0, y: 0 });

// DO — use a ref + subscription or a state management library
```

## State Initialization

### DO: Use lazy initializer for expensive initial state

```typescript
// DO — function is called only once
const [state, setState] = useState(() => computeExpensiveInitialState());

// DON'T — computed every render, ignored after first
const [state, setState] = useState(computeExpensiveInitialState());
```
