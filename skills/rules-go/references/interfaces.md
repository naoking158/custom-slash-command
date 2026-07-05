---
paths:
  - "**/*.go"
---

# Go Interface Design

## Core Principles

### DO: Keep interfaces small (1-3 methods)

The larger the interface, the weaker the abstraction. Prefer small, focused interfaces.

```go
// DO
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Closer interface {
    Close() error
}

// Compose when needed
type ReadCloser interface {
    Reader
    Closer
}
```

### DON'T: Create large, kitchen-sink interfaces

```go
// DON'T
type UserManager interface {
    Create(u *User) error
    Update(u *User) error
    Delete(id string) error
    Get(id string) (*User, error)
    List() ([]*User, error)
    SendEmail(id string, msg string) error
    ResetPassword(id string) error
}
```

## Consumer-Side Definition

### DO: Define interfaces where they are consumed, not where implemented

```go
// In the consumer package
package orderservice

// Only declare what this package needs
type UserGetter interface {
    Get(id string) (*user.User, error)
}

type Service struct {
    users UserGetter
}
```

### DON'T: Define interfaces in the implementation package preemptively

```go
// DON'T - don't force implementers into your interface
package user

type Store interface { // who uses this?
    Create(u *User) error
    Get(id string) (*User, error)
    // ...
}

type PostgresStore struct{ ... }
```

## Accept Interfaces, Return Structs

### DO: Accept interface parameters, return concrete types

```go
// DO
func New(logger Logger, store UserGetter) *Service {
    return &Service{logger: logger, store: store}
}

// DON'T - returning interface hides implementation
func New(logger Logger) Service { // returns interface
    return &service{logger: logger}
}
```

## Composition

### DO: Compose interfaces via embedding

```go
type ReadWriter interface {
    io.Reader
    io.Writer
}

type Handler interface {
    Validator
    Processor
}
```

## Avoid Unnecessary Abstraction

### DON'T: Create interfaces for a single implementation

If there's only one implementation and no testing need, use the concrete type directly. Interfaces are for decoupling, not decoration.

```go
// DON'T - premature abstraction
type Doer interface { Do() error }
type doer struct{}
func (d *doer) Do() error { ... }

// DO - just use the struct
type Processor struct{}
func (p *Processor) Process() error { ... }
```

### DON'T: Overuse interface{} / any

```go
// DON'T
func Process(data interface{}) interface{} { ... }

// DO - use generics or concrete types
func Process[T Processable](data T) (Result, error) { ... }
```

## Standard Library Patterns

### DO: Implement standard interfaces when appropriate

```go
// fmt.Stringer
func (u *User) String() string {
    return fmt.Sprintf("User(%s)", u.Name)
}

// error interface
func (e *AppError) Error() string {
    return e.Message
}

// io.Reader / io.Writer for stream processing
// sort.Interface for custom sorting
// encoding.TextMarshaler for custom text representation
```
