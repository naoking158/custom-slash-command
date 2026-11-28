package outboundguard

import "strings"

// held keeps the quoted strings and heredoc bodies of a line set aside: whole
// is the text as written (quotes included), content what it stands for, and
// expands whether the shell runs the substitutions in it.
type held struct {
	whole, content []string
	expands        []bool
}

// holdLine sets heredoc bodies and quoted strings of cmd aside behind markers.
func holdLine(cmd string) (string, *held) {
	h := &held{}
	add := func(whole, content string, expands bool) string {
		h.whole = append(h.whole, whole)
		h.content = append(h.content, content)
		h.expands = append(h.expands, expands)
		return marker(len(h.whole) - 1)
	}
	s := heredocs(cmd, func(header, body, rest string) string {
		return header + add(body, body, !strings.ContainsAny(header, `"'`)) + rest
	})
	s = quotes(s, func(kind quoteKind, whole, content string) string {
		switch kind {
		case escaped:
			return whole
		case comment:
			return ""
		}
		return add(whole, content, kind == doubleQuoted)
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

// takeReads removes from s each command substitution that only reads files
// ($(cat f...), $(<f), `cat f`), where the shell expands it, and returns s
// without them and the files they read: "" for one the line does not show.
func (h *held) takeReads(s string) (string, []string) {
	var files []string
	var b strings.Builder
	for i := 0; i < len(s); {
		if idx, end, ok := markerAt(s, i); ok {
			if idx < len(h.expands) && h.expands[idx] {
				c, fs := h.takeReads(h.content[idx])
				if c != h.content[idx] {
					if h.whole[idx] != h.content[idx] {
						h.whole[idx] = h.whole[idx][:1] + c + h.whole[idx][len(h.whole[idx])-1:]
					} else {
						h.whole[idx] = c
					}
					h.content[idx] = c
				}
				files = append(files, fs...)
			}
			b.WriteString(s[i:end])
			i = end
			continue
		}
		body, next := "", -1
		escaped := i > 0 && s[i-1] == '\\'
		switch {
		case escaped:
		case strings.HasPrefix(s[i:], "$(") && !strings.HasPrefix(s[i:], "$(("):
			if k := strings.IndexByte(s[i:], ')'); k >= 0 {
				body, next = s[i+2:i+k], i+k+1
			}
		case s[i] == '`':
			if k := strings.IndexByte(s[i+1:], '`'); k >= 0 {
				body, next = s[i+1:i+1+k], i+k+2
			}
		}
		if next >= 0 {
			if fs, whole := h.reads(body); fs != nil {
				files = append(files, fs...)
				if whole {
					i = next
					continue
				}
			}
		} else if !escaped && (strings.HasPrefix(s[i:], "$(cat") || strings.HasPrefix(s[i:], "$(<") || strings.HasPrefix(s[i:], "`cat")) {
			files = append(files, "")
		}
		b.WriteByte(s[i])
		i++
	}
	return b.String(), files
}

// reads returns the files a substitution body reads with cat or <, and
// whether reading them is all it does; nil when it is not such a reader.
func (h *held) reads(body string) ([]string, bool) {
	body = trimSpace(body)
	if strings.HasPrefix(body, "<") && !strings.HasPrefix(body, "<<") {
		w := trimSpace(body[1:])
		if w == "" || strings.ContainsAny(w, " \t\n;&|()<>") {
			return []string{""}, false
		}
		return []string{h.word(w)}, true
	}
	toks := fields(body)
	if len(toks) == 0 || toks[0] != "cat" {
		return nil, false
	}
	files := []string{}
	for _, t := range toks[1:] {
		if strings.ContainsAny(t[:1], ";&|<>") {
			return files, false
		}
		if t != "-" && !strings.HasPrefix(t, "-") {
			files = append(files, h.word(t))
		}
	}
	return files, true
}

// word is the value of a word that names a file: "" when it holds a variable
// or a substitution the line does not show.
func (h *held) word(w string) string { return fileValue(h.put(w, true)) }

// fileValue is the file a word's value names: "" when it holds a variable or
// a substitution the line does not show.
func fileValue(v string) string {
	if len(v) >= 2 && (v[0] == '\'' || v[0] == '"') && v[len(v)-1] == v[0] {
		v = v[1 : len(v)-1]
	}
	if strings.ContainsAny(v, "$`") {
		return ""
	}
	return v
}

// takeFed removes from a stage that pipes into an outbound command the files
// it reads (the arguments of cat, a < redirect) and returns them.
func (h *held) takeFed(st string) (string, []string) {
	var files []string
	in := findAll(st, stdinAt("123456789"))
	for _, m := range in {
		files = append(files, h.word(st[m.wordStart:m.end]))
	}
	st = removeSpans(st, in)
	p := skipSpaces(st, 0)
	if !strings.HasPrefix(st[p:], "cat") || (p+3 < len(st) && !isSpace(st[p+3])) {
		return st, files
	}
	var args []span
	for q := p + 3; ; {
		ws, e, ok := wordAfter(st, q)
		if !ok {
			break
		}
		w := st[ws:e]
		if !strings.HasPrefix(w, "-") && !strings.ContainsAny(w[:1], "<>&|;") && !strings.Contains(w, ">") {
			files = append(files, h.word(w))
			args = append(args, span{ws, e, ws})
		}
		q = e
	}
	return removeSpans(st, args), files
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

// outboundTextAt finds the first git commit or gh pr/issue text command: where
// it starts, where its arguments start and how it reads its options.
func outboundTextAt(s string) (start, args int, g grammar, ok bool) {
	start = -1
	if at, _, end, found := gitSub(s, "commit", 0); found {
		start, args, g = at, end, gitCommitGrammar
	}
	if at, end, found := findGh(s, 0, ghPRText); found && (start < 0 || at < start) {
		start, args = at, end
		g, _ = ghGrammarOf(s[at:end])
	}
	return start, args, g, start >= 0
}

// outboundText describes what the outbound commands of cmd send, one line
// each: "\x03<file>" for every file a command on the line writes (>, >>, >|,
// n>, &>, tee, the last argument of cp / mv); then for each outbound command
// "\x02<file>" per body file its own -F / --file / --body-file options name,
// read as the command reads them (for `-`, its < redirect), the value of each
// option written in the same word as its letter (-mTEXT), and its text
// without the body file options, together with the pipeline stages that feed
// it.
func outboundText(cmd string) string {
	var out []string
	s, h := holdLine(cmd)
	segs := splitOn(s, listSep(false, "<>|"))
	written := writtenFiles(segs, h)
	for _, seg := range segs {
		stages := splitOn(seg, pipeSep(true))
		k, start, args := -1, 0, 0
		var g grammar
		for n, st := range stages {
			if at, a, gr, ok := outboundTextAt(st); ok {
				k, start, args, g = n, at, a, gr
				break
			}
		}
		if k < 0 {
			continue
		}
		own := stages[k][start:]
		stdin := false
		words := lineWords(own, args-start, h)
		var files []span
		for _, o := range g.options(words) {
			if o.attached {
				out = append(out, o.value)
			}
			if !o.hasValue || !o.is("F", "file", "body-file") {
				continue
			}
			files = append(files, span{words[o.first].start, words[o.last].end, 0})
			if f := fileValue(o.value); f == "-" || f == "/dev/stdin" {
				stdin = true
			} else {
				out = append(out, "\x02"+f)
			}
		}
		own = removeSpans(own, files)
		if stdin {
			for _, f := range stdinFiles(stages[k][:start], h) {
				out = append(out, "\x02"+f)
			}
			in := findAll(own, stdinAt("123456789"))
			for _, m := range in {
				out = append(out, "\x02"+h.put(own[m.wordStart:m.end], true))
			}
			own = removeSpans(own, in)
		}
		sent, read := h.takeSent(stages[:k], own)
		for _, f := range read {
			out = append(out, "\x02"+f)
		}
		out = append(out, h.put(dropWrites(sent), false))
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

// stdinFiles returns the files of the < redirects in the words before a
// command: `< f cmd` feeds f to it just as `cmd < f` does.
func stdinFiles(before string, h *held) []string {
	var files []string
	for _, m := range findAll(before, stdinAt("0123456789")) {
		files = append(files, h.put(before[m.wordStart:m.end], true))
	}
	return files
}

// writtenFiles lists the files the commands of segs write: >, >>, >|, n>, &>,
// tee, the last argument of cp / mv.
func writtenFiles(segs []string, h *held) []string {
	var written []string
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
	return written
}

// takeSent returns the stages that feed an outbound command, then its own
// text, with the file reads of takeFed and takeReads taken out, and the files
// those reads name.
func (h *held) takeSent(feed []string, own string) ([]string, []string) {
	var files []string
	sent := append([]string{}, feed...)
	sent = append(sent, own)
	for i := range sent {
		sent[i] = removeSpans(sent[i], gitOptionSpans(sent[i]))
		var fs []string
		if i < len(feed) {
			sent[i], fs = h.takeFed(sent[i])
			files = append(files, fs...)
		}
		sent[i], fs = h.takeReads(sent[i])
		files = append(files, fs...)
	}
	return sent, files
}

// gitOptionSpans returns the -C <dir> and -c <name=value> options each git
// in s is given before its subcommand: they say where and how git runs, not
// what it sends.
func gitOptionSpans(s string) []span {
	var out []span
	for i := 0; ; i++ {
		k := strings.Index(s[i:], "git")
		if k < 0 {
			return out
		}
		i += k
		if prevIs(s, i, wordOrDash) {
			continue
		}
		p := i + 3
		for {
			q := skipSpaces(s, p)
			if q == p || q+1 >= len(s) || s[q] != '-' || (s[q+1] != 'C' && s[q+1] != 'c') {
				break
			}
			ws, e, ok := wordAfter(s, q+2)
			if !ok || ws == q+2 {
				break
			}
			out = append(out, span{q, e, ws})
			p = e
		}
	}
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

// apiCalls lists every `gh api` on the line, in the order it appears, and the
// files the line writes.
func apiCalls(cmd string) ([]apiCall, []string) {
	var calls []apiCall
	s, h := holdLine(cmd)
	segs := splitOn(s, listSep(false, "<>|"))
	for _, seg := range segs {
		stages := splitOn(seg, pipeSep(false))
		for k, st := range stages {
			for from := 0; ; {
				start, end, ok := findGh(st, from, ghAPI)
				if !ok {
					break
				}
				from = end
				calls = append(calls, apiCallAt(stages[:k], st[:start], st[start:], h))
			}
		}
	}
	return calls, writtenFiles(segs, h)
}

func apiCallAt(feed []string, before, gh string, h *held) apiCall {
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
		c.files = append(c.files, stdinFiles(before, h)...)
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
	stages, read := h.takeSent(feed, gh)
	c.files = append(c.files, read...)
	c.text = h.put(dropWrites(stages), false)
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
