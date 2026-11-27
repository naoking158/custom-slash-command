package outboundguard

import (
	"strconv"
	"strings"
)

// The scanners below read a Bash command line the way the guard needs: they
// set heredoc bodies and quoted strings aside behind markers (NUL, index,
// NUL), then split what is left into commands. They decide what is a command
// and what is text, so a change here changes what the guard lets through.

func isSpace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v'
}

func isWord(c byte) bool {
	return c == '_' || ('0' <= c && c <= '9') || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')
}

func isDigit(c byte) bool { return '0' <= c && c <= '9' }

// fields splits s on runs of ASCII whitespace.
func fields(s string) []string {
	var out []string
	i := 0
	for i < len(s) {
		for i < len(s) && isSpace(s[i]) {
			i++
		}
		j := i
		for j < len(s) && !isSpace(s[j]) {
			j++
		}
		if j > i {
			out = append(out, s[i:j])
		}
		i = j
	}
	return out
}

func trimSpace(s string) string {
	i, j := 0, len(s)
	for i < j && isSpace(s[i]) {
		i++
	}
	for j > i && isSpace(s[j-1]) {
		j--
	}
	return s[i:j]
}

func skipSpaces(s string, p int) int {
	for p < len(s) && isSpace(s[p]) {
		p++
	}
	return p
}

// prevIs reports whether the byte before position i is in set; false at 0.
func prevIs(s string, i int, set func(byte) bool) bool {
	return i > 0 && set(s[i-1])
}

func wordOrDash(c byte) bool { return isWord(c) || c == '-' }
func pathChar(c byte) bool   { return isWord(c) || c == '.' || c == '/' || c == '-' }
func notSpace(c byte) bool   { return !isSpace(c) }
func anyOf(set string) func(byte) bool {
	return func(c byte) bool { return strings.IndexByte(set, c) >= 0 }
}

func marker(i int) string { return "\x00" + strconv.Itoa(i) + "\x00" }

// markerAt returns the index and end of a marker starting at p.
func markerAt(s string, p int) (idx, end int, ok bool) {
	if p >= len(s) || s[p] != 0 {
		return 0, 0, false
	}
	q := p + 1
	for q < len(s) && isDigit(s[q]) {
		q++
	}
	if q == p+1 || q >= len(s) || s[q] != 0 {
		return 0, 0, false
	}
	n, err := strconv.Atoi(s[p+1 : q])
	if err != nil {
		return 0, 0, false
	}
	return n, q + 1, true
}

// wordEnd matches one word (markers and non-space, non-NUL bytes) at p and
// returns its end, or p when there is none.
func wordEnd(s string, p int) int {
	q := p
	for q < len(s) {
		if _, end, ok := markerAt(s, q); ok {
			q = end
			continue
		}
		if s[q] == 0 || isSpace(s[q]) {
			break
		}
		q++
	}
	return q
}

// heredocs finds each `<<[-] [quote]WORD[quote] rest-of-line \n body \n WORD`
// and replaces it with repl(header, body, rest). An unquoted WORD whose own
// terminator is missing is retried shorter, so `<<EOFX` can end at `EOF`.
func heredocs(s string, repl func(header, body, rest string) string) string {
	var b strings.Builder
	last, i := 0, 0
	for i+1 < len(s) {
		if s[i] == '<' && s[i+1] == '<' {
			if end, out, ok := heredocAt(s, i, repl); ok {
				b.WriteString(s[last:i])
				b.WriteString(out)
				last, i = end, end
				continue
			}
		}
		i++
	}
	b.WriteString(s[last:])
	return b.String()
}

func heredocAt(s string, i int, repl func(header, body, rest string) string) (int, string, bool) {
	p := i + 2
	if p < len(s) && s[p] == '-' {
		p++
	}
	p = skipSpaces(s, p)
	var quote byte
	if p < len(s) && (s[p] == '"' || s[p] == '\'') {
		quote = s[p]
		p++
	}
	ws := p
	for p < len(s) && isWord(s[p]) {
		p++
	}
	for we := p; we > ws; we-- {
		after := we
		if quote != 0 {
			if after >= len(s) || s[after] != quote {
				continue
			}
			after++
		}
		nl := strings.IndexByte(s[after:], '\n')
		if nl < 0 {
			return 0, "", false
		}
		restEnd := after + nl
		bodyStart := restEnd + 1
		word := s[ws:we]
		for k := bodyStart; k < len(s); k++ {
			if s[k] != '\n' {
				continue
			}
			t := k + 1
			for t < len(s) && (s[t] == ' ' || s[t] == '\t') {
				t++
			}
			if !strings.HasPrefix(s[t:], word) {
				continue
			}
			u := t + len(word)
			for u < len(s) && (s[u] == ' ' || s[u] == '\t') {
				u++
			}
			if u == len(s) || s[u] == '\n' {
				return u, repl(s[i:after], s[bodyStart:k], s[after:restEnd]), true
			}
		}
	}
	return 0, "", false
}

type quoteKind int

const (
	escaped quoteKind = iota
	dollarQuoted
	doubleQuoted
	singleQuoted
	comment
)

// quotes walks s and replaces each backslash escape, $'..', "..", '..' and
// comment with repl(kind, whole match, content).
func quotes(s string, repl func(kind quoteKind, whole, content string) string) string {
	var b strings.Builder
	i := 0
	for i < len(s) {
		c := s[i]
		switch {
		case c == '\\' && i+1 < len(s):
			b.WriteString(repl(escaped, s[i:i+2], ""))
			i += 2
			continue
		case c == '$' && i+1 < len(s) && s[i+1] == '\'':
			if end, ok := closeEscaped(s, i+2, '\''); ok {
				b.WriteString(repl(dollarQuoted, s[i:end+1], s[i+2:end]))
				i = end + 1
				continue
			}
		case c == '"':
			if end, ok := closeEscaped(s, i+1, '"'); ok {
				b.WriteString(repl(doubleQuoted, s[i:end+1], s[i+1:end]))
				i = end + 1
				continue
			}
		case c == '\'':
			if end := strings.IndexByte(s[i+1:], '\''); end >= 0 {
				end += i + 1
				b.WriteString(repl(singleQuoted, s[i:end+1], s[i+1:end]))
				i = end + 1
				continue
			}
		case c == '#' && (i == 0 || isSpace(s[i-1]) || strings.IndexByte(";&|()", s[i-1]) >= 0):
			end := strings.IndexByte(s[i:], '\n')
			if end < 0 {
				end = len(s) - i
			}
			b.WriteString(repl(comment, s[i:i+end], ""))
			i += end
			continue
		}
		b.WriteByte(c)
		i++
	}
	return b.String()
}

// closeEscaped finds the closing q from p, skipping backslash escapes.
func closeEscaped(s string, p int, q byte) (int, bool) {
	for p < len(s) {
		switch s[p] {
		case '\\':
			if p+1 >= len(s) {
				return 0, false
			}
			p += 2
		case q:
			return p, true
		default:
			p++
		}
	}
	return 0, false
}

// splitOn splits s at the separators sep reports (its length at i, 0 for
// none) and drops trailing empty fields, as Perl's split does.
func splitOn(s string, sep func(s string, i int) int) []string {
	var out []string
	start, i := 0, 0
	for i < len(s) {
		if n := sep(s, i); n > 0 {
			out = append(out, s[start:i])
			i += n
			start = i
			continue
		}
		i++
	}
	out = append(out, s[start:])
	for len(out) > 0 && out[len(out)-1] == "" {
		out = out[:len(out)-1]
	}
	return out
}

// listSep: && || ; newline, and a lone & that is not part of a redirection.
// pipes also splits at | (not after >) and |&; ampBefore is the set of bytes
// that keep a following & from being a separator.
func listSep(pipes bool, ampBefore string) func(string, int) int {
	return func(s string, i int) int {
		c := s[i]
		next := byte(0)
		if i+1 < len(s) {
			next = s[i+1]
		}
		switch {
		case c == '&' && next == '&', c == '|' && next == '|':
			return 2
		case c == ';', c == '\n':
			return 1
		case pipes && c == '|' && !prevIs(s, i, anyOf(">")):
			if next == '&' {
				return 2
			}
			return 1
		case c == '&' && !prevIs(s, i, anyOf(ampBefore)) && next != '>' && next != '&':
			return 1
		}
		return 0
	}
}

// pipeSep splits a pipeline at | and |&; afterGt keeps `>|` whole.
func pipeSep(afterGt bool) func(string, int) int {
	return func(s string, i int) int {
		if s[i] != '|' || (afterGt && prevIs(s, i, anyOf(">"))) {
			return 0
		}
		if i+1 < len(s) && s[i+1] == '&' {
			return 2
		}
		return 1
	}
}

// gitSub matches `git (-C|-c X)* SUB` with git not inside a longer word and
// SUB not followed by a word byte or -. It returns where git starts, the
// option text between them and where SUB ends.
func gitSub(s, sub string, from int) (start int, opts string, end int, ok bool) {
	for i := from; ; i++ {
		k := strings.Index(s[i:], "git")
		if k < 0 {
			return 0, "", 0, false
		}
		i += k
		if prevIs(s, i, wordOrDash) {
			continue
		}
		ends := []int{i + 3}
		p := i + 3
		for {
			q := skipSpaces(s, p)
			if q == p || q+1 >= len(s) || s[q] != '-' || (s[q+1] != 'C' && s[q+1] != 'c') {
				break
			}
			r := skipSpaces(s, q+2)
			if r == q+2 {
				break
			}
			t := r
			for t < len(s) && !isSpace(s[t]) {
				t++
			}
			if t == r {
				break
			}
			p = t
			ends = append(ends, p)
		}
		for n := len(ends) - 1; n >= 0; n-- {
			q := skipSpaces(s, ends[n])
			if q == ends[n] || !strings.HasPrefix(s[q:], sub) {
				continue
			}
			e := q + len(sub)
			if e < len(s) && wordOrDash(s[e]) {
				continue
			}
			return i, s[i+3 : ends[n]], e, true
		}
	}
}

// ghCommand matches `gh <first> <one of second>` (second empty: first alone)
// with gh not inside a longer word and the last word not followed by a word
// byte or -. It returns the start and end of the match.
func ghWords(s string, i int, alts [][2][]string) (int, bool) {
	if prevIs(s, i, wordOrDash) || !strings.HasPrefix(s[i:], "gh") {
		return 0, false
	}
	p := skipSpaces(s, i+2)
	if p == i+2 {
		return 0, false
	}
	for _, alt := range alts {
		for _, first := range alt[0] {
			if !strings.HasPrefix(s[p:], first) {
				continue
			}
			q := p + len(first)
			if len(alt[1]) == 0 {
				if q >= len(s) || !wordOrDash(s[q]) {
					return q, true
				}
				continue
			}
			r := skipSpaces(s, q)
			if r == q {
				continue
			}
			for _, second := range alt[1] {
				if !strings.HasPrefix(s[r:], second) {
					continue
				}
				e := r + len(second)
				if e >= len(s) || !wordOrDash(s[e]) {
					return e, true
				}
			}
		}
	}
	return 0, false
}

// findGh returns the first match of ghWords at or after from.
func findGh(s string, from int, alts [][2][]string) (start, end int, ok bool) {
	for i := from; i+1 < len(s); i++ {
		if s[i] == 'g' && s[i+1] == 'h' {
			if e, ok := ghWords(s, i, alts); ok {
				return i, e, true
			}
		}
	}
	return 0, 0, false
}

var (
	ghPRSend   = [][2][]string{{{"pr"}, {"create", "new", "merge", "ready"}}, {{"api"}, nil}}
	ghPRText   = [][2][]string{{{"pr", "issue"}, {"create", "new", "comment", "edit", "review"}}}
	ghAPI      = [][2][]string{{{"api"}, nil}}
	moveWords  = []string{"cd", "pushd", "popd"}
	declWords  = map[string]bool{"export": true, "declare": true, "local": true, "readonly": true, "typeset": true}
	leadWords  = []string{"if", "then", "elif", "else", "while", "until", "do", "time", "!", "{", "builtin", "command"}
	cdFlags    = map[string]bool{"-L": true, "-P": true, "--": true}
	notTarget  = " \t\n\r\f\v()<>&|;"
	redirectOp = []string{">>", ">|", ">&", ">", "<<<", "<<-", "<<", "<&", "<>", "<"}
)

// flattenParens replaces innermost (...) groups with a space until none is left.
func flattenParens(s string) string {
	for {
		start := -1
		found := false
		for i := 0; i < len(s); i++ {
			if s[i] == '(' {
				start = i
			} else if s[i] == ')' && start >= 0 {
				s = s[:start] + " " + s[i+1:]
				found = true
				break
			}
		}
		if !found {
			return s
		}
	}
}

// moves reports whether s runs cd, pushd or popd outside a (...) group.
func moves(s string) bool {
	flat := flattenParens(s)
	for i := 0; i < len(flat); i++ {
		if prevIs(flat, i, pathChar) {
			continue
		}
		for _, w := range moveWords {
			if strings.HasPrefix(flat[i:], w) {
				e := i + len(w)
				if e >= len(flat) || !pathChar(flat[e]) {
					return true
				}
			}
		}
	}
	return false
}

// assignedNames returns NAME for each NAME= at the start or after whitespace.
func assignedNames(s string) []string {
	var out []string
	for i := 0; i < len(s); i++ {
		if i > 0 && !isSpace(s[i-1]) {
			continue
		}
		j := i
		for j < len(s) && isWord(s[j]) {
			j++
		}
		if j > i && j < len(s) && s[j] == '=' {
			out = append(out, s[i:j])
			i = j
		}
	}
	return out
}

// stripRedirections drops each redirection and its target from a segment.
func stripRedirections(s string) string {
	var b strings.Builder
	i := 0
	for i < len(s) {
		if end, ok := redirectionAt(s, i); ok {
			i = end
			continue
		}
		b.WriteByte(s[i])
		i++
	}
	return b.String()
}

func redirectionAt(s string, i int) (int, bool) {
	target := func(p int) (int, bool) {
		p = skipSpaces(s, p)
		q := p
		for q < len(s) && strings.IndexByte(notTarget, s[q]) < 0 {
			q++
		}
		return q, q > p
	}
	ops := func(p int) (int, bool) {
		for _, op := range redirectOp {
			if strings.HasPrefix(s[p:], op) {
				if end, ok := target(p + len(op)); ok {
					return end, true
				}
			}
		}
		return 0, false
	}
	if isDigit(s[i]) && !prevIs(s, i, notSpace) {
		d := i
		for d < len(s) && isDigit(s[d]) {
			d++
		}
		if end, ok := ops(d); ok {
			return end, true
		}
	}
	if end, ok := ops(i); ok {
		return end, true
	}
	for _, op := range []string{"&>>", "&>"} {
		if strings.HasPrefix(s[i:], op) {
			if end, ok := target(i + len(op)); ok {
				return end, true
			}
		}
	}
	return 0, false
}
