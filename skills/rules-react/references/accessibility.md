---
paths:
  - "**/*.tsx"
---

# React Accessibility

## Semantic HTML

### DO: Use semantic HTML elements over generic divs

```typescript
// DO
<header>
  <nav>
    <ul>
      <li><a href="/">Home</a></li>
      <li><a href="/about">About</a></li>
    </ul>
  </nav>
</header>
<main>
  <article>
    <h1>Title</h1>
    <p>Content</p>
  </article>
</main>
<footer>© 2026</footer>

// DON'T — div soup
<div className="header">
  <div className="nav">
    <div className="link" onClick={goHome}>Home</div>
    <div className="link" onClick={goAbout}>About</div>
  </div>
</div>
<div className="main">
  <div className="title">Title</div>
  <div className="content">Content</div>
</div>
```

### DO: Use button for clickable actions, a for navigation

```typescript
// DO
<button onClick={handleDelete} type="button">Delete</button>
<a href="/settings">Settings</a>

// DON'T — div/span with onClick
<div onClick={handleDelete} className="clickable">Delete</div>
<span onClick={() => navigate("/settings")}>Settings</span>
```

## ARIA Attributes

### DON'T: Add redundant ARIA roles to semantic elements

Native HTML elements already have implicit roles.

```typescript
// DON'T — redundant
<button role="button">Click</button>
<nav role="navigation">...</nav>
<a href="/" role="link">Home</a>

// DO — semantic elements already convey their role
<button>Click</button>
<nav>...</nav>
<a href="/">Home</a>
```

### DO: Use ARIA only when native HTML cannot express the semantics

```typescript
// DO — custom tab component needs ARIA
<div role="tablist">
  <button role="tab" aria-selected={activeTab === 0} aria-controls="panel-0">
    Tab 1
  </button>
  <button role="tab" aria-selected={activeTab === 1} aria-controls="panel-1">
    Tab 2
  </button>
</div>
<div role="tabpanel" id="panel-0" aria-labelledby="tab-0">
  Panel content
</div>

// DO — live regions for dynamic content
<div role="status" aria-live="polite">
  {message && <p>{message}</p>}
</div>

<div role="alert" aria-live="assertive">
  {error && <p>{error}</p>}
</div>
```

## Keyboard Navigation

### DO: Ensure all interactive elements are keyboard accessible

```typescript
// DO — keyboard support for custom interactive element
function Accordion({ title, children }: { title: string; children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div>
      <button
        aria-expanded={isOpen}
        aria-controls="accordion-content"
        onClick={() => setIsOpen(!isOpen)}
      >
        {title}
      </button>
      {isOpen && (
        <div id="accordion-content" role="region">
          {children}
        </div>
      )}
    </div>
  );
}

// DON'T — not keyboard accessible
<div onClick={() => setIsOpen(!isOpen)}>
  {title}
</div>
```

### DO: Use native dialog element for modals

```typescript
// DO — native dialog handles focus trapping
function Dialog({ isOpen, onClose, children }: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    isOpen ? ref.current?.showModal() : ref.current?.close();
  }, [isOpen]);

  return (
    <dialog ref={ref} onClose={onClose}>
      {children}
      <button onClick={onClose}>Close</button>
    </dialog>
  );
}

// DON'T — custom div without focus management
<div className={isOpen ? "modal-open" : "modal-closed"}>{children}</div>
```

## Form Accessibility

### DO: Associate labels with form controls

```typescript
// DO — explicit label association
<label htmlFor="email">Email address</label>
<input id="email" type="email" aria-describedby="email-hint" />
<p id="email-hint">We'll never share your email.</p>

// DO — implicit label wrapping
<label>
  Email address
  <input type="email" />
</label>

// DON'T — no label
<input type="email" placeholder="Email" />
```

### DO: Provide accessible error messages

```typescript
// DO
<label htmlFor="password">Password</label>
<input
  id="password"
  type="password"
  aria-invalid={!!errors.password}
  aria-describedby={errors.password ? "password-error" : undefined}
/>
{errors.password && (
  <p id="password-error" role="alert">
    {errors.password}
  </p>
)}

// DON'T — error with no association to input
{errors.password && <span className="error">{errors.password}</span>}
```

## Images

### DO: Provide meaningful alt text — or empty alt for decorative images

```typescript
// DO
<img src={user.avatar} alt={`${user.name}'s profile photo`} />
<img src="/border.png" alt="" role="presentation" />

// DON'T
<img src={user.avatar} />
<img src={user.avatar} alt="image" />
```
