---
paths:
  - "**/*.go"
---

# Go Comments

A comment costs every future reader time. Write one only when it says
something the code cannot: a doc comment on an exported identifier, or a
non-obvious constraint the code depends on. Everything else is noise.

## Doc Comments

### DO: Give every exported identifier a one-sentence doc comment that starts with its name

```go
// DO
// FindPreviousDeal returns the most recent lost deal for the customer, or
// ErrDealNotFound when none exists.
func FindPreviousDeal(ctx context.Context, customerID string) (*Deal, error)

// DON'T: restate the signature
// FindPreviousDeal finds the previous deal. Takes a context and a customer
// ID and returns a deal and an error.
```

### DON'T: Add doc comments to unexported helpers whose name already says it

```go
// DON'T
// validate validates the request.
func validate(req *Request) error

// DO: no comment — the name is the documentation
func validate(req *Request) error
```

## Inline Comments

### DON'T: Restate what the code does

```go
// DON'T
// Loop over the bookings and cancel each one.
for _, b := range bookings {
    cancel(b)
}
```

### DON'T: Justify or apologize for a decision

If the reason matters, state the constraint in one line. If it does not,
delete the comment. "This is not ideal but" or "we chose X because Y felt
heavy" is never what a reader needs.

```go
// DON'T
// We use errors.New here instead of the wrapped-error package because the
// stack trace felt heavy for a sentinel and callers don't need it anyway.
var ErrDealNotFound = errors.New("deal not found")

// DO
var ErrDealNotFound = errors.New("deal not found")

// DO (a constraint the reader cannot infer from the code)
// Sentinel: callers compare with errors.Is, so it must not carry a stack.
var ErrDealNotFound = errors.New("deal not found")
```

### DON'T: Record history, dates, PR numbers, or review IDs in code

Git holds history. A comment that says when or why something changed is
stale the moment the next change lands.

```go
// DON'T
// Changed on 2026-09-01 after the PR review (M003): now uses UTC.
start := now.In(time.UTC)

// DO
start := now.In(time.UTC) // start_date is defined in UTC
```

### DO: Write comments that stand alone

A comment must not depend on the design discussion that produced the code.
Spell the case out instead of using shorthand from that discussion.

```go
// DON'T
// Handle the non-existent GUID case.
if deal == nil {

// DO
// The CRM returns no deal when the customer was created outside the
// calendar flow; there is nothing to reopen.
if deal == nil {
```
