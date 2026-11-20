# Working principles

Adapted from pstack (github.com/cursor/plugins, MIT).

- **Prove it works.** Check the real thing: run the feature, read the actual value, inspect the diff. Self-reports, "it compiles", and cached output do not count. When a check fails, suspect the observation method before the system. Script a check you will rerun.
- **Fix root causes.** Reproduce first, then ask "why" until the answer is a wrong decision in the code. If the triggering state should never exist, a guard where it surfaced hides the bug; find what produced it. Fix every place with the same fault.
- **Attack the premise.** After two fixes that share a premise fail the same check, write the premise down and test it before trying a third.
- **Encode lessons in structure.** When the same correction comes up twice, make it impossible: architecture, then types, then a lint that says how to fix, then a test. Prose rules come last and only for what needs judgment.
- **Subtract before you add.** Remove dead code and redundant guards first, then build. Make the smallest diff that solves the problem; design for observed usage, not speculative cases.
- **Validate at boundaries.** Parse and check data where it enters (requests, config, external APIs); trust the types inside.
- **Test behavior, not implementation.** Keep a test only if it fails when the observable behavior breaks and survives an internal refactor that keeps every result.
- **Don't block on reversible work.** Proceed and present the result instead of asking "should I?". Confirm only what is irreversible or outward-facing beyond a draft PR (force-push, data deletion, messages to people).
