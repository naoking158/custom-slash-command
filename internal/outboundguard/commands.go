package outboundguard

import (
	"regexp"
	"strings"
)

// command is one command on the line that sends something out.
//
//	push: Dir is where it runs, Rest its arguments (quotes removed, assignments
//	      expanded, "?" for one the line does not show).
//	pr:   Rest is the gh command with quoted strings and $( ) emptied; it ends
//	      in " ?" when the line cuts its arguments short.
//	text: Rest is "git" or "gh", for a command that carries a message, or
//	      "gh pr merge", whose directory the PR rules judge.
//
// Dir is "?" when the line does not show it and "?case" when a case statement
// precedes the command. For pr, Repos are the repositories gh is told to use
// instead of Dir's (-R or --repo with its value as the next word, GH_REPO
// assigned just before gh) and Also the ones it may act on besides (an
// attached -R<repo>, a pull request URL, a repos/OWNER/NAME path, any other
// GH_REPO assignment); "" stands for one the line does not show. Args are the
// words of a pr command with their quotes removed, unexpanded.
type command struct {
	Kind, Dir, Rest string
	Repos, Also     []string
	Args            []string
}

type literal struct {
	content string
	expand  bool
}

type scope struct {
	dir  *string
	vars map[string]string
}

// commandParser follows the directory and variables of a command line while
// it looks for the commands that send something out.
type commandParser struct {
	lit          []literal
	vars         map[string]string
	dir          *string
	saved        []scope
	opaque       bool
	home         *string
	out          []command
	ghMay        []string
	gitElsewhere bool // the line sets a variable that may point git elsewhere
}

func strPtr(s string) *string { return &s }

func copyVars(m map[string]string) map[string]string {
	c := make(map[string]string, len(m))
	for k, v := range m {
		c[k] = v
	}
	return c
}

// parseCommands lists the outbound commands of cmd, run from cwd.
func parseCommands(cmd, cwd string, home *string) []command {
	p := &commandParser{vars: map[string]string{}, home: home}
	if home != nil {
		p.vars["HOME"] = *home
	}
	if cwd != "" {
		p.dir = strPtr(cwd)
	}
	s := heredocs(cmd, func(header, _, rest string) string { return header + rest })
	s = quotes(s, func(kind quoteKind, whole, content string) string {
		switch kind {
		case escaped:
			return whole
		case comment:
			return ""
		}
		p.lit = append(p.lit, literal{content, kind == doubleQuoted})
		return marker(len(p.lit) - 1)
	})
	s = strings.ReplaceAll(s, "\\\n", " ")
	p.gitElsewhere = setsGitEnv(p.envText(s))
	for _, seg := range splitOn(s, listSep(true, "<>|&")) {
		p.segment(stripRedirections(seg))
	}
	return p.out
}

func (p *commandParser) segment(seg string) {
	var open, closed []int
	for i := 0; i < len(seg); i++ {
		switch seg[i] {
		case '(':
			open = append(open, i)
		case ')':
			if len(open) > 0 {
				open = open[:len(open)-1]
			} else {
				closed = append(closed, i)
			}
		}
	}
	var pieces []string
	from := 0
	for _, at := range append(append([]int{}, closed...), open...) {
		pieces = append(pieces, seg[from:at])
		from = at + 1
	}
	pieces = append(pieces, seg[from:])
	last := len(pieces) - 1
	for i, piece := range pieces {
		switch {
		case i < len(closed):
			if i == 0 {
				p.command(piece)
			} else {
				p.emit(piece, p.dir, false)
				if moves(piece) {
					p.dir = nil
				}
			}
			if n := len(p.saved); n > 0 {
				p.dir, p.vars = p.saved[n-1].dir, p.saved[n-1].vars
				p.saved = p.saved[:n-1]
			}
		case i < last:
			p.emit(piece, p.dir, true)
			outer := copyVars(p.vars)
			for _, name := range assignedNames(piece) {
				delete(outer, name)
			}
			dir := p.dir
			if moves(piece) {
				dir = nil
			}
			p.saved = append(p.saved, scope{dir, outer})
		case len(closed) > 0 && len(open) == 0:
			p.emit(piece, p.dir, false)
			if moves(piece) {
				p.dir = nil
			}
		default:
			p.command(piece)
		}
	}
}

// value expands a word the way the shell would, or reports that the line does
// not show its value (a command substitution or an unknown variable).
func (p *commandParser) value(word string) (string, bool) {
	if strings.HasPrefix(word, "~") && (len(word) == 1 || word[1] == '/') {
		home := ""
		if p.home != nil {
			home = *p.home
		}
		word = home + word[1:]
	}
	var out strings.Builder
	i := 0
	for i < len(word) {
		var part string
		expand := true
		if idx, end, ok := markerAt(word, i); ok && idx < len(p.lit) {
			part, expand = p.lit[idx].content, p.lit[idx].expand
			i = end
		} else {
			j := i + 1
			for j < len(word) {
				if _, _, ok := markerAt(word, j); ok {
					break
				}
				j++
			}
			part = word[i:j]
			i = j
		}
		if expand {
			v, ok := p.expand(part)
			if !ok {
				return "", false
			}
			part = v
		}
		out.WriteString(part)
	}
	return out.String(), true
}

func (p *commandParser) expand(s string) (string, bool) {
	if strings.Contains(s, "`") || strings.Contains(s, "$(") {
		return "", false
	}
	var b strings.Builder
	known := true
	i := 0
	for i < len(s) {
		if s[i] == '$' && i+1 < len(s) {
			if s[i+1] == '{' {
				j := i + 2
				for j < len(s) && isWord(s[j]) {
					j++
				}
				if j > i+2 && j < len(s) && s[j] == '}' {
					v, ok := p.vars[s[i+2:j]]
					known = known && ok
					b.WriteString(v)
					i = j + 1
					continue
				}
			} else if isWord(s[i+1]) {
				j := i + 1
				for j < len(s) && isWord(s[j]) {
					j++
				}
				v, ok := p.vars[s[i+1:j]]
				known = known && ok
				b.WriteString(v)
				i = j
				continue
			}
		}
		b.WriteByte(s[i])
		i++
	}
	out := b.String()
	if !known || strings.Contains(out, "$") {
		return "", false
	}
	return out, true
}

// enter returns the directory a cd to word from base leads to.
func (p *commandParser) enter(base *string, word string) *string {
	path, ok := p.value(word)
	if !ok || path == "" || path == "-" {
		return nil
	}
	if strings.HasPrefix(path, "/") {
		return strPtr(path)
	}
	if base == nil {
		return nil
	}
	return strPtr(*base + "/" + path)
}

func (p *commandParser) unknown() string {
	if p.opaque {
		return "?case"
	}
	return "?"
}

func orUnknown(dir *string, unknown string) string {
	if dir == nil {
		return unknown
	}
	return *dir
}

func (p *commandParser) emit(text string, at *string, cut bool) {
	unknown := p.unknown()
	if p.opaque {
		at = nil
	}
	if start, opts, end, ok := gitSub(text, "push", 0, p.wordValue); ok {
		in, elsewhere := p.gitDir(at, text[:start], opts)
		where := orUnknown(in, unknown)
		if elsewhere {
			where = gitElsewhereDir
		}
		argEnd := strings.IndexByte(text[end:], ')')
		if argEnd < 0 {
			argEnd = len(text) - end
		}
		var args []string
		for _, a := range fields(text[end : end+argEnd]) {
			v, ok := p.value(a)
			if !ok || pushArgUnreadable(v) {
				v = "?"
			}
			args = append(args, v)
		}
		p.out = append(p.out, command{"push", where, strings.Join(args, " "), nil, nil, nil})
	}
	for from := 0; ; {
		start, end, ok := findGh(text, from, ghPRSend)
		if !ok {
			break
		}
		from = end
		gh := flattenParens(text[start:])
		closedParen := false
		if k := strings.IndexByte(gh, ')'); k >= 0 {
			gh, closedParen = gh[:k], true
		}
		var words []string
		for _, t := range fields(gh) {
			words = append(words, p.literalText(t))
		}
		repos, also := p.namedRepos(gh)
		repos = append(p.prefixGhRepo(text[:start]), repos...)
		also = append(append([]string{}, p.ghMay...), also...)
		gh = p.emptyQuotes(gh)
		if cut && !closedParen {
			gh += " ?"
		}
		gh = strings.Join(splitKeepEmpty(gh), " ")
		gh = strings.TrimSuffix(gh, " ")
		p.out = append(p.out, command{"pr", orUnknown(at, unknown), gh, repos, also, words})
	}
	if start, opts, _, ok := gitSub(text, "commit", 0, p.wordValue); ok {
		in, elsewhere := p.gitDir(at, text[:start], opts)
		where := orUnknown(in, unknown)
		if elsewhere {
			where = gitElsewhereDir
		}
		p.out = append(p.out, command{"text", where, "git", nil, nil, nil})
	} else if start, end, ok := findGh(text, 0, ghPRText); ok {
		rest := "gh"
		if isCmd(strings.Join(fields(text[start:end]), " "), "gh pr merge") {
			rest = "gh pr merge"
		}
		p.out = append(p.out, command{"text", orUnknown(at, unknown), rest, nil, nil, nil})
	}
}

var (
	pullURL = regexp.MustCompile(`https?://[^/[:space:]]+/([^/[:space:]]+/[^/[:space:]]+)/pull/`)
	apiRepo = regexp.MustCompile(`(^|/)repos/([^/[:space:]]+)/([^/?#[:space:]]+)`)
)

// prefixGhRepo returns the GH_REPO values assigned in the words that
// directly precede gh (`GH_REPO=x gh`, `env GH_REPO=x gh`).
func (p *commandParser) prefixGhRepo(before string) []string {
	var out []string
	toks := fields(before)
	for k := len(toks) - 1; k >= 0; k-- {
		t := toks[k]
		if t == "env" {
			continue
		}
		eq := strings.IndexByte(t, '=')
		if eq < 1 || !allWord(t[:eq]) {
			break
		}
		if t[:eq] == "GH_REPO" {
			out = append(out, p.known(t[eq+1:]))
		}
	}
	return out
}

// known is the value of word, or "" when the line does not show it.
func (p *commandParser) known(word string) string {
	v, ok := p.value(word)
	if !ok {
		return ""
	}
	return v
}

// namedRepos returns the repositories gh is told to use (-R / --repo and the
// next word, -R after other short options in one word as gh reads them) and,
// from any word, the ones it may act on: an attached -R<repo>, which may be
// another option's value, pull request URLs and repos/OWNER/NAME paths. {owner}/{repo} is the directory's own repository and
// is not listed.
func (p *commandParser) namedRepos(gh string) (repos, also []string) {
	toks := fields(gh)
	if gr, ok := ghGrammarOf(gh); ok {
		words := make([]word, len(toks))
		for i, t := range toks {
			words[i] = word{text: p.literalText(t)}
		}
		for _, o := range gr.options(words) {
			if !o.is("R", "repo") || !o.hasValue || strings.HasPrefix(toks[o.first], "-R") || toks[o.first] == "--repo" || strings.HasPrefix(toks[o.first], "--repo=") {
				continue
			}
			if o.attached {
				also = append(also, p.known(o.value))
			} else {
				repos = append(repos, p.known(o.value))
			}
		}
	}
	for i := 0; i < len(toks); i++ {
		t := toks[i]
		switch {
		case t == "-R" || t == "--repo":
			if i+1 < len(toks) {
				i++
				repos = append(repos, p.known(toks[i]))
			}
			continue
		case strings.HasPrefix(t, "--repo="):
			repos = append(repos, p.known(t[len("--repo="):]))
			continue
		case strings.HasPrefix(t, "-R"):
			also = append(also, p.known(t[2:]))
			continue
		}
		v, ok := p.value(t)
		if !ok {
			raw := p.literalText(t)
			if strings.Contains(raw, "://") || strings.Contains(raw, "repos/") {
				also = append(also, "")
			}
			continue
		}
		for _, m := range pullURL.FindAllStringSubmatch(v, -1) {
			also = append(also, m[1])
		}
		for _, m := range apiRepo.FindAllStringSubmatch(v, -1) {
			if m[2] != "{owner}" || m[3] != "{repo}" {
				also = append(also, m[2]+"/"+m[3])
			}
		}
	}
	return repos, also
}

// literalText replaces each marker in s with the text it holds, unexpanded.
func (p *commandParser) literalText(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); {
		if idx, end, ok := markerAt(s, i); ok && idx < len(p.lit) {
			b.WriteString(p.lit[idx].content)
			i = end
			continue
		}
		b.WriteByte(s[i])
		i++
	}
	return b.String()
}

// splitKeepEmpty collapses each whitespace run of s to one space boundary:
// joined with " " it gives s with every run replaced by a single space.
func splitKeepEmpty(s string) []string {
	var out []string
	start := 0
	i := 0
	for i < len(s) {
		if isSpace(s[i]) {
			out = append(out, s[start:i])
			for i < len(s) && isSpace(s[i]) {
				i++
			}
			start = i
			continue
		}
		i++
	}
	return append(out, s[start:])
}

// emptyQuotes replaces each marker with "" (double-quoted) or ”.
func (p *commandParser) emptyQuotes(s string) string {
	var b strings.Builder
	i := 0
	for i < len(s) {
		if idx, end, ok := markerAt(s, i); ok && idx < len(p.lit) {
			if p.lit[idx].expand {
				b.WriteString(`""`)
			} else {
				b.WriteString(`''`)
			}
			i = end
			continue
		}
		b.WriteByte(s[i])
		i++
	}
	return b.String()
}

// envChdir reports whether t is an option of env that changes the directory:
// -C, alone or after other short options (-iC) but not in the value of -u,
// -S or -a (-uLC_ALL), or --chdir and the abbreviations GNU env takes (--c).
func envChdir(t string) bool {
	if strings.HasPrefix(t, "--") {
		name, _, _ := strings.Cut(t[2:], "=")
		return name != "" && strings.HasPrefix("chdir", name)
	}
	if len(t) < 2 || t[0] != '-' {
		return false
	}
	for _, c := range t[1:] {
		switch c {
		case 'C':
			return true
		case 'u', 'S', 'a':
			return false
		}
	}
	return false
}

var (
	shellKeywords = map[string]bool{"if": true, "then": true, "elif": true, "else": true, "fi": true,
		"while": true, "until": true, "do": true, "done": true, "{": true, "}": true, "!": true}
	// quietCommands set no shell variable, whatever their arguments say.
	quietCommands = map[string]bool{"git": true, "gh": true, "echo": true, "printf": true,
		"cat": true, "grep": true, "jq": true, "true": true}
	// definesFunction matches `name()`, `name ()` and `function name`.
	definesFunction = regexp.MustCompile(`[A-Za-z0-9_.:-][[:space:]]*\([[:space:]]*\)|(^|[^A-Za-z0-9_])function[[:space:]]`)
	assignWord      = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?=`)
)

// envText is the command line s as setsGitEnv reads it, one command a line,
// with quotes and backslashes removed. When a command's command word (after
// its assignments) is one of quietCommands (printf without -v), its quoted
// arguments become a space unless they expand something ($), so a word in a
// commit message or a PR body is not taken for an assignment. Every other
// command, a wrapper such as env or nice among them, is read whole, and so
// is every command of a line that defines a function (which may take the
// name of a quiet command) or sources a file (which a quiet command may have
// written).
func (p *commandParser) envText(s string) string {
	segs := splitOn(s, listSep(true, "<>|&"))
	words := make([][]string, len(segs))
	names := make([]string, len(segs))
	at := make([]int, len(segs))
	quietLine := !definesFunction.MatchString(p.wordValue(s))
	for n, seg := range segs {
		words[n], at[n] = fields(seg), -1
		for i, t := range words[n] {
			v := strings.TrimLeft(p.wordValue(t), "({!")
			if v != "" && !shellKeywords[v] && !assignWord.MatchString(v) {
				at[n], names[n] = i, basename(v)
				break
			}
		}
		quietLine = quietLine && names[n] != "." && names[n] != "source"
	}
	var lines []string
	for n, toks := range words {
		quiet := quietLine && quietCommands[names[n]]
		var out []string
		for i, t := range toks {
			if names[n] == "printf" && i > at[n] && strings.HasPrefix(p.wordValue(t), "-v") {
				quiet = false
			}
			if quiet && i > at[n] {
				out = append(out, p.argText(t))
			} else {
				out = append(out, p.wordValue(t))
			}
		}
		lines = append(lines, strings.Join(out, " "))
	}
	return strings.Join(lines, "\n")
}

// argText is an argument word of one of quietCommands: its quoted strings
// become a space unless they expand something ($ or ` in double quotes), and
// its
// backslashes are removed.
func (p *commandParser) argText(w string) string {
	var b strings.Builder
	for i := 0; i < len(w); {
		if idx, end, ok := markerAt(w, i); ok && idx < len(p.lit) {
			c := p.lit[idx].content
			if p.lit[idx].expand && strings.ContainsAny(c, "$`") {
				b.WriteString(c)
			} else {
				b.WriteByte(' ')
			}
			i = end
			continue
		}
		b.WriteByte(w[i])
		i++
	}
	return strings.ReplaceAll(b.String(), "\\", "")
}

// wordValue is the value of a word as git reads it: its quotes and
// backslashes removed.
func (p *commandParser) wordValue(w string) string {
	return strings.ReplaceAll(p.literalText(w), "\\", "")
}

// gitElsewhereDir is the directory recorded for a git that the line points at
// another repository, work tree or push target.
const gitElsewhereDir = "?git"

// gitDir is the directory git runs in from at, given the words before it
// (before) and its options: moved by each -C. elsewhere is set when the line
// may point git at another repository, work tree or push target (--git-dir,
// --work-tree, --namespace, a config key that is not gitSafeKey, a value
// given to one of gitEnvNames on the line, env -C / --chdir).
func (p *commandParser) gitDir(at *string, before, opts string) (dir *string, elsewhere bool) {
	if p.gitElsewhere {
		return nil, true
	}
	env := false
	for _, w := range fields(before) {
		t := p.wordValue(w)
		env = env || basename(t) == "env"
		if env && envChdir(t) {
			return nil, true
		}
	}
	words := fields(opts)
	for n := 0; n < len(words); n++ {
		w := p.wordValue(words[n])
		next := ""
		if n+1 < len(words) {
			next = strings.ToLower(p.wordValue(words[n+1]))
		}
		switch {
		case strings.HasPrefix(w, "--git-dir"), strings.HasPrefix(w, "--work-tree"), strings.HasPrefix(w, "--namespace"),
			(w == "-c" || w == "--config-env") && !gitSafeKey(next),
			strings.HasPrefix(w, "--config-env=") && !gitSafeKey(w[len("--config-env="):]):
			return nil, true
		case w == "-C" && n+1 < len(words):
			at = p.enter(at, words[n+1])
		}
	}
	return at, false
}

// pushArgUnreadable: whitespace, a redirection, a ( ) or a {a,b} brace list.
func pushArgUnreadable(v string) bool {
	for i := 0; i < len(v); i++ {
		if isSpace(v[i]) || strings.IndexByte("<>()", v[i]) >= 0 {
			return true
		}
	}
	if open := strings.IndexByte(v, '{'); open >= 0 {
		comma := strings.IndexByte(v[open+1:], ',')
		if comma >= 0 && strings.IndexByte(v[open+1+comma+1:], '}') >= 0 {
			return true
		}
	}
	return false
}

func (p *commandParser) command(text string) {
	text = trimSpace(text)
	for stripped := true; stripped; {
		stripped = false
		for _, w := range leadWords {
			if strings.HasPrefix(text, w) && len(text) > len(w) && isSpace(text[len(w)]) {
				text = text[skipSpaces(text, len(w)):]
				stripped = true
				break
			}
		}
	}
	if strings.HasPrefix(text, "case") && len(text) > 4 && isSpace(text[4]) {
		p.opaque = true
	}
	toks := fields(text)
	if assigns, ok := assignments(toks); ok {
		for _, a := range assigns {
			eq := strings.IndexByte(a, '=')
			if a[:eq] == "GH_REPO" {
				p.ghMay = append(p.ghMay, p.known(a[eq+1:]))
			}
			if v, ok := p.value(a[eq+1:]); ok {
				p.vars[a[:eq]] = v
			} else {
				delete(p.vars, a[:eq])
			}
		}
		return
	}
	if len(toks) > 0 && toks[0] == "cd" && cdForm(toks) {
		if len(toks) == 1 {
			p.dir = p.home
		} else {
			p.dir = p.enter(p.dir, toks[len(toks)-1])
		}
		return
	}
	if len(toks) == 2 && toks[0] == "pushd" {
		p.dir = p.enter(p.dir, toks[1])
		return
	}
	if moves(text) {
		p.dir = nil
	}
	for _, name := range assignedNames(text) {
		delete(p.vars, name)
	}
	if name, ok := forVariable(text); ok {
		delete(p.vars, name)
	}
	if strings.HasPrefix(text, "read") && len(text) > 4 && isSpace(text[4]) {
		for _, w := range fields(text[4:]) {
			if allWord(w) {
				delete(p.vars, w)
			}
		}
	}
	p.emit(text, p.dir, false)
}

func allWord(s string) bool {
	if s == "" {
		return false
	}
	for i := 0; i < len(s); i++ {
		if !isWord(s[i]) {
			return false
		}
	}
	return true
}

// assignments returns the NAME=value words when toks is nothing else, after
// an optional export / declare / local / readonly / typeset and its flags.
func assignments(toks []string) ([]string, bool) {
	j := 0
	if len(toks) > 0 && declWords[toks[0]] {
		j = 1
		for j < len(toks) && len(toks[j]) > 1 && toks[j][0] == '-' && allWord(toks[j][1:]) {
			j++
		}
	}
	if j >= len(toks) {
		return nil, false
	}
	for _, t := range toks[j:] {
		eq := strings.IndexByte(t, '=')
		if eq < 1 || !allWord(t[:eq]) {
			return nil, false
		}
	}
	return toks[j:], true
}

// cdForm: `cd`, or `cd [-L|-P|--]... DIR`.
func cdForm(toks []string) bool {
	for _, t := range toks[1:max(1, len(toks)-1)] {
		if !cdFlags[t] {
			return false
		}
	}
	return true
}

func forVariable(text string) (string, bool) {
	if !strings.HasPrefix(text, "for") {
		return "", false
	}
	p := skipSpaces(text, 3)
	if p == 3 {
		return "", false
	}
	q := p
	for q < len(text) && isWord(text[q]) {
		q++
	}
	if q == p || q >= len(text) || !isSpace(text[q]) {
		return "", false
	}
	return text[p:q], true
}
