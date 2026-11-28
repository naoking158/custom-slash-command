// Command tighten compares the outbound-guard package of a pull request with
// the base branch's and tells whether the change is one scripts/ci/guardrail.sh
// may let through without a person's approval.
//
//	go run ./scripts/ci/tighten <base package dir> <head package dir>
//
// It passes when the test files are the base's byte for byte, except
// cases added to the guardTests table that only drive the test's fixture;
// when every non-test file builds on every platform
// bin/ is built for; and when the non-test files import nothing the base's do
// not. It reads source only and runs none of it.
//
// Exit status: 0 passes, 1 does not (the reasons on stderr), 2 usage error or
// a file could not be read or parsed.
package main

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	casesFile = "guard_test.go"
	casesVar  = "guardTests"
)

var targets = [][2]string{{"darwin", "arm64"}, {"darwin", "amd64"}, {"linux", "arm64"}, {"linux", "amd64"}}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: tighten <base package dir> <head package dir>")
		os.Exit(2)
	}
	problems, err := check(os.Args[1], os.Args[2])
	if err != nil {
		fmt.Fprintln(os.Stderr, "tighten:", err)
		os.Exit(2)
	}
	if len(problems) > 0 {
		for _, p := range problems {
			fmt.Fprintln(os.Stderr, "tighten:", p)
		}
		os.Exit(1)
	}
}

func check(baseDir, headDir string) ([]string, error) {
	baseTests, _, err := goFiles(baseDir)
	if err != nil {
		return nil, err
	}
	headTests, headSrc, err := goFiles(headDir)
	if err != nil {
		return nil, err
	}
	var problems []string
	if !equal(baseTests, headTests) {
		problems = append(problems, fmt.Sprintf("the test files are %v, not the base's %v", headTests, baseTests))
	}
	for _, name := range headTests {
		if !contains(baseTests, name) {
			continue
		}
		b, err := os.ReadFile(filepath.Join(baseDir, name))
		if err != nil {
			return nil, err
		}
		h, err := os.ReadFile(filepath.Join(headDir, name))
		if err != nil {
			return nil, err
		}
		if name == casesFile {
			ps, err := addedCases(b, h)
			if err != nil {
				return nil, err
			}
			problems = append(problems, ps...)
		} else if !bytes.Equal(b, h) {
			problems = append(problems, name+" differs from the base's")
		}
	}
	if !contains(headTests, casesFile) {
		problems = append(problems, casesFile+" is missing")
	}
	ps, err := platformsAndImports(baseDir, headDir, headSrc)
	if err != nil {
		return nil, err
	}
	return append(problems, ps...), nil
}

// goFiles lists the .go files in dir, test files and the others apart.
func goFiles(dir string) (tests, src []string, err error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, nil, err
	}
	for _, e := range entries {
		name := e.Name()
		switch {
		case !strings.HasSuffix(name, ".go"):
		case strings.HasSuffix(name, "_test.go"):
			tests = append(tests, name)
		default:
			src = append(src, name)
		}
	}
	return tests, src, nil
}

// platformsAndImports checks that every file of the head is built on every
// target, so no file or build tag holds code for one platform only, and that
// the head imports no package the base does not.
func platformsAndImports(baseDir, headDir string, headSrc []string) ([]string, error) {
	var problems []string
	baseImports := map[string]bool{}
	ctx := context("linux", "amd64")
	basePkg, err := ctx.ImportDir(baseDir, 0)
	if err != nil {
		return nil, fmt.Errorf("read the base package: %w", err)
	}
	for _, imp := range basePkg.Imports {
		baseImports[imp] = true
	}
	for _, t := range targets {
		ctx := context(t[0], t[1])
		pkg, err := ctx.ImportDir(headDir, 0)
		if err != nil {
			problems = append(problems, fmt.Sprintf("%s/%s: %v", t[0], t[1], err))
			continue
		}
		got := append([]string(nil), pkg.GoFiles...)
		sort.Strings(got)
		if !equal(got, headSrc) || len(pkg.IgnoredGoFiles) > 0 || len(pkg.InvalidGoFiles) > 0 || len(pkg.CgoFiles) > 0 {
			problems = append(problems, fmt.Sprintf("%s/%s builds %v and ignores %v; every file has to build on every platform",
				t[0], t[1], got, append(pkg.IgnoredGoFiles, pkg.InvalidGoFiles...)))
		}
		for _, imp := range pkg.Imports {
			if !baseImports[imp] {
				problems = append(problems, fmt.Sprintf("%s/%s imports %s, which the base does not", t[0], t[1], imp))
			}
		}
	}
	return dedupe(problems), nil
}

func context(goos, goarch string) build.Context {
	ctx := build.Default
	ctx.GOOS, ctx.GOARCH, ctx.CgoEnabled = goos, goarch, false
	ctx.BuildTags, ctx.ToolTags = nil, nil
	return ctx
}

// addedCases checks that head is base with cases added to the guardTests
// table: outside the table the files are the same, and the base's cases
// appear in the head in their order, byte for byte. Each added case may only
// use the fixture and pure functions (plainCase).
func addedCases(base, head []byte) ([]string, error) {
	b, err := casesOf(base)
	if err != nil {
		return nil, fmt.Errorf("base %s: %w", casesFile, err)
	}
	h, err := casesOf(head)
	if err != nil {
		return nil, fmt.Errorf("head %s: %w", casesFile, err)
	}
	if !bytes.Equal(base[:b.lbrace], head[:h.lbrace]) || !bytes.Equal(base[b.rbrace:], head[h.rbrace:]) {
		return []string{casesFile + " changes more than the cases of " + casesVar}, nil
	}
	var problems []string
	next := 0
	for i, e := range h.elts {
		if next < len(b.elts) && bytes.Equal(b.text(base, next), h.text(head, i)) {
			next++
			continue
		}
		if p := plainCase(e); p != "" {
			problems = append(problems, fmt.Sprintf("%s:%d: the added case %s", casesFile, h.fset.Position(e.Pos()).Line, p))
		}
	}
	if next < len(b.elts) {
		problems = append(problems, fmt.Sprintf("%s changes or removes the base's case at line %d",
			casesFile, b.fset.Position(b.elts[next].Pos()).Line))
	}
	return problems, nil
}

type cases struct {
	fset           *token.FileSet
	elts           []ast.Expr
	lbrace, rbrace int
}

func (c cases) text(src []byte, i int) []byte {
	return src[c.fset.Position(c.elts[i].Pos()).Offset:c.fset.Position(c.elts[i].End()).Offset]
}

func casesOf(src []byte) (cases, error) {
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, casesFile, src, parser.ParseComments)
	if err != nil {
		return cases{}, err
	}
	for _, d := range file.Decls {
		g, ok := d.(*ast.GenDecl)
		if !ok || g.Tok != token.VAR {
			continue
		}
		for _, s := range g.Specs {
			v := s.(*ast.ValueSpec)
			if len(v.Names) == 1 && v.Names[0].Name == casesVar && len(v.Values) == 1 {
				if lit, ok := v.Values[0].(*ast.CompositeLit); ok {
					return cases{fset, lit.Elts, fset.Position(lit.Lbrace).Offset, fset.Position(lit.Rbrace).Offset}, nil
				}
			}
		}
	}
	return cases{}, fmt.Errorf("no %s table", casesVar)
}

// fixtureNames are the names an added case may select on the fixture f and
// on what it holds: its helpers, its fields, and the calls of testing.T that
// only report. f.git is not among them: its arguments can run any command
// and change the repository the cases share.
var fixtureNames = map[string]bool{
	"guard": true, "in": true, "own": true, "write": true,
	"shipRepo": true, "mainAndWorktree": true, "newRepo": true, "runPayload": true,
	"deny": true, "allow": true, "ask": true, "decision": true,
	"tmp": true, "repo": true, "wt": true, "out": true, "lastCommand": true,
	"env": true, "Now": true, "Home": true,
	"t": true, "Fatal": true, "Fatalf": true, "Error": true, "Errorf": true, "Log": true, "Logf": true,
}

// pureFuncs are the package functions an added case may call.
var pureFuncs = map[string]bool{
	"strings.Contains": true, "strings.HasPrefix": true, "strings.HasSuffix": true,
	"strings.Join": true, "strings.Repeat": true, "strings.Count": true,
	"filepath.Join": true, "strconv.FormatInt": true, "strconv.Itoa": true, "fmt.Sprintf": true,
}

// fixturePathArgs are the helpers whose first argument names a file under
// the fixture's directory.
var fixturePathArgs = map[string]bool{"write": true, "newRepo": true}

// plainCase returns why e is not a case {"name", func(f *fx) {...}} whose
// body only drives the fixture f and calls pure functions, or "" when it is.
// Such a case writes only under its own fixture's directory, so it cannot
// change what another case sees.
func plainCase(e ast.Expr) string {
	lit, ok := e.(*ast.CompositeLit)
	if !ok || lit.Type != nil || len(lit.Elts) != 2 {
		return `is not {"name", func(f *fx) {...}}`
	}
	if name, ok := lit.Elts[0].(*ast.BasicLit); !ok || name.Kind != token.STRING {
		return "has no string name"
	}
	fn, ok := lit.Elts[1].(*ast.FuncLit)
	if !ok || fn.Type.Results != nil || len(fn.Type.Params.List) != 1 || len(fn.Type.Params.List[0].Names) != 1 ||
		fn.Type.Params.List[0].Names[0].Name != "f" || !isType(fn.Type.Params.List[0].Type, "*fx") {
		return "is not func(f *fx)"
	}
	return plainBlock(fn.Body.List, scope{"f": true})
}

// scope holds the local names a case has bound.
type scope map[string]bool

func (s scope) with(names ...string) scope {
	out := scope{}
	for k := range s {
		out[k] = true
	}
	for _, n := range names {
		out[n] = true
	}
	return out
}

func plainBlock(stmts []ast.Stmt, s scope) string {
	for _, st := range stmts {
		var p string
		p, s = plainStmt(st, s)
		if p != "" {
			return p
		}
	}
	return ""
}

func plainStmt(st ast.Stmt, s scope) (string, scope) {
	switch st := st.(type) {
	case *ast.ExprStmt:
		if _, ok := st.X.(*ast.CallExpr); !ok {
			return "has an expression statement that is not a call", s
		}
		return plainExpr(st.X, s), s
	case *ast.AssignStmt:
		if len(st.Lhs) != len(st.Rhs) {
			return "assigns several values from one", s
		}
		for _, r := range st.Rhs {
			if p := plainExpr(r, s); p != "" {
				return p, s
			}
		}
		if st.Tok == token.DEFINE {
			var names []string
			for _, l := range st.Lhs {
				id, ok := l.(*ast.Ident)
				if !ok || id.Name == "_" || s[id.Name] || isPackage(id.Name) {
					return "binds a name already in use", s
				}
				names = append(names, id.Name)
			}
			return "", s.with(names...)
		}
		if st.Tok != token.ASSIGN {
			return "assigns with " + st.Tok.String(), s
		}
		for _, l := range st.Lhs {
			if !local(l, s) {
				return "assigns to something other than a local or the fixture", s
			}
		}
		return "", s
	case *ast.IfStmt:
		if st.Init != nil {
			return "has an if with an init statement", s
		}
		if p := plainExpr(st.Cond, s); p != "" {
			return p, s
		}
		if p := plainBlock(st.Body.List, s); p != "" {
			return p, s
		}
		switch e := st.Else.(type) {
		case nil:
		case *ast.BlockStmt:
			return plainBlock(e.List, s), s
		case *ast.IfStmt:
			return plainStmt(e, s)
		}
		return "", s
	case *ast.RangeStmt:
		if st.Tok != token.DEFINE {
			return "has a range that assigns to existing names", s
		}
		if p := plainExpr(st.X, s); p != "" {
			return p, s
		}
		var names []string
		for _, v := range []ast.Expr{st.Key, st.Value} {
			if v == nil {
				continue
			}
			id, ok := v.(*ast.Ident)
			if !ok || s[id.Name] || isPackage(id.Name) {
				return "binds a name already in use", s
			}
			if id.Name != "_" {
				names = append(names, id.Name)
			}
		}
		return plainBlock(st.Body.List, s.with(names...)), s
	}
	return fmt.Sprintf("has a statement of type %T", st), s
}

// local reports whether e names a local or something the fixture holds.
func local(e ast.Expr, s scope) bool {
	switch e := e.(type) {
	case *ast.Ident:
		return s[e.Name] && e.Name != "f"
	case *ast.SelectorExpr:
		return fixtureNames[e.Sel.Name] && e.Sel.Name != "t" && (isIdent(e.X, "f") || local(e.X, s))
	}
	return false
}

func plainExpr(e ast.Expr, s scope) string {
	switch e := e.(type) {
	case *ast.BasicLit:
		return ""
	case *ast.Ident:
		if s[e.Name] || e.Name == "true" || e.Name == "false" || e.Name == "nil" {
			return ""
		}
		return "uses " + e.Name
	case *ast.ParenExpr:
		return plainExpr(e.X, s)
	case *ast.UnaryExpr:
		if e.Op != token.NOT && e.Op != token.SUB {
			return "uses the operator " + e.Op.String()
		}
		return plainExpr(e.X, s)
	case *ast.BinaryExpr:
		if p := plainExpr(e.X, s); p != "" {
			return p
		}
		return plainExpr(e.Y, s)
	case *ast.SelectorExpr:
		if id, ok := e.X.(*ast.Ident); ok && isPackage(id.Name) {
			return "uses " + id.Name + "." + e.Sel.Name + " other than in a call"
		}
		if !fixtureNames[e.Sel.Name] {
			return "uses ." + e.Sel.Name
		}
		return plainExpr(e.X, s)
	case *ast.CallExpr:
		if e.Ellipsis.IsValid() {
			return "spreads arguments with ..."
		}
		if sel, ok := e.Fun.(*ast.SelectorExpr); ok {
			if fixturePathArgs[sel.Sel.Name] && (len(e.Args) == 0 || !fixturePath(e.Args[0])) {
				return "passes " + sel.Sel.Name + " a path that may be outside the fixture's directory"
			}
			if id, ok := sel.X.(*ast.Ident); ok && isPackage(id.Name) {
				if !pureFuncs[id.Name+"."+sel.Sel.Name] {
					return "calls " + id.Name + "." + sel.Sel.Name
				}
			} else if p := plainExpr(e.Fun, s); p != "" {
				return p
			}
		} else if p := plainExpr(e.Fun, s); p != "" {
			return p
		}
		for _, a := range e.Args {
			if p := plainExpr(a, s); p != "" {
				return p
			}
		}
		return ""
	case *ast.CompositeLit:
		if e.Type != nil && !isType(e.Type, "[]string") && !isType(e.Type, "map[string]any") {
			return "builds a value that is not []string or map[string]any"
		}
		for _, el := range e.Elts {
			if p := plainExpr(el, s); p != "" {
				return p
			}
		}
		return ""
	case *ast.KeyValueExpr:
		if p := plainExpr(e.Key, s); p != "" {
			return p
		}
		return plainExpr(e.Value, s)
	case *ast.FuncLit:
		var names []string
		for _, field := range e.Type.Params.List {
			if !isType(field.Type, "int64") && !isType(field.Type, "string") {
				return "has a function whose parameter is not an int64 or a string"
			}
			for _, n := range field.Names {
				if s[n.Name] || isPackage(n.Name) {
					return "binds a name already in use"
				}
				names = append(names, n.Name)
			}
		}
		if e.Type.Results != nil {
			return "has a function that returns a value"
		}
		return plainBlock(e.Body.List, s.with(names...))
	}
	return fmt.Sprintf("uses %T", e)
}

// fixturePath reports whether e is a relative path literal, or one appended
// to f.tmp, f.repo or f.wt, with no ".." in it.
func fixturePath(e ast.Expr) bool {
	switch e := e.(type) {
	case *ast.BasicLit:
		return e.Kind == token.STRING && !strings.Contains(e.Value, "..") && !strings.HasPrefix(e.Value[1:], "/")
	case *ast.BinaryExpr:
		if e.Op != token.ADD {
			return false
		}
		lit, ok := e.Y.(*ast.BasicLit)
		if !ok || lit.Kind != token.STRING || strings.Contains(lit.Value, "..") {
			return false
		}
		if sel, ok := e.X.(*ast.SelectorExpr); ok && isIdent(sel.X, "f") {
			return sel.Sel.Name == "tmp" || sel.Sel.Name == "repo" || sel.Sel.Name == "wt"
		}
		return fixturePath(e.X)
	}
	return false
}

func isPackage(name string) bool {
	switch name {
	case "strings", "filepath", "strconv", "fmt":
		return true
	}
	return false
}

func isIdent(e ast.Expr, name string) bool {
	id, ok := e.(*ast.Ident)
	return ok && id.Name == name
}

// isType reports whether the type expression t is written as want, one of
// *fx, []string, map[string]any, int64 and string.
func isType(t ast.Expr, want string) bool {
	switch t := t.(type) {
	case *ast.Ident:
		return t.Name == want
	case *ast.StarExpr:
		return strings.HasPrefix(want, "*") && isType(t.X, want[1:])
	case *ast.ArrayType:
		return t.Len == nil && strings.HasPrefix(want, "[]") && isType(t.Elt, want[2:])
	case *ast.MapType:
		return want == "map[string]any" && isIdent(t.Key, "string") && isIdent(t.Value, "any")
	}
	return false
}

func equal(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func dedupe(list []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range list {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}
