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
//	text: Rest is "git" or "gh", for a command that carries a message.
//
// Dir is "?" when the line does not show it and "?case" when a case statement
// precedes the command. For pr, Repos are the repositories gh is told to use
// instead of Dir's (-R or --repo with its value as the next word, GH_REPO
// assigned just before gh) and Also the ones it may act on besides (an
// attached -R<repo>, a pull request URL, a repos/OWNER/NAME path, any other
// GH_REPO assignment); "" stands for one the line does not show.
type command struct {
	Kind, Dir, Rest string
	Repos, Also     []string
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
	lit    []literal
	vars   map[string]string
	dir    *string
	saved  []scope
	opaque bool
	home   *string
	out    []command
	ghMay  []string
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
	if _, opts, end, ok := gitSub(text, "push", 0); ok {
		in := at
		if c, found := optionC(opts); found {
			in = p.enter(at, c)
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
		p.out = append(p.out, command{"push", orUnknown(in, unknown), strings.Join(args, " "), nil, nil})
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
		repos, also := p.namedRepos(gh)
		repos = append(p.prefixGhRepo(text[:start]), repos...)
		also = append(append([]string{}, p.ghMay...), also...)
		gh = p.emptyQuotes(gh)
		if cut && !closedParen {
			gh += " ?"
		}
		gh = strings.Join(splitKeepEmpty(gh), " ")
		gh = strings.TrimSuffix(gh, " ")
		p.out = append(p.out, command{"pr", orUnknown(at, unknown), gh, repos, also})
	}
	if _, opts, _, ok := gitSub(text, "commit", 0); ok {
		in := at
		if c, found := optionC(opts); found {
			in = p.enter(at, c)
		}
		p.out = append(p.out, command{"text", orUnknown(in, unknown), "git", nil, nil})
	} else if _, _, ok := findGh(text, 0, ghPRText); ok {
		p.out = append(p.out, command{"text", orUnknown(at, unknown), "gh", nil, nil})
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
// next word) and, from any word, the ones it may act on: an attached
// -R<repo>, which may be another option's value, pull request URLs and
// repos/OWNER/NAME paths. {owner}/{repo} is the directory's own repository and
// is not listed.
func (p *commandParser) namedRepos(gh string) (repos, also []string) {
	toks := fields(gh)
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

// optionC returns the value of the first -C in git's options.
func optionC(opts string) (string, bool) {
	for i := 0; i+2 < len(opts); i++ {
		if isSpace(opts[i]) && opts[i+1] == '-' && opts[i+2] == 'C' {
			p := skipSpaces(opts, i+3)
			if p == i+3 {
				continue
			}
			q := p
			for q < len(opts) && !isSpace(opts[q]) {
				q++
			}
			if q > p {
				return opts[p:q], true
			}
		}
	}
	return "", false
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
