package outboundguard

import "strings"

// held keeps the quoted strings and heredoc bodies of a line set aside: whole
// is the text as written (quotes included), content what it stands for.
type held struct {
	whole, content []string
}

// holdLine sets heredoc bodies and quoted strings of cmd aside behind markers.
func holdLine(cmd string) (string, *held) {
	h := &held{}
	add := func(whole, content string) string {
		h.whole = append(h.whole, whole)
		h.content = append(h.content, content)
		return marker(len(h.whole) - 1)
	}
	s := heredocs(cmd, func(header, body, rest string) string { return header + add(body, body) + rest })
	s = quotes(s, func(kind quoteKind, whole, content string) string {
		switch kind {
		case escaped:
			return whole
		case comment:
			return ""
		}
		return add(whole, content)
	})
	return strings.ReplaceAll(s, "\\\n", " "), h
}

// put replaces markers with what they hold until none is left.
func (h *held) put(s string, asContent bool) string {
	for {
		var b strings.Builder
		changed := false
		i := 0
		for i < len(s) {
			if idx, end, ok := markerAt(s, i); ok && idx < len(h.whole) {
				if asContent {
					b.WriteString(h.content[idx])
				} else {
					b.WriteString(h.whole[idx])
				}
				i, changed = end, true
				continue
			}
			b.WriteByte(s[i])
			i++
		}
		if !changed {
			return s
		}
		s = b.String()
	}
}

type span struct{ start, end, wordStart int }

// findAll returns the non-overlapping matches of at, scanning left to right.
func findAll(s string, at func(s string, i int) (span, bool)) []span {
	var out []span
	for i := 0; i < len(s); {
		if m, ok := at(s, i); ok {
			out = append(out, m)
			i = m.end
			if m.end == m.start {
				i++
			}
			continue
		}
		i++
	}
	return out
}

func removeSpans(s string, spans []span) string {
	var b strings.Builder
	last := 0
	for _, m := range spans {
		b.WriteString(s[last:m.start])
		last = m.end
	}
	b.WriteString(s[last:])
	return b.String()
}

// wordAfter matches optional whitespace then a word at p.
func wordAfter(s string, p int) (int, int, bool) {
	q := skipSpaces(s, p)
	e := wordEnd(s, q)
	return q, e, e > q
}

// bodyFileAt: --body-file / --file (space or =) WORD, or -F[space]WORD, at the
// start of a word.
func bodyFileAt(s string, i int) (span, bool) {
	if prevIs(s, i, notSpace) {
		return span{}, false
	}
	for _, opt := range []string{"--body-file", "--file"} {
		if !strings.HasPrefix(s[i:], opt) {
			continue
		}
		p := i + len(opt)
		if p < len(s) && s[p] == '=' {
			p++
		} else if q := skipSpaces(s, p); q > p {
			p = q
		} else {
			continue
		}
		if e := wordEnd(s, p); e > p {
			return span{i, e, p}, true
		}
		return span{}, false
	}
	if strings.HasPrefix(s[i:], "-F") {
		if ws, e, ok := wordAfter(s, i+2); ok {
			return span{i, e, ws}, true
		}
	}
	return span{}, false
}

// stdinAt: < WORD that is not <<, <(, <& and not after < or the given digits.
func stdinAt(digits string) func(string, int) (span, bool) {
	return func(s string, i int) (span, bool) {
		if s[i] != '<' || prevIs(s, i, anyOf("<"+digits)) {
			return span{}, false
		}
		if i+1 < len(s) && strings.IndexByte("<(&", s[i+1]) >= 0 {
			return span{}, false
		}
		if ws, e, ok := wordAfter(s, i+1); ok {
			return span{i, e, ws}, true
		}
		return span{}, false
	}
}

// writeAt: > or >> or >| WORD, not after < and not >&, >>&, >( .
func writeAt(s string, i int) (span, bool) {
	if s[i] != '>' || prevIs(s, i, anyOf("<")) {
		return span{}, false
	}
	try := func(q int) (span, bool) {
		if q < len(s) && strings.IndexByte("&>(", s[q]) >= 0 {
			return span{}, false
		}
		if ws, e, ok := wordAfter(s, q); ok {
			return span{i, e, ws}, true
		}
		return span{}, false
	}
	if i+1 < len(s) && (s[i+1] == '>' || s[i+1] == '|') {
		if m, ok := try(i + 2); ok {
			return m, true
		}
	}
	return try(i + 1)
}

// redirectArgAt: [digit|&] < or > [>|&] WORD.
func redirectArgAt(s string, i int) (span, bool) {
	at := func(p int) (span, bool) {
		if p >= len(s) || (s[p] != '<' && s[p] != '>') {
			return span{}, false
		}
		if p+1 < len(s) && strings.IndexByte(">|&", s[p+1]) >= 0 {
			if ws, e, ok := wordAfter(s, p+2); ok {
				return span{i, e, ws}, true
			}
		}
		if ws, e, ok := wordAfter(s, p+1); ok {
			return span{i, e, ws}, true
		}
		return span{}, false
	}
	if isDigit(s[i]) || s[i] == '&' {
		if m, ok := at(i + 1); ok {
			return m, true
		}
	}
	return at(i)
}

// wordsAfter matches one or more (whitespace, word) pairs at p.
func wordsAfter(s string, p int) ([]string, int) {
	var words []string
	for {
		q := skipSpaces(s, p)
		if q == p {
			return words, p
		}
		e := wordEnd(s, q)
		if e == q {
			return words, p
		}
		words = append(words, s[q:e])
		p = e
	}
}

// commandWordAt finds name at i, not inside a longer path, followed by words.
func commandWordAt(s, name string, min int) ([]string, bool) {
	for i := 0; i < len(s); i++ {
		if !strings.HasPrefix(s[i:], name) || prevIs(s, i, pathChar) {
			continue
		}
		if words, _ := wordsAfter(s, i+len(name)); len(words) >= min {
			return words, true
		}
	}
	return nil, false
}

// outboundTextAt finds the first git commit or gh pr/issue text command.
func outboundTextAt(s string) (int, bool) {
	best := -1
	if start, _, _, ok := gitSub(s, "commit", 0); ok {
		best = start
	}
	if start, _, ok := findGh(s, 0, ghPRText); ok && (best < 0 || start < best) {
		best = start
	}
	return best, best >= 0
}

// outboundText describes what the outbound commands of cmd send, one line
// each: "\x03<file>" for every file a command on the line writes (>, >>, >|,
// n>, &>, tee, the last argument of cp / mv); then for each outbound command
// "\x02<file>" per body file its own --body-file / --file / -F arguments name
// (for `-`, its < redirect), and its text without those arguments, together
// with the pipeline stages that feed it.
func outboundText(cmd string) string {
	var written, out []string
	s, h := holdLine(cmd)
	segs := splitOn(s, listSep(false, "<>|"))
	for _, seg := range segs {
		for _, st := range splitOn(seg, pipeSep(true)) {
			for _, m := range findAll(st, writeAt) {
				written = append(written, h.put(st[m.wordStart:m.end], true))
			}
			if words, ok := commandWordAt(st, "tee", 1); ok {
				for _, w := range words {
					if !strings.HasPrefix(w, "-") {
						written = append(written, h.put(w, true))
					}
				}
			}
			args := removeSpans(st, findAll(st, redirectArgAt))
			if words, ok := cpOrMv(args); ok {
				written = append(written, h.put(words[len(words)-1], true))
			}
		}
	}
	for _, seg := range segs {
		stages := splitOn(seg, pipeSep(true))
		k, start := -1, 0
		for n, st := range stages {
			if at, ok := outboundTextAt(st); ok {
				k, start = n, at
				break
			}
		}
		if k < 0 {
			continue
		}
		own := stages[k][start:]
		stdin := false
		matches := findAll(own, bodyFileAt)
		for _, m := range matches {
			f := h.put(own[m.wordStart:m.end], true)
			if f == "-" || f == "/dev/stdin" {
				stdin = true
			} else {
				out = append(out, "\x02"+f)
			}
		}
		own = removeSpans(own, matches)
		if stdin {
			in := findAll(own, stdinAt("123456789"))
			for _, m := range in {
				out = append(out, "\x02"+h.put(own[m.wordStart:m.end], true))
			}
			own = removeSpans(own, in)
		}
		out = append(out, h.put(dropWrites(append(append([]string{}, stages[:k]...), own)), false))
	}
	var b strings.Builder
	for _, w := range written {
		b.WriteString("\x03" + w + "\n")
	}
	for _, l := range out {
		b.WriteString(l + "\n")
	}
	return b.String()
}

// dropWrites joins pipeline stages without their output redirections: where
// a command writes its output is not part of what it sends.
func dropWrites(stages []string) string {
	for i, st := range stages {
		stages[i] = removeSpans(st, findAll(st, writeAt))
	}
	return strings.Join(stages, " | ")
}

// cpOrMv returns the words after the first cp or mv that has two or more.
func cpOrMv(s string) ([]string, bool) {
	for i := 0; i+1 < len(s); i++ {
		if prevIs(s, i, pathChar) {
			continue
		}
		if strings.HasPrefix(s[i:], "cp") || strings.HasPrefix(s[i:], "mv") {
			if words, _ := wordsAfter(s, i+2); len(words) >= 2 {
				return words, true
			}
		}
	}
	return nil, false
}

// apiCall is one `gh api` on the line. For a call that writes, files are the
// files it sends and text its text (the stages piping into it and its own
// arguments) without the arguments that name those files.
type apiCall struct {
	writes bool
	files  []string
	text   string
}

// apiCalls lists every `gh api` on the line, in the order it appears.
func apiCalls(cmd string) []apiCall {
	var calls []apiCall
	s, h := holdLine(cmd)
	for _, seg := range splitOn(s, listSep(false, "<>|")) {
		stages := splitOn(seg, pipeSep(false))
		for k, st := range stages {
			for from := 0; ; {
				start, end, ok := findGh(st, from, ghAPI)
				if !ok {
					break
				}
				from = end
				calls = append(calls, apiCallAt(stages[:k], st[start:], h))
			}
		}
	}
	return calls
}

func apiCallAt(feed []string, gh string, h *held) apiCall {
	if !apiWrites1(gh, h) {
		return apiCall{}
	}
	c := apiCall{writes: true}
	stdin := false
	for _, m := range findAll(gh, optionAt([]string{"--input"}, true)) {
		f := h.put(gh[m.wordStart:m.end], true)
		if f == "-" {
			stdin = true
		} else {
			c.files = append(c.files, f)
		}
	}
	for _, m := range findAll(gh, optionAt([]string{"--field", "-F"}, false)) {
		v := h.put(gh[m.wordStart:m.end], true)
		if f, ok := fieldFile(v); ok {
			if f == "-" {
				stdin = true
			} else {
				c.files = append(c.files, f)
			}
		}
	}
	if stdin {
		in := findAll(gh, stdinAt("0123456789"))
		for _, m := range in {
			c.files = append(c.files, h.put(gh[m.wordStart:m.end], true))
		}
		gh = removeSpans(gh, in)
	}
	gh = removeSpans(gh, findAll(gh, optionAt([]string{"--input"}, true)))
	var sent []span
	for _, m := range findAll(gh, optionAt([]string{"--field", "-F"}, false)) {
		v := h.put(gh[m.wordStart:m.end], true)
		if eq := strings.IndexByte(v, '='); eq >= 0 && eq+1 < len(v) && v[eq+1] == '@' {
			sent = append(sent, m)
		}
	}
	gh = removeSpans(gh, sent)
	c.text = h.put(dropWrites(append(append([]string{}, feed...), gh)), false)
	return c
}

// apiWrites1: a --method / -X other than GET or HEAD, or, without one, any
// --input / --field / --raw-field / -f / -F.
func apiWrites1(gh string, h *held) bool {
	if m := findAll(gh, optionAt([]string{"--method", "-X"}, false)); len(m) > 0 {
		v := strings.TrimSuffix(h.put(gh[m[0].wordStart:m[0].end], true), "\n")
		return !strings.EqualFold(v, "GET") && !strings.EqualFold(v, "HEAD")
	}
	for i := 0; i < len(gh); i++ {
		if prevIs(gh, i, notSpace) {
			continue
		}
		for _, o := range []string{"--input", "--field", "--raw-field", "-f", "-F"} {
			if strings.HasPrefix(gh[i:], o) {
				return true
			}
		}
	}
	return false
}

// optionAt matches an option at the start of a word followed by its value:
// with sepRequired, after whitespace or =; otherwise also directly.
func optionAt(names []string, sepRequired bool) func(string, int) (span, bool) {
	return func(s string, i int) (span, bool) {
		if prevIs(s, i, notSpace) {
			return span{}, false
		}
		for _, name := range names {
			if !strings.HasPrefix(s[i:], name) {
				continue
			}
			p := i + len(name)
			if q := skipSpaces(s, p); q > p {
				if e := wordEnd(s, q); e > q {
					return span{i, e, q}, true
				}
			}
			if p < len(s) && s[p] == '=' {
				if e := wordEnd(s, p+1); e > p+1 {
					return span{i, e, p + 1}, true
				}
			}
			if !sepRequired {
				if e := wordEnd(s, p); e > p {
					return span{i, e, p}, true
				}
			}
			return span{}, false
		}
		return span{}, false
	}
}

// fieldFile returns FILE for a field value key=@FILE.
func fieldFile(v string) (string, bool) {
	eq := strings.IndexByte(v, '=')
	if eq < 0 || eq+2 >= len(v) || v[eq+1] != '@' {
		return "", false
	}
	return v[eq+2:], true
}
