package outboundguard

import (
	"encoding/json"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// Tests for the outbound guard, run in process. Each test is one @test that
// tests/hooks/test_outbound_guard.bats held, under the same name.
//
// Contract under test:
//   - PRs are created as drafts only and never marked ready.
//   - git push never forces, deletes, or targets the default branch.
//   - Outbound text never cites review IDs, local absolute paths, or untracked docs/.
//   - Allowed commands produce no output.

var (
	templateOnce sync.Once
	templateDir  string
	templateErr  error
)

// template builds, once per test binary, the repository every test copies:
// main with an empty commit and a commit adding docs/log/tracked.md, and
// feature/x checked out.
func template(t *testing.T) string {
	templateOnce.Do(func() {
		dir, err := os.MkdirTemp("", "guard-template")
		if err != nil {
			templateErr = err
			return
		}
		repo := filepath.Join(dir, "repo")
		steps := [][]string{
			{"init", "-q", "--template=", "-b", "main", repo},
			{"-C", repo, "commit", "-q", "--allow-empty", "-m", "init"},
		}
		for _, s := range steps {
			if templateErr = gitRun(s...); templateErr != nil {
				return
			}
		}
		if templateErr = os.MkdirAll(filepath.Join(repo, "docs/log"), 0o755); templateErr != nil {
			return
		}
		if templateErr = os.WriteFile(filepath.Join(repo, "docs/log/tracked.md"), []byte("x\n"), 0o644); templateErr != nil {
			return
		}
		for _, s := range [][]string{
			{"-C", repo, "add", "docs/log/tracked.md"},
			{"-C", repo, "commit", "-q", "-m", "docs"},
			{"-C", repo, "checkout", "-q", "-b", "feature/x"},
		} {
			if templateErr = gitRun(s...); templateErr != nil {
				return
			}
		}
		templateErr = chmodTree(dir, false)
		templateDir = repo
	})
	if templateErr != nil {
		t.Fatalf("template repository: %v", templateErr)
	}
	return templateDir
}

func gitRun(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@example.com",
		"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@example.com")
	if out, err := cmd.CombinedOutput(); err != nil {
		return &gitError{args, string(out), err}
	}
	return nil
}

type gitError struct {
	args []string
	out  string
	err  error
}

func (e *gitError) Error() string {
	return "git " + strings.Join(e.args, " ") + ": " + e.err.Error() + ": " + e.out
}

// chmodTree makes every file and directory under dir writable or not.
func chmodTree(dir string, writable bool) error {
	return filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		mode := fs.FileMode(0o444)
		if d.IsDir() {
			mode = 0o555
		}
		if writable {
			mode |= 0o200
		}
		return os.Chmod(path, mode)
	})
}

func TestMain(m *testing.M) {
	code := m.Run()
	if templateDir != "" {
		dir := filepath.Dir(templateDir)
		_ = chmodTree(dir, true)
		_ = os.RemoveAll(dir)
	}
	os.Exit(code)
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		to := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(to, 0o755)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(to, data, 0o644)
	})
}

// fx is one test's fixture: REPO is the template, read-only and shared, until
// the test calls own() for a copy at TMP/repo; TMP holds the files the test
// writes. The autonomy config is absent until a test writes it, and the
// ship-ready record of me/app is fresh.
type fx struct {
	t                *testing.T
	tmp, repo, wt    string
	env              Env
	out, lastCommand string
}

func newFx(t *testing.T) *fx {
	t.Helper()
	t.Parallel()
	tmp, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	f := &fx{t: t, tmp: tmp, repo: template(t)}
	home := os.Getenv("HOME")
	f.env = Env{
		Home:         &home,
		AutonomyConf: filepath.Join(tmp, "autonomy.conf"),
		ToolkitData:  filepath.Join(tmp, "data"),
		LibDir:       "/toolkit/scripts/lib",
		Now:          time.Now().Unix(),
	}
	f.write("data/ship-ready/me__app", strconv.FormatInt(f.env.Now, 10)+"\n")
	return f
}

// own gives the test its own copy of the template at TMP/repo, for a test
// that changes REPO.
func (f *fx) own() {
	f.t.Helper()
	f.repo = filepath.Join(f.tmp, "repo")
	if err := copyTree(template(f.t), f.repo); err != nil {
		f.t.Fatal(err)
	}
}

// write puts content in name, relative to TMP unless absolute.
func (f *fx) write(name, content string) {
	f.t.Helper()
	if !filepath.IsAbs(name) {
		name = filepath.Join(f.tmp, name)
	}
	if err := os.MkdirAll(filepath.Dir(name), 0o755); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(name, []byte(content), 0o644); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fx) git(args ...string) {
	f.t.Helper()
	if err := gitRun(args...); err != nil {
		f.t.Fatal(err)
	}
}

// shipRepo opts REPO into ship mode as me/app.
func (f *fx) shipRepo() {
	f.git("-C", f.repo, "remote", "add", "origin", "git@github.com:me/app.git")
	f.write("autonomy.conf", "ship me/*\n")
}

// mainAndWorktree puts REPO on main and adds WT, a worktree on feature/x.
func (f *fx) mainAndWorktree() {
	f.git("-C", f.repo, "checkout", "-q", "main")
	f.wt = filepath.Join(f.tmp, "wt")
	f.git("-C", f.repo, "worktree", "add", "-q", f.wt, "feature/x")
}

// newRepo makes a repository at TMP/name on main with origin url.
func (f *fx) newRepo(name, url string) string {
	dir := filepath.Join(f.tmp, name)
	f.git("init", "-q", "-b", "main", dir)
	f.git("-C", dir, "remote", "add", "origin", url)
	return dir
}

func (f *fx) runPayload(p map[string]any) {
	data, err := json.Marshal(p)
	if err != nil {
		f.t.Fatal(err)
	}
	f.out = Run(data, f.env)
}

// in judges a Bash call of command whose session cwd is dir.
func (f *fx) in(dir, command string) *fx {
	f.lastCommand = command
	f.runPayload(map[string]any{"tool_name": "Bash", "cwd": dir, "tool_input": map[string]any{"command": command}})
	return f
}

// guard judges a Bash call of command run from REPO.
func (f *fx) guard(command string) *fx { return f.in(f.repo, command) }

func (f *fx) decision() string {
	var v struct {
		H struct {
			D string `json:"permissionDecision"`
			R string `json:"permissionDecisionReason"`
		} `json:"hookSpecificOutput"`
	}
	if f.out == "" {
		return ""
	}
	if err := json.Unmarshal([]byte(f.out), &v); err != nil {
		f.t.Fatalf("output is not JSON: %q", f.out)
	}
	return v.H.D
}

func (f *fx) want(kind string) {
	f.t.Helper()
	if d := f.decision(); d != kind {
		f.t.Fatalf("command %q: want %s, got %q (output %q)", f.lastCommand, kind, d, f.out)
	}
}

func (f *fx) deny() { f.t.Helper(); f.want("deny") }
func (f *fx) ask()  { f.t.Helper(); f.want("ask") }

func (f *fx) allow() {
	f.t.Helper()
	if f.out != "" {
		f.t.Fatalf("command %q: want no output, got %q", f.lastCommand, f.out)
	}
}

var guardTests = []struct {
	name string
	body func(f *fx)
}{
	// --- PR state ---------------------------------------------------------------
	{"gh pr create without --draft is denied", func(f *fx) {
		f.guard(`gh pr create --title t --body b`).deny()
	}},
	{"gh pr create --draft is allowed", func(f *fx) {
		f.guard(`gh pr create --draft --title t --body b`).allow()
	}},
	{"gh pr create -d is allowed", func(f *fx) {
		f.guard(`gh pr create -d --title t --body b`).allow()
	}},
	{"gh pr create --draft=false is denied", func(f *fx) {
		f.guard(`gh pr create --draft=false --title t --body b`).deny()
		f.guard(`gh pr create -d=false --title t --body b`).deny()
		f.guard(`gh pr create --draft=FALSE --title t --body b`).deny()
		f.guard(`gh pr create -d --draft=0 --title t --body b`).deny()
		f.guard(`gh pr create --draft=false -d --title t --body b`).deny()
	}},
	{"gh pr create -d bundled with other short options is a draft", func(f *fx) {
		f.guard(`gh pr create -fd --title t`).allow()
	}},
	{"gh pr ready is denied", func(f *fx) {
		f.guard(`gh pr ready 12`).deny()
	}},
	{"gh api markPullRequestReadyForReview is denied", func(f *fx) {
		f.guard(`gh api graphql -f query="mutation { markPullRequestReadyForReview(input:{pullRequestId:\"x\"}) { clientMutationId } }"`).deny()
	}},
	{"read-only gh pr commands pass", func(f *fx) {
		f.guard(`gh pr view 12 --json isDraft`).allow()
	}},
	{"a read-only API query for the ready-for-review event passes", func(f *fx) {
		f.guard(`gh api graphql -f query='{ repository(owner:"o",name:"r") { pullRequest(number:1) { timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT], first:5) { nodes { __typename } } } } }'`).allow()
	}},

	// --- git push ---------------------------------------------------------------
	{"push of a feature branch is allowed", func(f *fx) {
		f.guard(`git push -u origin feature/x`).allow()
	}},
	{"bare push from a feature branch is allowed", func(f *fx) {
		f.guard(`git push`).allow()
	}},
	{"push to main is denied", func(f *fx) {
		f.guard(`git push origin main`).deny()
	}},
	{"push of HEAD:master is denied", func(f *fx) {
		f.guard(`git push origin HEAD:master`).deny()
	}},
	{"bare push while on main is denied", func(f *fx) {
		f.own()
		f.git("-C", f.repo, "checkout", "-q", "main")
		f.guard(`git push`).deny()
	}},
	{"push to the origin/HEAD default branch is denied", func(f *fx) {
		f.own()
		f.git("-C", f.repo, "update-ref", "refs/remotes/origin/develop", "HEAD")
		f.git("-C", f.repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/develop")
		f.guard(`git push origin develop`).deny()
	}},
	{"force push is denied", func(f *fx) {
		f.guard(`git push --force-with-lease origin feature/x`).deny()
	}},
	{"force and delete bundled with other short options or abbreviated are denied", func(f *fx) {
		for _, c := range []string{
			`git push -uf origin feature/x`,
			`git push -qd origin feature/x`,
			`git push --del origin feature/x`,
			`git push --forc origin feature/x`,
			`git push --mir origin`,
			`git push --branches origin`,
		} {
			f.guard(c).deny()
		}
		f.guard(`git push -u origin feature/x`).allow()
	}},
	{"a push option value is not taken for the remote", func(f *fx) {
		f.own()
		f.git("-C", f.repo, "checkout", "-q", "main")
		f.guard(`git push -o ci.skip origin`).deny()
		f.guard(`git push --recurse-submodules check origin`).deny()
	}},
	{"plus refspec is denied", func(f *fx) {
		f.guard(`git push origin +feature/x`).deny()
	}},
	{"deleting a remote branch is denied", func(f *fx) {
		f.guard(`git push origin :feature/x`).deny()
	}},
	{"leading cd selects the repository", func(f *fx) {
		f.own()
		f.git("-C", f.repo, "checkout", "-q", "main")
		f.in("/", "cd "+f.repo+" && git push").deny()
	}},
	{"bare push after an assignment and cd is judged in that directory", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.guard("W=" + f.wt + `; cd $W && git add f && git commit -q -m "msg" && git push -q && echo pushed`).allow()
	}},
	{"bare push after a later cd into a checkout on the default branch is denied", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "M="+f.repo+`; cd "$M" && git push -q`).deny()
		f.in(f.wt, "export X=1; cd "+f.repo+" && git push -q").deny()
	}},
	{"git -C with a relative path is resolved from the preceding cd", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in("/", "cd "+f.tmp+" && git -C wt push -q").allow()
		f.in("/", "cd "+f.tmp+" && git -C repo push -q").deny()
	}},
	{"a cd after the push does not move it", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "git push -q && cd "+f.repo+" && git fetch -q").allow()
	}},
	{"a cd inside a subshell ends with the subshell", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "(cd "+f.repo+" && make) ; git push -q").allow()
		f.in(f.wt, "(cd "+f.repo+" && git push -q)").deny()
		f.in(f.wt, "(cd "+f.repo+" && echo $(true && true) && git push -q)").deny()
	}},
	{"a push whose directory cannot be followed is denied", func(f *fx) {
		f.guard(`cd "$(mktemp -d)" && git push -q origin feature/x`).deny()
	}},
	{"every push on the line is judged", func(f *fx) {
		f.guard(`git push origin feature/x && git push origin main`).deny()
		f.guard(`git push origin feature/x; git push --force origin feature/x`).deny()
	}},
	{"git -c before push is still a push", func(f *fx) {
		f.guard(`git -c credential.helper=x push origin main`).deny()
		f.guard(`git -c credential.helper=x push origin feature/x`).allow()
	}},
	{"a quoted refspec is read", func(f *fx) {
		f.guard(`git push origin "main"`).deny()
		f.guard(`git push origin 'HEAD:main'`).deny()
		f.guard(`git push origin "feature/x"`).allow()
	}},
	{"a refspec held in a variable is read when the line assigns it", func(f *fx) {
		f.guard(`B=main; git push origin "$B"`).deny()
		f.guard(`B=feature/x; git push origin $B`).allow()
	}},
	{"a push after a single-quoted string holding one double quote is still judged", func(f *fx) {
		f.guard(`grep -n 'x "' f.txt && git commit -q -m "msg" && git push origin main 2>&1 | grep -v '^remote'`).deny()
	}},
	{"a push argument the line does not show is denied", func(f *fx) {
		f.guard(`git push origin "$(git branch --show-current)"`).deny()
	}},
	{"a redirection is not a push argument", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.guard(`git push origin &>/dev/null`).deny()
		f.guard(`git push &> /dev/null`).deny()
		f.guard(`git push origin > /tmp/out.log`).deny()
		f.guard(`git push -q >/dev/null 2>&1`).deny()
		f.guard(`git push origin main>/dev/null`).deny()
		f.in(f.wt, `cd . > /dev/null && git push origin feature/x 2> err.txt`).allow()
	}},
	{"a cd behind if, builtin, a command substitution or a function is followed", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "if cd "+f.repo+"; then git push -q; fi").deny()
		f.in(f.wt, "builtin cd "+f.repo+" && git push -q").deny()
		f.in(f.wt, "out=$(cd "+f.repo+` && git push -q 2>&1); echo "$out"`).deny()
		f.in(f.wt, "f() { cd "+f.repo+" && git push -q; }; f").deny()
		f.in(f.repo, "out=$(cd "+f.wt+` && git push -q 2>&1); echo "$out"`).allow()
	}},
	{"an escaped quote or a $'…' string does not hide a later push", func(f *fx) {
		f.guard(`git commit -q -m 'it'\''s done' && git push origin main 2>&1 | grep -v '^remote'`).deny()
		f.guard(`git commit -q -m $'it\'s done' && git push origin main && echo 'ok'`).deny()
		f.guard(`echo \"start\" && git push origin main && echo "done"`).deny()
	}},
	{"a comment is not read as part of the command", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "# it's time to publish\ngit push --force origin feature/x\necho 'done'").deny()
		f.guard("cd " + f.wt + "  # the worktree\ngit push -u origin feature/x").allow()
		f.in(f.wt, `git push origin feature/x  # not main, no --force`).allow()
		f.in(f.wt, "(cd "+f.repo+" && make)  # build (see the notes\ngit push -q").allow()
	}},
	{"a command written before an unclosed command substitution is still judged", func(f *fx) {
		f.own()
		f.guard(`git push origin main $(echo a && echo b)`).deny()
		f.guard(`gh pr merge 3 $(true && true)`).deny()
		f.guard(`git push origin feature/x $(true && true)`).deny()
		f.mainAndWorktree()
		f.in(f.wt, "X="+f.wt+"; X=$(cd "+f.repo+" && pwd); cd $X && git push -q").deny()
	}},
	{"a redirection into a substitution or a brace list is not a refspec", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.guard(`git push origin > $(mktemp)`).deny()
		f.guard(`git push origin > >(tee log)`).deny()
		f.in(f.wt, `git push origin {main,feature/x}`).deny()
	}},
	{"a segment that closes one substitution and opens the next keeps their directories apart", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.guard("echo $(cd " + f.wt + " && pwd) $(true && git push -q)").deny()
		f.guard("diff <(cd " + f.wt + " && git log -1) <(git push -q | cat)").deny()
		f.in(f.wt, "echo $(cd "+f.wt+" && pwd) $(cd "+f.repo+" && git push -q)").deny()
		f.in(f.wt, "echo $(true && true) $(cd "+f.repo+" && git push -q)").deny()
		f.in(f.wt, "diff <(cd "+f.wt+" && git log -1) <(cd "+f.repo+" && git push -q)").deny()
		f.in(f.wt, "case x in x) (cd "+f.repo+" && git push -q) ;; esac").deny()
		f.guard("echo $(cd " + f.repo + " && pwd) $(cd " + f.wt + " && git push -q)").allow()
		f.in(f.wt, "echo $(cd "+f.repo+" && pwd) $(true && git push -q)").allow()
	}},
	{"a subshell closed on its own segment does not move what follows", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "(cd "+f.repo+") ; git push -q").allow()
		f.guard("(cd " + f.wt + ") ; git push -q").deny()
	}},
	{"a push on a line with a case statement is denied unless it names its directory", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.guard("W=" + f.wt + `; cd "$W" && (cd ` + f.repo + " && case x in a) true ;; esac && git push -q)").deny()
		f.in(f.wt, "(cd "+f.repo+" && case x in a) echo hi ;; esac && git push -q)").deny()
		f.in(f.wt, "case x in x) cd "+f.repo+" ;; esac; git push -q").deny()
		f.in(f.wt, "case x in a) true ;; esac; git -C "+f.wt+" push -q").allow()
		f.in(f.wt, "case x in a) true ;; esac; git -C "+f.repo+" push -q").deny()
		f.in(f.wt, "git push -q; case x in a) true ;; esac").allow()
	}},
	{"a cd written after a closing parenthesis makes the directory unknown", func(f *fx) {
		f.own()
		f.mainAndWorktree()
		f.in(f.wt, "X=$(true && true) cd "+f.repo+" && git push -q").deny()
	}},
	{"a tag push asks only when nothing on the line is denied", func(f *fx) {
		f.guard(`git push --tags`).ask()
		f.guard(`git push --tags && gh pr merge 3`).deny()
		f.guard(`git push --tags origin feature/x && git push origin main`).deny()
	}},

	// --- outbound text ----------------------------------------------------------
	{"commit message with a review finding ID is denied", func(f *fx) {
		f.guard(`git commit -m "fix: address H003 from review"`).deny()
	}},
	{"PR body citing docs/reviews is denied", func(f *fx) {
		f.guard(`gh pr create --draft --title t --body "see docs/reviews/20261119-x.md"`).deny()
	}},
	{"commit message citing an untracked docs file is denied", func(f *fx) {
		f.guard(`git commit -m "plan is in docs/plans/features/x.md"`).deny()
	}},
	{"commit message citing a tracked docs file is allowed", func(f *fx) {
		f.guard(`git commit -m "record the result in docs/log/tracked.md"`).allow()
	}},
	{"local absolute path in a PR comment is denied", func(f *fx) {
		f.guard(`gh pr comment 3 --body "details: /Users/me/Desktop/design.md"`).deny()
	}},
	{"leading cd path is not mistaken for a leak", func(f *fx) {
		f.in("/", "cd "+f.repo+" && git commit -m 'add guard'").allow()
	}},
	{"paths in setup steps before the commit are not a leak", func(f *fx) {
		f.guard(`git init -q /Users/me/tmp/w && git -C /Users/me/tmp/w commit --allow-empty -m init`).allow()
	}},
	{"commands mentioned inside a heredoc message are not run", func(f *fx) {
		f.guard("git commit -q -F - <<'EOF'\ngh pr create and git push origin main are described here\nEOF").allow()
	}},
	{"a file flag written inside a commit message does not hide a review ID", func(f *fx) {
		f.guard("git commit -q -F - <<'EOF'\nfix: x\n\ncomment with -F body=H001\nEOF").deny()
	}},
	{"a body file that cannot be read yet is denied with how to split the call", func(f *fx) {
		f.guard("printf 'x' >" + f.tmp + "/msg.txt && git commit -q -F " + f.tmp + "/later.txt").deny()
		if !strings.Contains(f.out, "later.txt を読めない") {
			f.t.Fatalf("reason does not name later.txt: %q", f.out)
		}
		f.guard(`MSG=$(mktemp); git commit -q -F "$MSG"`).deny()
	}},
	{"a body read from stdin is checked as the heredoc, not as a file", func(f *fx) {
		f.guard("git commit -q -F /dev/stdin <<'EOF'\nfix: x\nEOF").allow()
	}},
	{"a body file written in the same call is denied, even when it already exists", func(f *fx) {
		f.own()
		f.guard(`printf 'fix H001' > m.txt && git commit -q -F m.txt`).deny()
		f.write(f.repo+"/m.txt", "old\n")
		f.guard(`printf 'fix H001' > ./m.txt && git commit -q -F m.txt`).deny()
		f.guard("cp " + f.tmp + "/src.txt m.txt && git commit -q -F m.txt").deny()
		f.guard("cp " + f.tmp + "/src.txt m.txt 2>/dev/null && git commit -q -F m.txt").deny()
		for _, w := range []string{"1>", "2>", "&>", ">|"} {
			f.guard("printf 'fix H001' " + w + " m.txt && git commit -q -F m.txt").deny()
		}
	}},
	{"cp, mv and tee in a title or message do not count as writing the body file", func(f *fx) {
		f.own()
		f.write(f.repo+"/body.md", "body\n")
		f.guard(`gh pr create --draft --title "Add tcp keepalive" --body-file body.md`).allow()
		f.guard(`git commit -q -m "rename via mv x" -F body.md`).allow()
	}},
	{"a body redirected into stdin is checked", func(f *fx) {
		f.write("leak.md", "fixed H001\n")
		f.guard("git commit -q -F - < " + f.tmp + "/leak.md").deny()
		f.guard("git commit -q -F - 0<" + f.tmp + "/leak.md").deny()
	}},
	{"a -C word inside a message or body file does not hide a review ID", func(f *fx) {
		f.guard(`git commit -m "use -C H001 here"`).deny()
		f.write("m.txt", "use -C H001 here\n")
		f.guard("git commit -q -F " + f.tmp + "/m.txt").deny()
		f.guard("gh pr comment 3 --body-file " + f.tmp + "/m.txt").deny()
		f.guard(`gh pr comment 3 --body "run git -C /Users/me/x"`).deny()
		f.guard(`echo see git -C H001 | gh pr comment 3 --body-file -`).deny()
		f.guard(`git log -1 --format="git -C H001" | gh pr comment 3 --body-file -`).deny()
	}},
	{"git -C before commit and -C after it are not message text", func(f *fx) {
		f.guard(`git -C /Users/me/tmp/w commit -m ok`).allow()
		f.guard(`git -c user.name=x -C /Users/me/tmp/w commit -m ok`).allow()
		f.guard(`git commit -m x -C HEAD`).allow()
		f.guard(`git -C /Users/me/tmp/w log -1 --format=%B | gh pr comment 3 --body-file -`).allow()
		f.guard(`gh pr comment 3 --body "$(git -C /Users/me/tmp/w log -1 --format=%B)"`).deny()
	}},
	{"short options bundled with a body file or message are read as git and gh read them", func(f *fx) {
		f.own()
		f.write(f.repo+"/m.txt", "fix H001\n")
		f.write(f.repo+"/clean.txt", "fix x\n")
		for _, c := range []string{
			`git commit -qF m.txt`,
			`git commit -qFm.txt`,
			`git commit -vqF m.txt`,
			`git commit --fil m.txt`,
			`git commit --fil=m.txt`,
			`git commit -mH001`,
			`git commit -amH001`,
			`gh pr create -d -bH001`,
			`gh pr create -d -tH001 -b x`,
			`gh pr comment 3 -eF m.txt`,
			`gh pr comment 3 -eFm.txt`,
			`gh pr comment 3 -F=m.txt`,
			`gh pr review 3 -aF m.txt`,
			`gh pr review 3 -cbH001`,
			`gh issue create -t x -wF m.txt`,
		} {
			f.guard(c).deny()
			if !strings.Contains(f.out, "review finding ID") {
				f.t.Fatalf("command %q: reason is not the review ID: %q", c, f.out)
			}
		}
		for _, c := range []string{
			`git commit -qF clean.txt`,
			`git commit -qFclean.txt`,
			`git commit -am ok`,
			`gh pr comment 3 -eF clean.txt`,
			`gh pr review 3 -aF clean.txt`,
			`gh pr create -d -tFix -b x`,
		} {
			f.guard(c).allow()
		}
	}},
	{"git options other than -C and -c before the subcommand do not hide it", func(f *fx) {
		f.own()
		f.write(f.repo+"/m.txt", "fix H001\n")
		f.guard(`git --no-pager commit -m "fix H001"`).deny()
		f.guard(`git -P commit -qF m.txt`).deny()
		f.guard(`git --literal-pathspecs -c x.y=z commit -mH001`).deny()
		f.guard(`git --no-pager -C /Users/me/tmp/w commit -m ok`).allow()
		f.guard(`git --no-pager push origin main`).deny()
		f.guard(`git --no-pager push origin feature/x`).allow()
		f.guard(`git --git-dir=/x/.git push origin feature/x`).deny()
		f.guard(`git --work-tree /x push origin feature/x`).deny()
		f.guard(`git --attr-source HEAD commit -mH001`).deny()
	}},
	{"git that the guard runs does not start the repository's fsmonitor", func(f *fx) {
		f.own()
		mark := filepath.Join(f.tmp, "ran")
		f.write("fsmonitor.sh", "#!/bin/sh\ntouch "+mark+"\n")
		if err := os.Chmod(filepath.Join(f.tmp, "fsmonitor.sh"), 0o755); err != nil {
			f.t.Fatal(err)
		}
		f.git("-C", f.repo, "config", "core.fsmonitor", filepath.Join(f.tmp, "fsmonitor.sh"))
		f.guard(`git commit -m "record the result in docs/log/tracked.md"`).allow()
		if _, err := os.Stat(mark); err == nil {
			f.t.Fatal("the guard's git ran core.fsmonitor")
		}
	}},
	{"bodies of other gh commands are checked", func(f *fx) {
		f.own()
		f.shipRepo()
		f.write(f.repo+"/m.txt", "fix H001\n")
		f.write(f.repo+"/clean.txt", "fix x\n")
		for _, c := range []string{
			`gh pr merge 3 -s --body "fix H001"`,
			`gh pr merge 3 -s -F m.txt`,
			`gh pr merge 3 -s -tH001`,
			`gh pr close 3 -c "fix H001"`,
			`gh pr reopen 3 --comment "fix H001"`,
			`gh issue close 3 -c "fix H001"`,
			`gh issue reopen 3 -c "fix H001"`,
			`gh release create v1 --notes "fix H001"`,
			`gh release create v1 -F m.txt`,
			`gh release edit v1 --notes-file m.txt`,
			`gh gist create m.txt`,
			`gh gist create -d "fix H001" clean.txt`,
			`gh gist edit abc -a m.txt`,
			`gh gist create < m.txt`,
			`gh gist edit abc m.txt`,
			`gh gist edit abc - < m.txt`,
			`gh release new v1 --notes "fix H001"`,
			`gh release create v1 './app.tgz#fix H001'`,
			`gh pr comment 3 -b x --attach './a.png#see H001'`,
		} {
			f.guard(c).deny()
			if !strings.Contains(f.out, "review finding ID") {
				f.t.Fatalf("command %q: reason is not the review ID: %q", c, f.out)
			}
		}
		for _, c := range []string{
			`gh pr merge 3 -s --body ok`,
			`gh gist create clean.txt`,
			`gh release create v1 /Users/me/dist/app.tgz --notes ok`,
			`gh pr comment 3 -b x --attach /Users/me/a.png`,
		} {
			f.guard(c).allow()
		}
	}},
	{"a body file path written in the same word as its option is not message text", func(f *fx) {
		f.write("tmp/claude-x/clean.txt", "fix x\n")
		f.guard("git commit -qF" + f.tmp + "/tmp/claude-x/clean.txt").allow()
		f.guard("gh api repos/o/r/issues/1/comments -Fbody=@" + f.tmp + "/tmp/claude-x/clean.txt").allow()
	}},
	{"quoted gh options are read by their value", func(f *fx) {
		f.guard(`gh pr create -d "--draft=false" --title t --body b`).deny()
		f.own()
		f.shipRepo()
		f.guard(`gh pr merge 3 "-R" work/app`).deny()
		f.guard(`gh pr merge 3 "-R" me/app`).allow()
		f.guard(`gh pr merge 3 "--repo" work/app`).deny()
		f.guard(`gh pr merge 3 "--repo=work/app"`).deny()
	}},
	{"file flags quoted inside a message are message text, not body files", func(f *fx) {
		f.guard(`git commit -q -m 'read config with --file $CONFIG or -F /etc/nothere'`).allow()
		f.guard(`git commit -q --allow-empty -F /dev/null`).allow()
	}},
	{"commands mentioned inside a quoted message are not run", func(f *fx) {
		f.guard(`git commit -m "explain why gh pr ready is denied"`).allow()
	}},
	{"body file contents are checked", func(f *fx) {
		f.write("body.md", "see docs/reviews/r.md\n")
		f.guard("gh pr create --draft --title t --body-file " + f.tmp + "/body.md").deny()
	}},
	{"paths in commands after a heredoc commit are not a leak", func(f *fx) {
		f.guard("git commit -q -F - <<'EOF'\nfix: x\nEOF\ngit push -q 2>&1 | tail -1; cat /private/tmp/claude-1/x/out.txt").allow()
	}},
	{"paths in commands after a PR body are not a leak", func(f *fx) {
		f.guard("gh pr create --draft --title t --body \"$(cat <<'EOF'\nbody\nEOF\n)\"; cat /private/tmp/claude-1/x/out.txt").allow()
	}},
	{"a path in the PR body is denied even with later commands", func(f *fx) {
		f.guard(`gh pr create --draft --title t --body "see /Users/me/x.md" && cat /private/tmp/claude-1/x/out.txt`).deny()
	}},
	{"a path inside a heredoc commit message is denied", func(f *fx) {
		f.guard("git commit -q -F - <<'EOF'\nsee /Users/me/notes.md\nEOF\ngit push -q").deny()
	}},
	{"a path in a body continued onto the next line is denied", func(f *fx) {
		f.guard("gh pr create --draft \\\n  --title t \\\n  --body \"see /Users/me/x.md\"").deny()
	}},
	{"a path in a heredoc whose operator line goes on is denied", func(f *fx) {
		f.guard("git commit -q -F - <<'EOF' && git push -q\nsee /Users/me/notes.md\nEOF").deny()
	}},
	{"a path in a body piped into the outbound command is denied", func(f *fx) {
		f.guard("cat <<'EOF' | gh pr create --draft --title t --body-file -\nsee /Users/me/notes.md\nEOF").deny()
	}},
	{"a path in a message after a single-quoted string holding one double quote is denied", func(f *fx) {
		f.guard(`grep -n 'x "' f.txt && git commit -q -m "see /Users/me/notes.md"`).deny()
	}},
	{"an env prefix before the commit is not a leak", func(f *fx) {
		f.guard(`GIT_INDEX_FILE=/Users/me/idx git commit -m "add guard"`).allow()
	}},
	{"notion page update with a local path is denied", func(f *fx) {
		f.lastCommand = "notion-update-page"
		f.runPayload(map[string]any{"tool_name": "mcp__claude_ai_Notion__notion-update-page", "cwd": "/",
			"tool_input": map[string]any{"content": "正本 /Users/me/Desktop/x.md"}})
		f.deny()
	}},
	{"unrelated tools pass silently", func(f *fx) {
		f.lastCommand = "Read"
		f.runPayload(map[string]any{"tool_name": "Read", "cwd": "/", "tool_input": map[string]any{"file_path": "/Users/me/x"}})
		f.allow()
	}},

	// --- autonomy modes ---------------------------------------------------------
	{"strict: gh pr merge is denied", func(f *fx) {
		f.guard(`gh pr merge 3 --squash`).deny()
	}},
	{"strict: merging through the API is denied", func(f *fx) {
		f.guard(`gh api -X PUT repos/o/r/pulls/3/merge`).deny()
	}},
	{"strict: a repo absent from the config stays strict", func(f *fx) {
		f.own()
		f.git("-C", f.repo, "remote", "add", "origin", "git@github.com:work/app.git")
		f.write("autonomy.conf", "ship me/*\n")
		f.guard(`gh pr create --title t --body b`).deny()
	}},
	{"ship: non-draft PR, ready and merge are allowed", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr create --title t --body b`).allow()
		f.guard(`gh pr ready 3`).allow()
		f.guard(`gh pr merge 3 --squash --delete-branch`).allow()
	}},
	{"ship: pushing to the default branch is still denied", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`git push origin main`).deny()
	}},
	{"ship: force push is still denied", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`git push --force-with-lease origin feature/x`).deny()
	}},
	{"ship: leak checks still apply", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr create --title t --body "see /Users/me/x.md"`).deny()
	}},
	{"ship cwd: gh -R naming another repo is judged as that repo", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr merge 3 -R work/app`).deny()
		f.guard(`gh pr merge 3 -sR work/app`).deny()
		f.guard(`gh pr merge 3 -sdR work/app`).deny()
		f.guard(`gh pr merge 3 -sR me/app`).allow()
	}},
	{"ship cwd: cd into a strict repo is judged as that repo", func(f *fx) {
		f.own()
		f.shipRepo()
		work := f.newRepo("work", "https://github.com/work/app.git")
		f.guard("cd " + work + " && gh pr merge 3").deny()
	}},
	{"ship cwd: a later cd into a strict repo is judged as that repo", func(f *fx) {
		f.own()
		f.shipRepo()
		work := f.newRepo("work", "https://github.com/work/app.git")
		f.guard("S=" + work + "; cd $S && gh pr merge 3").deny()
		f.guard("export X=1; cd " + work + " && gh pr create --title t --body b").deny()
	}},
	{"strict cwd: a later cd into a ship repo is judged as that repo", func(f *fx) {
		ship := f.newRepo("ship", "git@github.com:me/app.git")
		f.write("autonomy.conf", "ship me/*\n")
		f.guard("S=" + ship + "; cd $S && gh pr merge 3 --squash").allow()
	}},
	{"a PR command whose repository cannot be followed is denied unless -R names it", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`cd "$(mktemp -d)" && gh pr merge 3`).deny()
		f.guard(`cd "$(mktemp -d)" && gh pr merge 3 -R me/app`).allow()
		f.guard(`cd "$(mktemp -d)" && gh pr view 3`).allow()
	}},
	{"strict: every PR command on the line is judged", func(f *fx) {
		f.guard(`gh pr create --title a --body b; gh pr create --draft --title c --body d`).deny()
	}},
	{"a commit in a directory that cannot be followed is not denied for that", func(f *fx) {
		f.guard(`D="$(mktemp -d)"; cd "$D" && git init -q && git commit -q --allow-empty -m init`).allow()
	}},
	{"the tracked-docs test runs where the commit runs", func(f *fx) {
		f.in("/", "X=1; cd "+f.repo+` && git commit -m "plan is in docs/plans/features/x.md"`).deny()
		f.in("/", "X=1; cd "+f.repo+` && git commit -m "record the result in docs/log/tracked.md"`).allow()
	}},
	{"strict: a PR command closed by a parenthesis or followed by a redirection is judged", func(f *fx) {
		f.guard(`(gh pr merge)`).deny()
		f.guard(`out=$(gh pr ready)`).deny()
		f.guard(`gh pr merge>/dev/null`).deny()
		f.guard(`gh pr new --title t --body b`).deny()
	}},
	{"ship cwd: a cd inside a command substitution into a strict repo is followed", func(f *fx) {
		f.own()
		f.shipRepo()
		work := f.newRepo("work", "https://github.com/work/app.git")
		f.guard("url=$(cd " + work + " && gh pr create --title t --body b)").deny()
		f.guard("if cd " + work + "; then gh pr merge 3 --squash; fi").deny()
	}},
	{"a gh message command whose directory cannot be followed is denied", func(f *fx) {
		f.own()
		f.write(f.repo+"/body.md", "see docs/reviews/r.md\n")
		f.guard(`W=$(pwd); cd "$W" && gh pr create --draft --title t --body-file body.md`).deny()
		f.guard(`W=$(pwd); cd "$W" && gh pr comment 3 --body "plan is in docs/plans/features/x.md"`).deny()
	}},
	{"the hint for gh api does not offer -R", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`cd "$(mktemp -d)" && gh api -X PUT repos/{owner}/{repo}/pulls/3/merge`).deny()
		if strings.Contains(f.out, "-R") {
			f.t.Fatalf("the hint offers -R: %q", f.out)
		}
	}},
	{"ship cwd: -R after a command substitution still names the repository", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr merge $(gh pr view 3 --json number -q .number) -R work/app`).deny()
		f.guard(`gh pr ready $(gh pr view --json number -q .number) -R work/app`).deny()
		f.guard(`gh pr merge $(gh pr view 3 --json number -q .number) -R me/app`).allow()
		f.guard(`gh api x $(gh pr merge 3 -R work/app)`).deny()
	}},
	{"ship cwd: a substitution inside a subshell does not hide where the subshell opens", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`(gh pr merge $(gh pr view 3 --json number -q .number) -R me/app | cat)`).allow()
		f.guard(`(gh pr merge $(gh pr view 3 --json number -q .number) -R work/app | cat)`).deny()
		f.guard(`(echo $(date) && gh pr merge 3 -R work/app)`).deny()
	}},
	{"a PR command whose arguments are cut by a pipe inside a substitution is denied", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr merge $(gh pr list --json number -q '.[0].number' | head -1) -R work/app --squash`).deny()
		f.guard(`echo $(gh pr merge 3 -R me/app) $(true && true)`).allow()
	}},
	{"strict: --draft after a command substitution is seen", func(f *fx) {
		f.guard(`gh pr create --title $(echo t) --body b --draft`).allow()
	}},
	{"ship cwd: a strict directory entered in one substitution does not carry into the next, nor is the next one's own lost", func(f *fx) {
		ship := f.newRepo("ship", "git@github.com:me/app.git")
		f.write("autonomy.conf", "ship me/*\n")
		f.guard("echo $(cd " + ship + " && pwd) $(true && gh pr merge 3)").deny()
		f.guard("echo $(cd " + ship + " && pwd) $(true && gh pr create --title t --body b)").deny()
		f.in(ship, "echo $(true && true) $(cd "+f.repo+" && gh pr merge 3)").deny()
		f.in(ship, "echo $(cd "+f.repo+" && pwd) $(true && gh pr merge 3)").allow()
	}},
	{"ship cwd: a PR command on a line with a case statement needs -R", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`case x in x) gh pr merge 3 -R work/app ;; esac`).deny()
		f.guard(`case x in x) gh pr merge 3 -R me/app ;; esac`).allow()
		f.guard(`case x in x) gh pr merge 3 ;; esac`).deny()
	}},

	// --- gh api writes carry outbound text --------------------------------------
	{"api: a read-only gh api call is allowed", func(f *fx) {
		f.guard(`gh api repos/o/r/pulls/1/comments`).allow()
		f.guard(`gh api --paginate repos/o/r/pulls/1/comments --jq '.[] | select(.body | test("H001"))'`).allow()
	}},
	{"a file read into a message written after -m is checked as the file, not as its path", func(f *fx) {
		f.write("home/clean.md", "fix x\n")
		f.write("home/leak.md", "fix H001\n")
		home := filepath.Join(f.tmp, "home")
		f.env.Home = &home
		f.guard(`git commit -m"$(cat ~/clean.md)"`).allow()
		f.guard(`git commit -m"$(cat ~/leak.md)"`).deny()
	}},
	{"api: fields bundled after a boolean short option are checked", func(f *fx) {
		f.write("body.md", "fixed H001\n")
		f.guard("gh api repos/o/r/issues/1/comments -iF body=@" + f.tmp + "/body.md").deny()
		f.guard("gh api repos/o/r/issues/1/comments -iFbody=@" + f.tmp + "/body.md").deny()
		f.guard(`gh api repos/o/r/issues/1/comments -iFbody=H001`).deny()
		f.guard(`gh api repos/o/r/issues/1/comments -if body=H001`).deny()
		f.guard(`gh api -X GET -XPOST repos/o/r/issues/1/comments -f body=H001`).deny()
		f.guard(`gh api -XPOST -X GET repos/o/r/issues/1/comments -f body=H001`).deny()
		f.write("clean.md", "fixed in abc123\n")
		f.guard("gh api repos/o/r/issues/1/comments -iF body=@" + f.tmp + "/clean.md").allow()
	}},
	{"api: GET with query fields is not a write", func(f *fx) {
		f.guard(`gh api -X GET search/issues -f q="repo:o/r H001"`).allow()
	}},
	{"api: a field with a local path is denied", func(f *fx) {
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="see /Users/alice/foo"`).deny()
	}},
	{"api: a typed field with a review ID is denied", func(f *fx) {
		f.guard(`gh api repos/o/r/issues/1/comments -F body=H001`).deny()
		f.guard(`gh api repos/o/r/issues/1/comments -F body="H001 fixed"`).deny()
		f.guard(`gh api repos/o/r/issues/1/comments --raw-field=body=H001`).deny()
	}},
	{"api: a clean field is allowed", func(f *fx) {
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="fixed in abc123"`).allow()
	}},
	{"api: an input file citing a review ID, a local path or docs/reviews is denied", func(f *fx) {
		f.write("a.json", `{"body":"fixed H001"}`)
		f.guard("gh api --method POST repos/o/r/pulls/1/comments/9/replies --input " + f.tmp + "/a.json").deny()
		f.write("b.json", `{"body":"see /Users/alice/x.md"}`)
		f.guard("gh api -XPOST repos/o/r/pulls/1/comments/9/replies --input=" + f.tmp + "/b.json").deny()
		f.write("c.json", `{"body":"see docs/reviews/r.md"}`)
		f.guard("gh api --method=post repos/o/r/pulls/1/comments/9/replies --input '" + f.tmp + "/c.json'").deny()
	}},
	{"api: a review ID after a JSON newline escape is denied", func(f *fx) {
		f.write("a.json", `{"body":"done\nH001"}`)
		f.guard("gh api --method POST repos/o/r/issues/1/comments --input " + f.tmp + "/a.json").deny()
	}},
	{"api: an input file citing an untracked docs path is denied", func(f *fx) {
		f.own()
		f.write(f.repo+"/a.json", `{"body":"see docs/plan/x.md"}`)
		f.guard(`gh api --method POST repos/o/r/issues/1/comments --input a.json`).deny()
		f.write(f.repo+"/b.json", `{"body":"see docs/log/tracked.md"}`)
		f.guard(`gh api --method POST repos/o/r/issues/1/comments --input b.json`).allow()
	}},
	{"api: a clean input file under a local path is allowed", func(f *fx) {
		f.write("home/reply.json", `{"body":"fixed in abc123"}`)
		home := filepath.Join(f.tmp, "home")
		f.env.Home = &home
		f.guard(`gh api --method POST repos/o/r/pulls/1/comments/9/replies --input ~/reply.json`).allow()
	}},
	{"api: an input file the hook cannot read is denied", func(f *fx) {
		f.guard(`jq -n '{body:"x"}' >` + f.tmp + "/new.json && gh api --method POST repos/o/r/issues/1/comments --input " + f.tmp + "/new.json").deny()
	}},
	{"api: a field read from a file is checked", func(f *fx) {
		f.write("body.md", "fixed H001\n")
		f.guard("gh api repos/o/r/issues/1/comments -F body=@" + f.tmp + "/body.md").deny()
		f.write("clean.md", "fixed in abc123\n")
		f.guard("gh api repos/o/r/issues/1/comments -F body=@" + f.tmp + "/clean.md").allow()
	}},
	{"api: a body piped into --input - is checked", func(f *fx) {
		f.guard(`jq -n --arg b 'fixed H001' '{body:$b}' | gh api --method POST repos/o/r/issues/1/comments --input -`).deny()
		f.guard(`jq -n --arg b 'fixed in abc123' '{body:$b}' | gh api --method POST repos/o/r/issues/1/comments --input -`).allow()
	}},
	{"api: the word --input inside a quoted body is not a flag", func(f *fx) {
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="pass --input reply.json"`).allow()
	}},
	{"api: a field read from stdin is checked through its pipe", func(f *fx) {
		f.guard(`printf 'fixed H001' | gh api repos/o/r/issues/1/comments -F body=@-`).deny()
		f.guard(`printf 'fixed in abc123' | gh api repos/o/r/issues/1/comments -F body=@-`).allow()
		f.write("body.md", "fixed H001\n")
		f.guard("gh api repos/o/r/issues/1/comments -F body=@- <" + f.tmp + "/body.md").deny()
	}},
	{"api: a relative input file is read from the directory its own gh api runs in", func(f *fx) {
		f.write("a/body.json", `{"body":"fixed H001"}`)
		f.write("b/body.json", `{"body":"fixed in abc123"}`)
		f.in("/", "cd "+f.tmp+"/b && gh api repos/o/r/pulls/1; cd "+f.tmp+"/a && gh api --method POST repos/o/r/issues/1/comments --input body.json").deny()
		f.in("/", "cd "+f.tmp+"/a && gh api repos/o/r/pulls/1; cd "+f.tmp+"/b && gh api --method POST repos/o/r/issues/1/comments --input body.json").allow()
		f.in(f.tmp+"/b", `cd "$(mktemp -d)" && gh api --method POST repos/o/r/issues/1/comments --input body.json`).deny()
		f.in("/", "cd "+f.tmp+"/a && gh api repos/o/r/pulls/1; cd "+f.tmp+"/b && gh api --method POST repos/o/r/issues/1/comments --input body.json -f who=$(gh api user -q .login)").allow()
		f.in("/", "cd "+f.tmp+"/b && gh api repos/o/r/pulls/1; cd "+f.tmp+"/a && gh api --method POST repos/o/r/issues/1/comments --input body.json -f who=$(gh api user -q .login)").deny()
	}},
	{"api: an output redirection is not part of what is sent", func(f *fx) {
		f.guard(`gh api graphql -f query='{ viewer { login } }' > /Users/alice/out.json`).allow()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="fixed in abc123" >/Users/alice/out.json 2>> /Users/alice/err.log`).allow()
		f.guard(`gh pr comment 3 --body "fixed in abc123" &> /Users/alice/out.log`).allow()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="see /Users/alice/x" > out.json`).deny()
		f.guard("gh pr comment 3 --body-file - > /Users/alice/out.log <<'EOF'\nsee /Users/me/notes.md\nEOF").deny()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments --input - <<< '{"body":"fixed H001"}' > /Users/alice/out.json`).deny()
	}},
	{"a body read through cat or a substitution is checked", func(f *fx) {
		f.write("leak.md", "see /Users/alice/x\n")
		f.write("clean.md", "fixed in abc123\n")
		f.write("leak.json", `{"body":"fixed H001"}`)
		f.write("clean.json", `{"body":"fixed in abc123"}`)
		f.guard(`gh pr comment 3 --body "$(cat ` + f.tmp + `/leak.md)"`).deny()
		f.guard(`gh pr comment 3 --body "$(cat ` + f.tmp + `/clean.md)"`).allow()
		f.guard(`gh pr comment 3 --body "$(<` + f.tmp + `/leak.md)"`).deny()
		f.guard("gh pr comment 3 --body \"`cat " + f.tmp + "/leak.md`\"").deny()
		f.guard(`cat ` + f.tmp + `/leak.md | gh pr comment 3 --body-file -`).deny()
		f.guard(`cat ` + f.tmp + `/clean.md | gh pr comment 3 --body-file -`).allow()
		f.guard(`cat ` + f.tmp + `/leak.json | gh api --method POST repos/o/r/issues/1/comments --input -`).deny()
		f.guard(`cat ` + f.tmp + `/clean.json | gh api --method POST repos/o/r/issues/1/comments --input -`).allow()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="$(cat ` + f.tmp + `/leak.md)"`).deny()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -f body="$(cat ` + f.tmp + `/clean.md)"`).allow()
		f.in(f.tmp, `gh pr comment 3 --body "$(cat leak.md)"`).deny()
		f.guard(`gh pr comment 3 --body 'run $(cat nofile) to see it'`).allow()
		f.guard(`gh pr comment 3 --body "$(cat "$F")"`).deny()
		f.guard(`echo x > ` + f.tmp + `/clean.md && gh pr comment 3 --body "$(cat ` + f.tmp + `/clean.md)"`).deny()
		f.guard(`echo x > ` + f.tmp + `/clean.json && cat ` + f.tmp + `/clean.json | gh api --method POST repos/o/r/issues/1/comments --input -`).deny()
		f.guard(`gh pr create --draft --title $(echo t) --body "$(git log -1 --format=%b)"`).allow()
		f.guard(`gh pr comment 3 --body "run \$(cat nofile) to see it"`).allow()
		f.guard("gh pr comment 3 --body \"run \\`cat nofile\\` to see it\"").allow()
		f.guard(`gh pr comment 3 --body "$(cat '` + f.tmp + `/clean.md')"`).allow()
		f.guard(`gh pr comment 3 --body "$(cat '` + f.tmp + `/leak.md')"`).deny()
	}},
	{"a clean body read through cat from a local path is allowed", func(f *fx) {
		f.write("home/clean.md", "fixed in abc123\n")
		f.write("home/leak.md", "fixed H001\n")
		home := filepath.Join(f.tmp, "home")
		f.env.Home = &home
		f.guard(`gh pr comment 3 --body "$(cat ~/clean.md)"`).allow()
		f.guard(`cat ~/clean.md | gh pr comment 3 --body-file -`).allow()
		f.guard(`gh api --method POST repos/o/r/issues/1/comments -F body=@- < ~/clean.md`).allow()
		f.guard(`gh pr comment 3 --body "$(cat ~/leak.md)"`).deny()
		f.guard(`< ~/leak.md gh pr comment 3 --body-file -`).deny()
		f.guard(`< ~/clean.md gh pr comment 3 --body-file -`).allow()
		f.guard(`< ~/leak.md gh api --method POST repos/o/r/issues/1/comments -F body=@-`).deny()
	}},
	{"ship cwd: a repository named by an attached -R, a PR URL, GH_REPO or an API path is judged as that repo", func(f *fx) {
		f.own()
		f.shipRepo()
		f.guard(`gh pr merge 3 -Rwork/app`).deny()
		f.guard(`gh pr merge https://github.com/work/app/pull/3 --squash`).deny()
		f.guard(`GH_REPO=work/app gh pr merge 3`).deny()
		f.guard(`export GH_REPO=work/app; gh pr merge 3`).deny()
		f.guard(`gh api -X PUT repos/work/app/pulls/3/merge`).deny()
		f.guard(`gh api -X PUT /repos/work/app/pulls/3/merge`).deny()
		f.guard(`GH_REPO=work/app; gh pr merge 3`).deny()
		f.guard(`gh pr merge 3 --subject https://github.com/work/app/pull/9`).deny()
		f.guard(`gh pr merge https://github.com/work/app/pull/3 -R me/app`).deny()
		f.guard(`gh pr merge "https://github.com/work/app/pull/3"`).deny()
		f.guard(`gh api -X PUT "repos/work/app/pulls/3/merge"`).deny()
		f.guard(`GH_REPO="work/app" gh pr merge 3`).deny()
		f.guard(`gh api -X PATCH repos/work/app/pulls/3 -F draft=false`).deny()
		f.guard(`gh pr merge 3 -R "$R"`).deny()
		f.guard(`gh api -X PATCH repos/me/app/pulls/3 -F draft=false`).allow()
		f.guard(`gh pr merge 3 -Rme/app`).allow()
		f.guard(`gh pr merge https://github.com/me/app/pull/3 --squash`).allow()
		f.guard(`GH_REPO=me/app gh pr merge 3`).allow()
		f.guard(`gh api -X PUT repos/me/app/pulls/3/merge`).allow()
		f.guard(`gh api -X PUT repos/{owner}/{repo}/pulls/3/merge`).allow()
	}},
	{"strict cwd: only -R and a GH_REPO just before gh stand in for the directory's repo", func(f *fx) {
		f.write("autonomy.conf", "ship me/*\n")
		f.guard(`gh pr merge https://github.com/me/app/pull/3`).deny()
		f.guard(`gh api -X PUT repos/me/app/pulls/3/merge`).deny()
		f.guard(`gh pr merge 3 --subject https://github.com/me/app/pull/9`).deny()
		f.guard(`echo GH_REPO=me/app; gh pr merge 3`).deny()
		f.guard(`GH_REPO=me/app true; gh pr merge 3`).deny()
		f.guard(`GH_REPO=me/app; gh pr merge 3`).deny()
		f.guard(`gh api -X PUT repos/{owner}/{repo}/pulls/3/merge -f x=/repos/me/app`).deny()
		f.guard(`gh api graphql -f query='mutation{mergePullRequest(input:{pullRequestId:"x"}){clientMutationId}}' -f n=/repos/me/app`).deny()
		f.guard(`gh pr create --title https://github.com/me/app/pull/1 --body b`).deny()
		f.guard(`gh pr merge 3 -R me/app`).allow()
		f.guard(`GH_REPO=me/app gh pr merge 3`).allow()
		f.guard(`export GH_REPO=me/app; gh pr merge 3`).deny()
		f.guard(`export GH_REPO=me/app; unset GH_REPO; gh pr merge 3`).deny()
		f.guard(`export GH_REPO=me/app; env -u GH_REPO gh pr merge 3`).deny()
		f.guard(`false && export GH_REPO=me/app; gh pr merge 3`).deny()
		f.guard(`if false; then export GH_REPO=me/app; fi; gh pr merge 3`).deny()
		f.guard(`gh pr merge 3 -Rme/app`).deny()
		f.guard(`gh pr merge 3 --subject -Rme/app`).deny()
		f.guard(`gh api -X PUT repos/{owner}/{repo}/pulls/3/merge -q -Rme/app`).deny()
	}},
	{"ship: a protection record older than 7 days or dated in the future is strict", func(f *fx) {
		f.own()
		f.shipRepo()
		record := func(at int64) { f.write("data/ship-ready/me__app", strconv.FormatInt(at, 10)+"\n") }
		record(f.env.Now - 604801)
		f.guard(`gh pr merge 3`).deny()
		record(f.env.Now + 1)
		f.guard(`gh pr merge 3`).deny()
		record(f.env.Now - 604800)
		f.guard(`gh pr merge 3`).allow()
	}},
}

func TestNULInCommandIsDropped(t *testing.T) {
	f := newFx(t)
	done := make(chan struct{})
	go func() {
		f.guard("gh pr comment 1 --body \"\x000\x00\"")
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the guard did not return for a command holding NULs")
	}
	f.allow()
}

func TestGuard(t *testing.T) {
	seen := map[string]bool{}
	for _, tc := range guardTests {
		if seen[tc.name] {
			t.Fatalf("two tests named %q", tc.name)
		}
		seen[tc.name] = true
		tc := tc
		t.Run(tc.name, func(t *testing.T) { tc.body(newFx(t)) })
	}
}
