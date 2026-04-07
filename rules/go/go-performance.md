---
paths:
  - "**/*.go"
---

# Go Performance Guidelines

## Measure First

### DO: Profile before optimizing

Never optimize without profiling. Use `pprof` to identify bottlenecks.

```go
import _ "net/http/pprof"

// Or programmatic profiling
f, _ := os.Create("cpu.prof")
pprof.StartCPUProfile(f)
defer pprof.StopCPUProfile()
```

```bash
go test -bench=. -cpuprofile=cpu.prof
go tool pprof cpu.prof
```

### DON'T: Optimize without evidence

Premature optimization is the root of all evil. Write clear code first, optimize measured bottlenecks.

## String Operations

### DO: Use strings.Builder for string concatenation

```go
// DO
var b strings.Builder
for _, s := range parts {
    b.WriteString(s)
}
result := b.String()

// DON'T
var result string
for _, s := range parts {
    result += s // allocates new string each iteration
}
```

## Slice Performance

### DO: Pre-allocate slices when capacity is known

```go
// DO
users := make([]User, 0, len(ids))
for _, id := range ids {
    u, err := getUser(id)
    if err != nil { continue }
    users = append(users, u)
}

// DON'T
var users []User // grows and reallocates repeatedly
for _, id := range ids {
    u, _ := getUser(id)
    users = append(users, u)
}
```

### DO: Pre-allocate maps when size is known

```go
// DO
m := make(map[string]int, len(items))
```

## Object Reuse

### DO: Use sync.Pool for frequently allocated temporary objects

```go
var bufPool = sync.Pool{
    New: func() any { return new(bytes.Buffer) },
}

func process(data []byte) string {
    buf := bufPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufPool.Put(buf)
    }()
    buf.Write(data)
    return buf.String()
}
```

## Receiver Types

### DO: Choose pointer vs value receivers intentionally

Use **pointer receivers** when:
- Method modifies the receiver
- Struct is large
- Consistency: if one method needs pointer, use pointer for all

Use **value receivers** when:
- Struct is small and immutable (e.g., `time.Time`, `Point{X, Y}`)
- Method is a simple accessor

```go
// Pointer - modifies state or large struct
func (s *Server) Close() error { s.closed = true; return nil }

// Value - small, immutable
func (p Point) Distance(q Point) float64 {
    return math.Sqrt(math.Pow(p.X-q.X, 2) + math.Pow(p.Y-q.Y, 2))
}
```

## Memory Allocation

### DON'T: Allocate in hot loops unnecessarily

```go
// DON'T
for i := 0; i < 1000000; i++ {
    buf := make([]byte, 256) // allocation per iteration
    process(buf)
}

// DO - reuse buffer
buf := make([]byte, 256)
for i := 0; i < 1000000; i++ {
    clear(buf)
    process(buf)
}
```

## I/O Performance

### DO: Use bufio for I/O operations

```go
// DO
scanner := bufio.NewScanner(file)
for scanner.Scan() {
    process(scanner.Text())
}

// DO - buffered writer
w := bufio.NewWriter(file)
defer w.Flush()
for _, line := range lines {
    fmt.Fprintln(w, line)
}
```

## Range Loops

### DO: Be aware of value copies in range (pre-Go 1.22)

```go
// In Go < 1.22, range copies the value
type BigStruct struct { Data [1024]byte }

// DON'T (pre-1.22) - copies BigStruct each iteration
for _, item := range bigItems {
    process(item)
}

// DO - use index to avoid copy
for i := range bigItems {
    process(&bigItems[i])
}

// In Go 1.22+, the loop variable is per-iteration, but
// large struct copy still applies with value range
```

## Benchmarking

### DO: Write benchmarks to validate optimizations

```go
func BenchmarkProcess(b *testing.B) {
    data := loadTestData()
    b.ResetTimer()
    for b.Loop() {
        process(data)
    }
}
```
