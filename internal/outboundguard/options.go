package outboundguard

import "strings"

// grammar is how a command reads its options, as git's parse-options or gh's
// pflag does: a short letter that takes a value takes the rest of its word, or
// the next word when nothing is left; the other letters of a word are flags
// of their own.
type grammar struct {
	value    string   // short letters that take a value
	attached string   // short letters whose value can only be the rest of the word
	long     []string // long options that take a value (--name=v or --name v)
	prefixes bool     // a unique prefix of a long option names it (git)
	shortEq  bool     // -x=v gives v, and a flag letter accepts =v too (pflag)
}

var (
	gitCommitGrammar = grammar{value: "FmcCtU", attached: "Su", prefixes: true,
		long: []string{"file", "message", "reedit-message", "reuse-message", "template", "fixup", "squash",
			"author", "date", "cleanup", "trailer", "pathspec-from-file", "unified"}}
	gitPushGrammar = grammar{value: "o", prefixes: true,
		long: []string{"push-option", "repo", "receive-pack", "exec"}}
	ghAPIGrammar = grammar{value: "FfHXpqt", shortEq: true,
		long: []string{"field", "raw-field", "header", "method", "preview", "jq", "template", "input", "hostname", "cache"}}
	ghGrammars = map[string]grammar{
		"pr create":     {value: "aBbFHlmprTtR", shortEq: true, long: ghLong("assignee", "attach", "base", "body", "body-file", "head", "label", "milestone", "project", "recover", "reviewer", "template", "title")},
		"pr comment":    {value: "bFR", shortEq: true, long: ghLong("attach", "body", "body-file")},
		"pr edit":       {value: "BbFmtR", shortEq: true, long: ghLong("add-assignee", "add-label", "add-project", "add-reviewer", "attach", "base", "body", "body-file", "milestone", "remove-assignee", "remove-label", "remove-project", "remove-reviewer", "title")},
		"pr review":     {value: "bFR", shortEq: true, long: ghLong("body", "body-file")},
		"pr merge":      {value: "AbFtR", shortEq: true, long: ghLong("author-email", "body", "body-file", "match-head-commit", "subject")},
		"pr ready":      {value: "R", shortEq: true, long: ghLong()},
		"issue create":  {value: "abFlmpTtR", shortEq: true, long: ghLong("assignee", "attach", "blocked-by", "blocking", "body", "body-file", "label", "milestone", "parent", "project", "recover", "template", "title", "type")},
		"issue comment": {value: "bFR", shortEq: true, long: ghLong("attach", "body", "body-file")},
		"issue edit":    {value: "bFmtR", shortEq: true, long: ghLong("add-assignee", "add-blocked-by", "add-blocking", "add-label", "add-project", "add-sub-issue", "attach", "body", "body-file", "milestone", "parent", "remove-assignee", "remove-blocked-by", "remove-blocking", "remove-label", "remove-project", "remove-sub-issue", "title", "type")},
	}
)

func ghLong(names ...string) []string { return append(names, "repo") }

// ghGrammarOf returns the grammar of the gh command that s starts with
// (`gh pr new` reads as `gh pr create`, `gh issue new` as `gh issue create`).
func ghGrammarOf(s string) (grammar, bool) {
	f := fields(s)
	if len(f) < 3 || f[0] != "gh" {
		return grammar{}, false
	}
	sub := f[2]
	if sub == "new" {
		sub = "create"
	}
	g, ok := ghGrammars[f[1]+" "+sub]
	return g, ok
}

// word is one word of a command line: its value and where it is written.
type word struct {
	text       string
	start, end int
}

// option is one option given on a command line. name is the short letter or
// the long name (resolved when the grammar takes prefixes); value is set when
// hasValue. first and last are the indexes of the words it spans, and
// attached is set when its value is written in its own word after a letter.
type option struct {
	name        string
	value       string
	hasValue    bool
	attached    bool
	first, last int
	long        bool
}

// options reads words as the command does, up to `--`; a word that is not an
// option (an argument, a redirection) does not end them.
func (g grammar) options(words []word) []option {
	var out []option
	for i := 0; i < len(words); i++ {
		w := words[i].text
		if w == "--" {
			break
		}
		if len(w) < 2 || w[0] != '-' {
			continue
		}
		if strings.HasPrefix(w, "--") {
			name, v, eq := strings.Cut(w[2:], "=")
			o := option{name: g.longName(name), value: v, hasValue: eq, first: i, last: i, long: true}
			if !eq && g.takesValue(o.name) && i+1 < len(words) {
				i++
				o.value, o.hasValue, o.last = words[i].text, true, i
			}
			out = append(out, o)
			continue
		}
		for k := 1; k < len(w); k++ {
			o := option{name: w[k : k+1], first: i, last: i}
			rest := w[k+1:]
			switch {
			case strings.IndexByte(g.value, w[k]) >= 0:
				if g.shortEq && strings.HasPrefix(rest, "=") {
					rest = rest[1:]
				}
				if rest != "" {
					o.value, o.hasValue, o.attached = rest, true, true
				} else if i+1 < len(words) {
					i++
					o.value, o.hasValue, o.last = words[i].text, true, i
				}
				out = append(out, o)
				k = len(w)
			case strings.IndexByte(g.attached, w[k]) >= 0:
				o.value, o.hasValue, o.attached = rest, rest != "", rest != ""
				out = append(out, o)
				k = len(w)
			case g.shortEq && strings.HasPrefix(rest, "="):
				o.value, o.hasValue, o.attached = rest[1:], true, true
				out = append(out, o)
				k = len(w)
			default:
				out = append(out, o)
			}
		}
	}
	return out
}

func (g grammar) takesValue(name string) bool {
	for _, l := range g.long {
		if l == name {
			return true
		}
	}
	return false
}

// longName is the long option name stands for: itself, or with prefixes the
// one value-taking option it is the only prefix of.
func (g grammar) longName(name string) string {
	if !g.prefixes || name == "" || g.takesValue(name) {
		return name
	}
	found := ""
	for _, l := range g.long {
		if strings.HasPrefix(l, name) {
			if found != "" {
				return name
			}
			found = l
		}
	}
	if found == "" {
		return name
	}
	return found
}

// is reports whether o is one of the given short letters or long names.
func (o option) is(names ...string) bool {
	for _, n := range names {
		if o.name == n && o.long == (len(n) > 1) {
			return true
		}
	}
	return false
}

// lineWords splits a held line into words from p, with each word's value as
// content; redirections (and the word an operator alone points at) are left
// out.
func lineWords(s string, p int, h *held) []word {
	var out []word
	skipNext := false
	for {
		q := skipSpaces(s, p)
		e := wordEnd(s, q)
		if e == q {
			if q < len(s) && s[q] == 0 {
				p = q + 1
				continue
			}
			return out
		}
		p = e
		raw := s[q:e]
		if skipNext {
			skipNext = false
			continue
		}
		if op := redirectPrefix(raw); op > 0 {
			skipNext = op == len(raw)
			continue
		}
		out = append(out, word{h.put(raw, true), q, e})
	}
}

// redirectPrefix returns the length of the redirection operator raw starts
// with ([n]<, [n]>, &>, with >>, >|, >&, <&, <>, <<<), or 0.
func redirectPrefix(raw string) int {
	i := 0
	for i < len(raw) && isDigit(raw[i]) {
		i++
	}
	if i == 0 && strings.HasPrefix(raw, "&>") {
		i = 1
	}
	if i >= len(raw) || (raw[i] != '<' && raw[i] != '>') {
		return 0
	}
	i++
	for i < len(raw) && strings.IndexByte("<>|&", raw[i]) >= 0 {
		i++
	}
	return i
}
