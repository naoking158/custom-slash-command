---
paths:
  - "**/*.tsx"
---

# React Testing

## Query Priority

### DO: Use role-based queries first (Testing Library)

Follow the Testing Library query priority: accessible roles > labels > text > testId.

```typescript
import { render, screen } from "@testing-library/react";

// DO — queries by role (most accessible)
const button = screen.getByRole("button", { name: "Submit" });
const input = screen.getByLabelText("Email");
const heading = screen.getByRole("heading", { level: 1 });

// OK — when role is not available
const message = screen.getByText("Welcome back");

// LAST RESORT — test IDs
const widget = screen.getByTestId("custom-widget");

// DON'T — implementation details
const div = container.querySelector(".submit-btn");
const input = screen.getByPlaceholderText("Enter email");
```

## User Interaction

### DO: Use userEvent over fireEvent

`userEvent` simulates real browser interactions (focus, blur, keystrokes).

```typescript
import userEvent from "@testing-library/user-event";

// DO
test("submits form with user input", async () => {
  const user = userEvent.setup();
  render(<LoginForm onSubmit={mockSubmit} />);

  await user.type(screen.getByLabelText("Email"), "test@example.com");
  await user.type(screen.getByLabelText("Password"), "secret123");
  await user.click(screen.getByRole("button", { name: "Log in" }));

  expect(mockSubmit).toHaveBeenCalledWith({
    email: "test@example.com",
    password: "secret123",
  });
});

// DON'T — fireEvent skips intermediate events
fireEvent.change(input, { target: { value: "test@example.com" } });
fireEvent.click(button);
```

## Async Testing

### DO: Use findBy for async elements, waitFor for assertions

```typescript
// DO — findBy waits for element to appear
test("loads user data", async () => {
  render(<UserProfile userId="1" />);

  const name = await screen.findByText("John Doe");
  expect(name).toBeInTheDocument();
});

// DO — waitFor for async assertions
test("shows error on failure", async () => {
  server.use(http.get("/api/user", () => HttpResponse.error()));
  render(<UserProfile userId="1" />);

  await waitFor(() => {
    expect(screen.getByRole("alert")).toHaveTextContent("Failed to load");
  });
});

// DON'T — manual timers
await new Promise((r) => setTimeout(r, 1000));
expect(screen.getByText("loaded")).toBeInTheDocument();
```

## Custom Hook Testing

### DO: Use renderHook from Testing Library

```typescript
import { renderHook, act } from "@testing-library/react";

// DO
test("useCounter increments", () => {
  const { result } = renderHook(() => useCounter(0));

  act(() => {
    result.current.increment();
  });

  expect(result.current.count).toBe(1);
});

// DO — with wrapper for context providers
test("useAuth returns user", () => {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <AuthProvider>{children}</AuthProvider>
  );

  const { result } = renderHook(() => useAuth(), { wrapper });
  expect(result.current.user).toBeDefined();
});
```

## act() Usage

### DON'T: Wrap everything in act() — Testing Library handles it

```typescript
// DON'T — unnecessary act wrapping
act(() => {
  render(<Component />);
});

// DO — render and userEvent handle act internally
render(<Component />);
await user.click(button);

// DO — use act only for direct state updates outside of Testing Library
act(() => {
  result.current.setState(newValue);
});
```

## Test Structure

### DO: Test behavior, not implementation

```typescript
// DO — test what the user sees and does
test("displays error when email is invalid", async () => {
  const user = userEvent.setup();
  render(<RegistrationForm />);

  await user.type(screen.getByLabelText("Email"), "not-an-email");
  await user.click(screen.getByRole("button", { name: "Register" }));

  expect(screen.getByRole("alert")).toHaveTextContent("Invalid email");
});

// DON'T — test internal state or implementation
test("sets error state", () => {
  const { result } = renderHook(() => useForm());
  act(() => { result.current.validate(); });
  expect(result.current.errors.email).toBe("invalid");
});
```

### DO: Keep tests focused — one assertion group per test

```typescript
// DO
test("shows loading state", () => {
  render(<DataTable loading />);
  expect(screen.getByRole("progressbar")).toBeInTheDocument();
});

test("shows data when loaded", () => {
  render(<DataTable data={mockData} loading={false} />);
  expect(screen.getByRole("table")).toBeInTheDocument();
  expect(screen.getAllByRole("row")).toHaveLength(mockData.length + 1);
});

// DON'T — everything in one test
test("DataTable", () => {
  const { rerender } = render(<DataTable loading />);
  expect(screen.getByRole("progressbar")).toBeInTheDocument();
  rerender(<DataTable data={mockData} loading={false} />);
  expect(screen.getByRole("table")).toBeInTheDocument();
  // ...100 more assertions
});
```

## Mocking

### DO: Use MSW for API mocking over manual mocks

```typescript
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

// DO — MSW intercepts at the network level
const server = setupServer(
  http.get("/api/users/:id", ({ params }) =>
    HttpResponse.json({ id: params.id, name: "John" }),
  ),
);
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// DON'T — mock fetch or axios directly
jest.mock("axios");
```
