// Package outboundguard is the PreToolUse hook that keeps what leaves the
// machine reviewable. scripts/hooks/outbound-guard.sh documents the rules and
// starts it.
package outboundguard

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Env is what the guard reads besides its payload.
type Env struct {
	Home         *string
	AutonomyConf string
	ToolkitData  string
	LibDir       string
	Now          int64
}

// EnvFromOS reads Env from the process environment; libDir is the toolkit's
// scripts/lib, named in the hint to record a repository's protection.
func EnvFromOS(libDir string, now int64) Env {
	e := Env{LibDir: libDir, Now: now}
	if h, ok := os.LookupEnv("HOME"); ok {
		e.Home = &h
	}
	home := ""
	if e.Home != nil {
		home = *e.Home
	}
	e.AutonomyConf = os.Getenv("MY_AUTONOMY_CONF")
	if e.AutonomyConf == "" {
		e.AutonomyConf = home + "/.claude/my-toolkit/autonomy.conf"
	}
	e.ToolkitData = os.Getenv("MY_TOOLKIT_DATA")
	if e.ToolkitData == "" {
		e.ToolkitData = home + "/.claude/my-toolkit"
	}
	return e
}

type decision struct{ kind, reason string }

// decided carries the first decision out of the checks.
type decided struct{ d decision }

func decide(kind, reason string) { panic(decided{decision{kind, reason}}) }

// Run judges one hook payload and returns what the hook prints: a
// permissionDecision JSON line, or nothing to allow. Any other panic is
// passed on, so that the process fails and the launcher denies instead.
func Run(payload []byte, env Env) (out string) {
	defer func() {
		if r := recover(); r != nil {
			d, ok := r.(decided)
			if !ok {
				panic(r)
			}
			out = decisionJSON(d.d)
		}
	}()
	(&guard{env: env}).run(payload)
	return ""
}

func decisionJSON(d decision) string {
	return `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":` +
		jsonString(d.kind) + `,"permissionDecisionReason":` + jsonString("outbound-guard: "+d.reason) + "}}\n"
}

// jsonString encodes s as jq does: control bytes and DEL escaped, the rest raw.
func jsonString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range strings.ToValidUTF8(s, "�") {
		switch {
		case r == '"':
			b.WriteString(`\"`)
		case r == '\\':
			b.WriteString(`\\`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\t':
			b.WriteString(`\t`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\b':
			b.WriteString(`\b`)
		case r == '\f':
			b.WriteString(`\f`)
		case r < 0x20 || r == 0x7f:
			b.WriteString(`\u00`)
			b.WriteByte("0123456789abcdef"[r>>4])
			b.WriteByte("0123456789abcdef"[r&15])
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('"')
	return b.String()
}

type guard struct {
	env        Env
	cmd        string
	pendingAsk string
}

// jqRaw renders a JSON value as `jq -r` prints it, with NULs and trailing
// newlines dropped as a shell command substitution does.
func jqRaw(v any) string {
	return strings.ReplaceAll(jqRaw1(v), "\x00", "")
}

func jqRaw1(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case bool:
		if !t {
			return ""
		}
		return "true"
	case string:
		return strings.TrimRight(t, "\n")
	}
	return strings.TrimRight(jqString(v), "\n")
}

// jqString is jq's tostring: a string as it is, anything else as compact JSON.
func jqString(v any) string {
	if s, ok := v.(string); ok {
		return s
	}
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return ""
	}
	return strings.TrimSuffix(b.String(), "\n")
}

var notionWrite = regexp.MustCompile(`^mcp__.*notion-(create-pages|update-page|create-comment|update-comment)$`)

func (g *guard) run(payload []byte) {
	var p map[string]any
	dec := json.NewDecoder(bytes.NewReader(payload))
	dec.UseNumber()
	if err := dec.Decode(&p); err != nil {
		return
	}
	tool := jqRaw(p["tool_name"])
	cwd := jqRaw(p["cwd"])
	input, _ := p["tool_input"].(map[string]any)
	if tool != "Bash" {
		if notionWrite.MatchString(tool) {
			text := strings.TrimRight(strings.ReplaceAll(jqString(p["tool_input"]), "\x00", ""), "\n")
			if r := g.leakReason(text, ""); r != "" {
				decide("deny", r)
			}
		}
		return
	}
	if input == nil {
		return
	}
	g.cmd = jqRaw(input["command"])
	if g.cmd == "" {
		return
	}
	commands := parseCommands(g.cmd, cwd, g.env.Home)
	g.labelCheck()
	textDir := ""
	var apiDirs []string
	for _, c := range commands {
		switch c.Kind {
		case "pr":
			if strings.HasPrefix(c.Rest, "gh api") {
				apiDirs = append(apiDirs, c.Dir)
			}
			g.judgePR(c.Dir, c.Rest, c.Args, c.Repos, c.Also)
		case "push":
			g.judgePush(c.Dir, c.Rest)
		case "text":
			switch c.Dir {
			case "?case":
				if c.Rest == "gh" {
					decide("deny", "case 文と同じ行では gh を実行する directory を判定できない。別のコマンドに分ける")
				}
			case "?", "?git":
				if c.Rest == "gh" {
					decide("deny", "gh を実行する directory を判定できない。cd <絶対パス> で始める")
				}
			default:
				if textDir == "" {
					textDir = c.Dir
				}
			}
		}
	}
	g.textCheck(textDir)
	g.apiCheck(apiDirs)
	if g.pendingAsk != "" {
		decide("ask", g.pendingAsk)
	}
}

var (
	labelAdd  = regexp.MustCompile(`(?i)(^|[^[:alnum:]_.-])gh[[:space:]]+(pr|issue)[[:space:]]+(create|new|edit)[[:space:]].*(--add-label|--label|-l)[[:space:]=]+[^[:space:]]*(human-approved|[$` + "`" + `])`)
	labelEdit = regexp.MustCompile(`(?i)(^|[^[:alnum:]_.-])gh[[:space:]]+label[[:space:]]+edit[[:space:]].*human-approved`)
)

// labelCheck denies adding the approval label `human-approved`, read with
// quotes and backslashes dropped so that human-"approved" is seen.
func (g *guard) labelCheck() {
	flat := strings.Map(func(r rune) rune {
		switch r {
		case '\n':
			return ' '
		case '"', '\\', '\'':
			return -1
		}
		return r
	}, g.cmd)
	if anyLine(flat, labelAdd) || anyLine(flat, labelEdit) || labelOption(g.cmd) {
		decide("deny", "label human-approved は人の承認を表す。agent は付けず、人が GitHub の画面で付ける（label は変数を使わず直接書く）")
	}
}

// labelOption reports whether a gh pr / issue create or edit on the line adds
// human-approved, or a label it does not show, through -l / --label /
// --add-label as gh reads them (-dl human-approved, -lhuman-approved).
func labelOption(cmd string) bool {
	s, h := holdLine(cmd)
	for _, seg := range splitOn(s, listSep(true, "<>|")) {
		for from := 0; ; {
			start, end, ok := findGh(seg, from, ghLabelCmds)
			if !ok {
				break
			}
			from = end
			gr, _ := ghGrammarOf(seg[start:end])
			for _, o := range gr.options(lineWords(seg, end, h)) {
				if o.hasValue && o.is("l", "label", "add-label") &&
					(strings.Contains(strings.ToLower(o.value), "human-approved") || strings.ContainsAny(o.value, "$`")) {
					return true
				}
			}
		}
	}
	return false
}

// anyLine reports whether re matches one of the lines of s, as grep does.
func anyLine(s string, re *regexp.Regexp) bool {
	for _, l := range strings.Split(s, "\n") {
		if re.MatchString(l) {
			return true
		}
	}
	return false
}

var (
	apiMerge = regexp.MustCompile(`(?i)mergePullRequest|enablePullRequestAutoMerge|pulls/[0-9]+/merge`)
	apiReady = regexp.MustCompile(`(?i)markPullRequestReadyForReview|"?draft"?[[:space:]]*[:=][[:space:]]*false`)
)

// draftReason returns why a gh pr create may not open a draft, or "": it
// needs a -d / --draft and none that pflag reads as false (-d=false,
// --draft=0).
func draftReason(args []string) string {
	var words []word
	for _, t := range args[min(3, len(args)):] {
		words = append(words, word{text: t})
	}
	draft := false
	for _, o := range ghGrammars["pr create"].options(words) {
		if !o.is("d", "draft") {
			continue
		}
		if b, err := strconv.ParseBool(o.value); o.hasValue && (err != nil || !b) {
			return "PR は draft で作る（--draft=false は使わない）"
		}
		draft = true
	}
	if draft {
		return ""
	}
	return "PR は draft で作る。gh pr create に --draft を付ける"
}

func isCmd(gh, name string) bool { return gh == name || strings.HasPrefix(gh, name+" ") }

// judgePR denies what a strict repository does not allow. The repositories
// judged are those gh is told to use, or dir's when it is told none, and
// every other one it may act on: all of them must be ship.
func (g *guard) judgePR(dir, gh string, args, repos, also []string) {
	reason, cut := "", false
	hint := "-R <owner/name> を付けるか cd <絶対パス> で始める"
	if strings.HasSuffix(gh, " ?") {
		cut, gh = true, strings.TrimSuffix(gh, " ?")
	}
	switch {
	case isCmd(gh, "gh pr merge"):
		reason = "このリポジトリでは PR をマージしない。draft のまま本人に渡す"
	case isCmd(gh, "gh pr ready"):
		reason = "PR を ready にしない。ready への変更は本人がセルフレビュー後に行う"
	case isCmd(gh, "gh pr create"), isCmd(gh, "gh pr new"):
		reason = draftReason(args)
	case isCmd(gh, "gh api"):
		hint = "cd <絶対パス> で始める"
		if anyLine(g.cmd, apiMerge) {
			reason = "API 経由でも PR をマージしない"
		} else if anyLine(g.cmd, apiReady) {
			reason = "API 経由でも PR を ready にしない"
		}
	}
	if reason == "" {
		return
	}
	if cut {
		decide("deny", "gh の引数を判定できない。command substitution を使わず値を直接書く")
	}
	targets := repos
	if len(targets) == 0 {
		switch dir {
		case "?case":
			decide("deny", "case 文と同じ行では gh を実行するリポジトリを判定できない。-R <owner/name> を付けるか別のコマンドに分ける")
		case "?":
			decide("deny", "gh を実行するリポジトリを判定できない。"+hint)
		}
		targets = []string{repoSlug(dir)}
	}
	targets = append(targets, also...)
	for _, repo := range targets {
		if g.autonomyMode(repo) != "strict" {
			continue
		}
		if g.shipConfigured(repo) {
			if len(repos) > 0 || repo != targets[0] {
				dir = "<" + repo + " の checkout>"
			}
			reason += "（ship の設定はあるが、default branch の保護を確かめた記録がない。" + g.env.LibDir + "/autonomy.sh \"" + dir + "\" を実行する）"
		}
		decide("deny", reason)
	}
}

// git runs git in dir with core.fsmonitor turned off: that setting of the
// repository makes ls-files, which the guard runs, start a program of the
// repository's choosing.
func git(dir string, args ...string) (string, bool) {
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "core.fsmonitor=false"}, args...)...)
	out, err := cmd.Output()
	return strings.TrimRight(string(out), "\n"), err == nil
}

var slugPrefix = regexp.MustCompile(`^(git@[^:]+:|ssh://git@[^/]+/|https?://[^/]+/)`)

// repoSlug returns owner/name of dir's origin remote, empty when unknown.
func repoSlug(dir string) string {
	url, _ := git(dir, "remote", "get-url", "origin")
	lines := strings.Split(url, "\n")
	for i, l := range lines {
		l = slugPrefix.ReplaceAllString(l, "")
		lines[i] = strings.TrimSuffix(l, ".git")
	}
	return strings.TrimRight(strings.Join(lines, "\n"), "\n")
}

// shellLines returns the lines `while read` sees: each one ended by a newline.
func shellLines(data string) []string {
	lines := strings.Split(data, "\n")
	return lines[:len(lines)-1]
}

// shipConfigured reports whether the config opts slug into ship mode.
func (g *guard) shipConfigured(slug string) bool {
	if slug == "" {
		return false
	}
	data, err := os.ReadFile(g.env.AutonomyConf)
	if err != nil {
		return false
	}
	for _, l := range shellLines(string(data)) {
		f := fieldsIFS(l)
		if len(f) >= 2 && f[0] == "ship" && globMatch(f[1], slug) {
			return true
		}
	}
	return false
}

// fieldsIFS splits on spaces, tabs and newlines, as `read` does by default.
func fieldsIFS(s string) []string {
	return strings.FieldsFunc(s, func(r rune) bool { return r == ' ' || r == '\t' || r == '\n' })
}

var plainSlug = regexp.MustCompile(`^[A-Za-z0-9._/-]+$`)

// shipReadyRecorded reports whether a protection check passed within 7 days.
func (g *guard) shipReadyRecorded(slug string) bool {
	if !plainSlug.MatchString(slug) || strings.Count(slug, "/") > 1 || strings.HasPrefix(slug, "/") || strings.HasSuffix(slug, "/") {
		return false
	}
	owner, name := slug, slug
	if k := strings.IndexByte(slug, '/'); k >= 0 {
		owner, name = slug[:k], slug[k+1:]
	}
	data, err := os.ReadFile(g.env.ToolkitData + "/ship-ready/" + owner + "__" + name)
	if err != nil {
		return false
	}
	lines := shellLines(string(data))
	if len(lines) == 0 {
		return false
	}
	at := strings.Trim(lines[0], " \t")
	if at == "" || strings.Trim(at, "0123456789") != "" {
		return false
	}
	n, err := strconv.ParseInt(at, 10, 64)
	if err != nil {
		return false
	}
	age := g.env.Now - n
	return age >= 0 && age <= 604800
}

func (g *guard) autonomyMode(slug string) string {
	if g.shipConfigured(slug) && g.shipReadyRecorded(slug) {
		return "ship"
	}
	return "strict"
}

// pushRefused reports whether a git push long option, possibly abbreviated as
// git allows, forces, deletes or pushes more than one branch.
func pushRefused(name string) bool {
	for _, o := range []string{"force", "force-with-lease", "force-if-includes", "mirror", "all", "branches", "delete", "prune"} {
		if strings.HasPrefix(o, name) {
			return true
		}
	}
	return false
}

// judgePush denies force pushes and pushes to the default branch.
func (g *guard) judgePush(dir, args string) {
	unknownDir := "git push を実行する directory を判定できない。cd <絶対パス> で始めるか git -C <絶対パス> push と書く"
	var positional, dests []string
	tags := false
	toks := fieldsIFS(args)
	words := make([]word, len(toks))
	for i, t := range toks {
		if t == "?" {
			decide("deny", "git push の引数を判定できない。remote と branch を直接書く")
		}
		words[i] = word{text: t}
	}
	inOption := make([]bool, len(toks))
	for _, o := range gitPushGrammar.options(words) {
		for i := o.first; i <= o.last; i++ {
			inOption[i] = true
		}
		tok := words[o.first].text
		switch {
		case !o.long && (o.name == "f" || o.name == "d"), o.long && o.name != "" && pushRefused(o.name):
			decide("deny", "git push "+tok+" は使わない（取り消せない、または既定の branch に及ぶ）")
		case o.long && o.name != "" && strings.HasPrefix("tags", o.name):
			tags = true
			g.pendingAsk = "tag の push は deploy を起こしうる"
		}
	}
	afterDashes := false
	for i, tok := range toks {
		switch {
		case inOption[i]:
		case tok == "--" && !afterDashes:
			afterDashes = true
		case strings.HasPrefix(tok, "-") && !afterDashes:
		case strings.HasPrefix(tok, "+"):
			decide("deny", "+ 付きの refspec は force-push になる")
		default:
			positional = append(positional, tok)
		}
	}
	switch dir {
	case "?case":
		decide("deny", "case 文と同じ行では git push を実行する directory を判定できない。別のコマンドに分けるか git -C <絶対パス> push と書く")
	case "?":
		decide("deny", unknownDir)
	case "?git":
		decide("deny", "git push を実行する directory を判定できない。同じ行で git に別の repository・work tree・設定を指している（GIT_DIR や HOME などへの代入、--git-dir、--work-tree、-c の鍵、env -C）。それを外すか、push を別の Bash 呼び出しに分ける")
	}
	protected := []string{"main", "master"}
	if ref, _ := git(dir, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"); ref != "" {
		protected = append(protected, fieldsIFS(ref[strings.LastIndexByte(ref, '/')+1:])...)
	}
	if len(positional) >= 2 {
		for _, tok := range positional[1:] {
			if strings.HasPrefix(tok, ":") {
				decide("deny", "refspec "+tok+" は remote の branch を消す")
			}
			dst := tok[strings.LastIndexByte(tok, ':')+1:]
			dst = strings.TrimPrefix(dst, "refs/heads/")
			if dst == "HEAD" {
				dst, _ = git(dir, "rev-parse", "--abbrev-ref", "HEAD")
			}
			dests = append(dests, dst)
		}
	} else if !tags {
		cur, _ := git(dir, "rev-parse", "--abbrev-ref", "HEAD")
		if cur == "" {
			decide("deny", unknownDir)
		}
		if cur == "HEAD" {
			decide("deny", "detached HEAD からは push しない")
		}
		dests = append(dests, cur)
	}
	for _, dst := range dests {
		for _, p := range protected {
			if dst == p {
				decide("deny", "既定の branch（"+dst+"）へは push しない。作業 branch から PR を出す")
			}
		}
	}
}

var (
	reviewID  = regexp.MustCompile(`(^|[^A-Za-z0-9_])[CHML][0-9]{3}([^A-Za-z0-9_]|$)`)
	localPath = regexp.MustCompile(`(/Users/|/home/[a-z]|~/|/private/tmp/|/tmp/claude)`)
	docsPath  = func() *regexp.Regexp {
		re := regexp.MustCompile(`(^|[^A-Za-z0-9_./-])docs/[A-Za-z0-9_./-]+`)
		re.Longest()
		return re
	}()
)

// leakReason returns a reason when text cites local artifacts.
func (g *guard) leakReason(text, repo string) string {
	switch {
	case anyLine(text, reviewID):
		return "review finding ID が含まれている。指摘の内容を変更の説明として書く"
	case strings.Contains(text, "docs/reviews/"):
		return "docs/reviews/ のパスが含まれている。ローカルのレビュー記録は外に出さない"
	case anyLine(text, localPath):
		return "ローカルの絶対パスが含まれている。読者が開けない場所を参照しない"
	}
	if repo == "" {
		return ""
	}
	if _, ok := git(repo, "rev-parse", "--git-dir"); !ok {
		return ""
	}
	seen := map[string]bool{}
	var paths []string
	for _, l := range strings.Split(text, "\n") {
		for _, m := range docsPath.FindAllString(l, -1) {
			if k := strings.IndexByte(m, 'd'); k >= 0 {
				m = m[k:]
			}
			m = strings.TrimRight(m, ".,")
			if m != "" && !seen[m] {
				seen[m] = true
				paths = append(paths, m)
			}
		}
	}
	sort.Strings(paths)
	for _, p := range paths {
		if _, ok := git(repo, "ls-files", "--error-unmatch", "--", p); ok {
			continue
		}
		if _, ok := git(repo, "ls-files", "--error-unmatch", "--", strings.TrimSuffix(p, "/")+"/"); ok {
			continue
		}
		return "git で追跡していない " + p + " を参照している。ローカル文書は外に出さない"
	}
	return ""
}

// readBody reads a file as $(cat f) does: NULs and trailing newlines dropped.
func readBody(f string) string {
	data, _ := os.ReadFile(f)
	return strings.TrimRight(strings.ReplaceAll(string(data), "\x00", ""), "\n")
}

// readable is `[ -f f ] && [ -r f ]`.
func readable(f string) bool {
	st, err := os.Stat(f)
	if err != nil || !st.Mode().IsRegular() {
		return false
	}
	fh, err := os.Open(f)
	if err != nil {
		return false
	}
	fh.Close()
	return true
}

func (g *guard) tilde(f string) string {
	if strings.HasPrefix(f, "~") {
		home := ""
		if g.env.Home != nil {
			home = *g.env.Home
		}
		return home + f[1:]
	}
	return f
}

// shellOut is what $(...) keeps of a command's output: trailing newlines go.
func shellOut(s string) string { return strings.TrimRight(s, "\n") }

// grepLines splits the output of `printf '%s\n' "$s" | grep` into the lines
// that start with one of the bytes in prefix (keep) or with none (!keep).
func grepLines(s, prefix string, keep bool) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if (l != "" && strings.IndexByte(prefix, l[0]) >= 0) == keep {
			out = append(out, l)
		}
	}
	return out
}

func basename(f string) string { return f[strings.LastIndexByte(f, '/')+1:] }

// textCheck applies the leak check to the text the outbound commands carry,
// with the body files they name.
func (g *guard) textCheck(textDir string) {
	text := shellOut(outboundText(g.cmd))
	if text == "" {
		return
	}
	body := shellOut(strings.Join(grepLines(text, "\x02\x03", false), "\n"))
	var names []string
	for _, l := range grepLines(text, "\x03", true) {
		names = append(names, basename(l[1:]))
	}
	written := map[string]bool{}
	for _, n := range strings.Split(shellOut(strings.Join(names, "\n")), "\n") {
		written[n] = true
	}
	for _, f := range grepLines(text, "\x02", true) {
		f = f[1:]
		if f == "" {
			decide("deny", "本文を読むコマンドの引数を判定できない。ファイルのパスを直接書く")
		}
		if strings.HasPrefix(f, "/dev/fd/") || f == "/dev/null" {
			continue
		}
		if written[basename(f)] {
			decide("deny", "本文のファイル "+basename(f)+" を同じ呼び出しで書いている。ファイルを書くコマンドと送るコマンドを別の Bash 呼び出しに分ける")
		}
		f = g.tilde(f)
		if !strings.HasPrefix(f, "/") {
			f = textDir + "/" + f
		}
		if !readable(f) {
			decide("deny", "本文のファイル "+basename(f)+" を読めない。ファイルを書くコマンドと送るコマンドを別の Bash 呼び出しに分け、パスを直接書く")
		}
		body += "\n" + readBody(f)
	}
	if r := g.leakReason(shellOut(body), textDir); r != "" {
		decide("deny", r)
	}
}

var (
	labelAPI     = regexp.MustCompile(`(issues|pulls)/[0-9]+/labels|repos/[^[:space:]/]+/[^[:space:]/]+/labels|addLabelsToLabelable|labelIds|createLabel|updateLabel`)
	jsonEscapeNL = regexp.MustCompile(`\\[nrt]`)
)

// apiCheck applies the leak and label checks to what `gh api` writes send.
// dirs are the directories the parser followed for each `gh api` on the line;
// a relative file is read from its own call's directory.
func (g *guard) apiCheck(dirs []string) {
	calls, written := apiCalls(g.cmd)
	for i, c := range calls {
		if !c.writes {
			continue
		}
		dir := ""
		if len(dirs) == len(calls) && !strings.HasPrefix(dirs[i], "?") {
			dir = dirs[i]
		}
		text := shellOut(c.text)
		for _, f := range c.files {
			if f == "" {
				decide("deny", "gh api が送る本文を読むコマンドの引数を判定できない。ファイルのパスを直接書く")
			}
			for _, w := range written {
				if basename(w) == basename(f) {
					decide("deny", "gh api が送るファイル "+basename(f)+" を同じ呼び出しで書いている。ファイルを書くコマンドと gh api を別の Bash 呼び出しに分ける")
				}
			}
			f = g.tilde(f)
			if !strings.HasPrefix(f, "/") {
				if dir == "" {
					decide("deny", "gh api が送るファイル "+basename(f)+" の directory を判定できない。cd <絶対パス> で始めるか、パスを絶対パスで書く")
				}
				f = dir + "/" + f
			}
			if !readable(f) {
				decide("deny", "gh api が送るファイル "+basename(f)+" を読めない。ファイルを書くコマンドと gh api を別の Bash 呼び出しに分け、パスを直接書く")
			}
			text += "\n" + readBody(f) + "\n" + jsonStrings(f)
		}
		if anyLine(text, labelAPI) {
			decide("deny", "gh api で label を書き換えない。human-approved 以外の label は gh pr edit --add-label で付ける")
		}
		if r := g.leakReason(shellOut(jsonEscapeNL.ReplaceAllString(text, " ")), dir); r != "" {
			decide("deny", r)
		}
	}
}

// jsonStrings is `jq -r '.. | strings'` over the JSON values in file f.
func jsonStrings(f string) string {
	data, err := os.ReadFile(f)
	if err != nil {
		return ""
	}
	var out []string
	var walk func(v any)
	walk = func(v any) {
		switch t := v.(type) {
		case string:
			out = append(out, t)
		case map[string]any:
			for _, x := range t {
				walk(x)
			}
		case []any:
			for _, x := range t {
				walk(x)
			}
		}
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	for {
		var v any
		if dec.Decode(&v) != nil {
			break
		}
		walk(v)
	}
	return strings.TrimRight(strings.ReplaceAll(strings.Join(out, "\n"), "\x00", ""), "\n")
}

// globMatch matches s against a shell pattern (* ? [..] [!..]); * also
// matches /.
func globMatch(pattern, s string) bool {
	pattern = strings.ReplaceAll(pattern, "[!", "[^")
	ok, err := filepath.Match(strings.ReplaceAll(pattern, "/", "\x01"), strings.ReplaceAll(s, "/", "\x01"))
	return err == nil && ok
}
