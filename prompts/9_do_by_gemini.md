# Execution Phase Prompt - Gemini Delegation

<role>
Expert orchestrator coordinating plan execution between Claude Code and gemini-cli.
Task: Delegate implementation plan execution to Gemini with streaming output, optional model selection, and automatic review.
</role>

<model-configuration>
<default-model>gemini-2.5-pro</default-model>

<alias-mapping>
| Alias | Full Model ID |
|-------|---------------|
| 2.5 | gemini-2.5-pro |
| 2.5-pro | gemini-2.5-pro |
| 3 | gemini-3-pro-preview |
| 3-pro | gemini-3-pro-preview |
</alias-mapping>

<valid-models>
- gemini-2.5-pro
- gemini-3-pro-preview
</valid-models>

<preview-models>
- gemini-3-pro-preview
</preview-models>
</model-configuration>

<input-handling>
<option-parsing>
Parse command arguments in this order:
1. Extract -m or --model flag and its value (if present)
2. Extract --no-review flag (if present)
3. Remaining argument is the identifier

Examples:
- `/do-by-gemini user-auth` → model=default, review=true, identifier=user-auth
- `/do-by-gemini -m 3-pro user-auth` → model=3-pro, review=true, identifier=user-auth
- `/do-by-gemini --no-review user-auth` → model=default, review=false, identifier=user-auth
- `/do-by-gemini -m 3-pro --no-review feature:auth` → model=3-pro, review=false, identifier=feature:auth
</option-parsing>

<model-resolution>
1. If no -m/--model flag provided, use default model (gemini-2.5-pro)
2. If alias provided (e.g., "3-pro"), resolve to full model ID using alias-mapping
3. If full model ID provided, validate against valid-models list
4. If invalid model, show error-invalid-model
5. If preview model, show preview warning
</model-resolution>

<resolution-logic>
The `/do-by-gemini` command automatically resolves the plan type:

1. plans/features/{{IDENTIFIER}}.md exists → Execute new feature
2. plans/fixes/{{IDENTIFIER}}.md exists → Execute bug fix
3. plans/refactors/{{IDENTIFIER}}.md exists → Execute refactoring
4. plans/changes/{{IDENTIFIER}}.md exists → Execute change
5. Multiple exist → Error + require explicit prefix
6. None exist → Error + show guidance
</resolution-logic>

<explicit-prefix>
/do-by-gemini feature:{{IDENTIFIER}}   → docs/plans/features/{{IDENTIFIER}}.md
/do-by-gemini fix:{{IDENTIFIER}}       → docs/plans/fixes/{{IDENTIFIER}}.md
/do-by-gemini refactor:{{IDENTIFIER}}  → docs/plans/refactors/{{IDENTIFIER}}.md
/do-by-gemini change:{{IDENTIFIER}}    → docs/plans/changes/{{IDENTIFIER}}.md
</explicit-prefix>

<error-gemini-not-found>
❌ Error: gemini-cli not found

Please install gemini-cli first:
  npm install -g @google/gemini-cli

Or verify it's in your PATH:
  which gemini

For more information:
  https://github.com/google/gemini-cli
</error-gemini-not-found>

<error-no-plan>
❌ Error: No plan found for '{{IDENTIFIER}}'

📋 To create a plan:

  New Feature:
    /research {{IDENTIFIER}}  → Start with research
    /spec {{IDENTIFIER}}      → Create specification (if research exists)
    /plan {{IDENTIFIER}}      → Create implementation plan (if spec exists)

  Maintenance:
    /debug {{IDENTIFIER}}      → Analyze and plan bug fix
    /refactor {{IDENTIFIER}}   → Analyze and plan refactoring
    /change {{IDENTIFIER}}     → Analyze and plan behavior change

💡 Tip: Check existing documents with: ls docs/plans/
</error-no-plan>

<error-multiple-plans>
❌ Error: Multiple plans found for '{{IDENTIFIER}}':
   - docs/plans/features/{{IDENTIFIER}}.md
   - docs/plans/changes/{{IDENTIFIER}}.md

Please specify flow:
  /do-by-gemini feature:{{IDENTIFIER}}
  /do-by-gemini change:{{IDENTIFIER}}
</error-multiple-plans>

<error-empty-plan>
❌ Error: Plan document is empty: {{PATH}}

The plan file exists but contains no content. Please verify the plan was created correctly.
</error-empty-plan>

<error-read-failure>
❌ Error: Could not read plan file: {{PATH}}

Please check:
  - File exists and is readable
  - Path is correct
  - No permission issues
</error-read-failure>

<error-gemini-execution>
❌ Gemini Execution Error

Exit code: {{EXIT_CODE}}
Error output: {{ERROR_MESSAGE}}

Possible causes:
  - Gemini API authentication issue
  - Rate limit exceeded
  - Network connectivity problem
  - Invalid prompt format

Suggested actions:
  1. Check `gemini auth status`
  2. Retry after a moment
  3. Use `/do` to execute with Claude instead
</error-gemini-execution>

<error-pattern-detection>
After execution failure, analyze the log file for known error patterns:

1. ByteString conversion error:
   Pattern: "Cannot convert argument to a ByteString"
   Cause: API key contains invisible Unicode characters
   Action: Display error-api-key-unicode

2. Authentication error (401):
   Pattern: "401" or "Unauthorized" or "authentication"
   Cause: Invalid or expired API key
   Action: Display error-auth-failed

3. Rate limit error (429):
   Pattern: "429" or "rate limit" or "quota"
   Cause: API rate limit exceeded
   Action: Display error-rate-limit

4. Network error:
   Pattern: "ENOTFOUND" or "ETIMEDOUT" or "network" or "connection"
   Cause: Network connectivity issue
   Action: Display error-network

5. Sandbox restriction:
   Pattern: "sandbox" or "permission denied" or "not allowed"
   Cause: Sandbox mode blocking file operations
   Action: Display error-sandbox-restriction
</error-pattern-detection>

<error-auth-failed>
❌ Authentication Failed (HTTP 401)

Your API key was rejected by the Gemini API.

Possible causes:
  - API key is invalid or revoked
  - API key has expired
  - API key is for a different project/service

Suggested actions:
  1. Verify your API key is active:
     https://aistudio.google.com/apikey

  2. Check gemini-cli auth status:
     gemini auth status

  3. Re-authenticate if needed:
     gemini auth login
</error-auth-failed>

<error-rate-limit>
⏳ Rate Limit Exceeded (HTTP 429)

You have exceeded the Gemini API rate limit.

Current status:
  - Requests are being throttled
  - Partial output saved to: {log_path}

Suggested actions:
  1. Wait a few minutes before retrying
  2. Check your API quota at:
     https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas

  3. Consider using a different model with higher quota
  4. Use `/do` to execute with Claude instead
</error-rate-limit>

<error-network>
🌐 Network Connection Error

Failed to connect to the Gemini API.

Possible causes:
  - No internet connection
  - Firewall blocking the request
  - Gemini API service outage

Suggested actions:
  1. Check your internet connection
  2. Verify you can reach Google services:
     curl -I https://generativelanguage.googleapis.com

  3. Check Gemini API status:
     https://status.cloud.google.com/

  4. Retry after network issue is resolved
</error-network>

<error-sandbox-restriction>
🔒 Sandbox Restriction

The sandbox environment prevented file operations.

Gemini tried to modify files but was blocked by sandbox restrictions.

Details from log: {log_path}

Suggested actions:
  1. Verify sandbox settings in gemini-cli
  2. If file operations are required, consider:
     - Adjusting sandbox permissions
     - Running in a trusted environment

  3. Use `/do` to execute with Claude instead (different sandbox model)
</error-sandbox-restriction>


<error-timeout>
⏱️ Execution timed out

The Gemini execution exceeded the timeout limit.
The task may still be running in the background.

Partial Results:
  - Output log saved: {log_path}
  - Log contains {line_count} lines of output

To view partial output:
  cat {log_path}
  less {log_path}

Suggested actions:
  1. Check if files were partially modified:
     git status
     git diff

  2. Review partial log for progress:
     tail -100 {log_path}

  3. Consider breaking the plan into smaller phases

Would you like to review partial changes?
  [Y] Yes - Run review on current state
  [N] No - Abort without review
  [R] Resume - Try to continue execution

If partial changes exist, the review phase will analyze whatever was completed.
</error-timeout>

<error-invalid-model>
❌ Unknown model: '{model}'

Available models:
  - gemini-2.5-pro (default)
  - gemini-3-pro-preview

Aliases:
  - 2.5, 2.5-pro → gemini-2.5-pro
  - 3, 3-pro → gemini-3-pro-preview

Example:
  /do-by-gemini -m 3-pro {identifier}
</error-invalid-model>

<error-model-unavailable>
⚠️ Model '{model}' is currently unavailable

The selected model could not be accessed. This may be due to:
  - API quota limits
  - Model deprecation
  - Temporary service issues

Would you like to use the default model (gemini-2.5-pro) instead? [Y/n]
</error-model-unavailable>

<warning-preview-model>
⚠️ Using preview model: {model}

This is a preview/experimental model. Results may be:
  - Less stable than production models
  - Subject to change without notice
  - Not recommended for production code

Proceeding with execution...
</warning-preview-model>

<error-max-cycles>
🔄 Maximum improvement cycles (3) reached

The automatic improvement process has completed 3 cycles but issues remain.

Remaining issues:
{remaining_issues}

Suggested actions:
  1. Review the remaining issues manually
  2. Make targeted fixes to the specific problems
  3. Run /review {identifier} after manual changes

Changes from improvement cycles have been applied.
</error-max-cycles>

<error-not-git-repo>
⚠️ Not a git repository

Cannot generate diff-based review because this directory is not a git repository.

Review will be limited to:
  - Output log analysis
  - Plan compliance check

For full review capabilities, initialize git:
  git init
  git add .
  git commit -m "Initial commit"
</error-not-git-repo>

<error-output-truncated>
📊 Output truncated due to size

The Gemini output exceeded display limits.

Full output saved to: {log_path}

To view the complete output:
  cat {log_path}
  less {log_path}

Review will use the full log file for analysis.
</error-output-truncated>

<error-api-key-missing>
❌ Error: GEMINI_API_KEY is not set

The GEMINI_API_KEY environment variable is required for gemini-cli.

To set up your API key:
  1. Visit https://aistudio.google.com/apikey to generate a key
  2. Export the key in your shell:
     export GEMINI_API_KEY="your-api-key-here"
  3. (Optional) Add to your shell profile for persistence

For more information:
  https://github.com/google-gemini/gemini-cli#setup
</error-api-key-missing>

<error-api-key-invalid-prefix>
❌ Error: Invalid API key format

The GEMINI_API_KEY does not appear to be a valid Gemini API key.
Expected format: API key should start with 'AIza'

Current key prefix: {key_prefix}...

Suggested actions:
  1. Verify you copied the correct API key
  2. Check that you're using a Gemini API key (not another Google service)
  3. Regenerate the key at https://aistudio.google.com/apikey
</error-api-key-invalid-prefix>

<error-api-key-unicode>
❌ Error: API key contains invisible Unicode characters

Your GEMINI_API_KEY contains hidden characters (likely from copy-paste).
This can cause "Cannot convert argument to a ByteString" errors.

Detected issue: Unicode control characters found in the key

To fix this:
  1. Delete the current key from your environment:
     unset GEMINI_API_KEY

  2. Go to https://aistudio.google.com/apikey

  3. Click "Copy" button directly (don't manually select the text)

  4. Re-export the key, typing the quotes manually:
     export GEMINI_API_KEY='paste-here'

  5. Verify the key is clean:
     printenv GEMINI_API_KEY | xxd | head

     (Should show only printable ASCII characters, no 'e280' sequences)
</error-api-key-unicode>
</input-handling>

<process>
<step n="1" name="Parse Options and Check Prerequisites">
1. Parse command options:
   - Extract -m/--model flag value (if provided)
   - Extract --no-review flag (if present)
   - Extract identifier (remaining argument)

2. Resolve model:
   - If model specified, resolve alias to full model ID
   - If model invalid, display error-invalid-model and STOP
   - If preview model, display preview warning

3. Validate GEMINI_API_KEY:
   Execute the following validation checks in order:

   a. Check if GEMINI_API_KEY exists:
      ```bash
      if [[ -z "${GEMINI_API_KEY:-}" ]]; then
          # Display error-api-key-missing and STOP
      fi
      ```

   b. Check if key starts with 'AIza':
      ```bash
      if [[ ! "${GEMINI_API_KEY}" =~ ^AIza ]]; then
          # Display error-api-key-invalid-prefix with key_prefix=${GEMINI_API_KEY:0:8}
          # STOP execution
      fi
      ```

   c. Check for invisible Unicode characters (e.g., e280 sequences):
      ```bash
      if printenv GEMINI_API_KEY | xxd | grep -q 'e280'; then
          # Display error-api-key-unicode and STOP
      fi
      ```

   If all validations pass, proceed to step 4.

4. Verify gemini-cli is available:
   - Run: `which gemini` or `command -v gemini`
   - If not found, display error-gemini-not-found message
   - STOP execution if gemini-cli is not available

5. Parse the identifier:
   - Check for prefix notation (feature:, fix:, refactor:, change:)
   - Extract base identifier
</step>

<step n="2" name="Resolve Plan Location">
1. If prefix is provided:
   - Use explicit path: docs/plans/{type}/{identifier}.md

2. If no prefix:
   - Check all plan directories:
     - docs/plans/features/{identifier}.md
     - docs/plans/fixes/{identifier}.md
     - docs/plans/refactors/{identifier}.md
     - docs/plans/changes/{identifier}.md
   - Count matching files
   - If 0 matches → Show error-no-plan
   - If 1 match → Use that path
   - If multiple → Show error-multiple-plans
</step>

<step n="3" name="Read Documents">
1. Read the plan document:
   - If read fails → Show error-read-failure
   - If empty → Show error-empty-plan

2. Extract source document path from plan:
   - Look for "Source Document:" or "References:" section
   - Read the source document (spec or analysis)
   - Source document is optional but recommended
</step>

<step n="4" name="Construct Gemini Prompt">
Build the prompt using this template:

```
You are an expert developer executing an implementation plan.

## Plan Document
{plan_content}

## Source Document (Reference)
{source_document_content}

## Instructions
1. Follow the plan step by step - do NOT skip or reorder
2. Write actual source code to specified files
3. Run verification checks after each phase
4. Do NOT add features not in the source document
5. Write tests alongside implementation

## Constraints
- Follow project coding conventions
- Include appropriate error handling
- No linting or type errors allowed
- Cover code with tests as specified

Execute this plan now.
```
</step>

<step n="5" name="Execute with File-based Prompt">
Use file-based prompt passing to avoid encoding issues with multi-byte characters
and shell escaping problems.

1. Generate timestamp for log file:
   ```bash
   timestamp=$(date +%Y%m%d-%H%M%S)
   log_path="/tmp/gemini-output-${timestamp}.log"
   prompt_file=$(mktemp)
   ```

2. Write prompt to temporary file:
   ```bash
   # Write the constructed prompt to temp file (safe for multi-byte characters)
   printf '%s' "${constructed_prompt}" > "$prompt_file"
   ```

3. Display start message using start-format

4. Execute with stdin input and streaming output:
   ```bash
   # If model is not default:
   cat "$prompt_file" | gemini -m {resolved_model} -y 2>&1 | tee "$log_path"
   exit_code=${PIPESTATUS[1]}

   # If using default model:
   cat "$prompt_file" | gemini -y 2>&1 | tee "$log_path"
   exit_code=${PIPESTATUS[1]}
   ```

   Note: Use PIPESTATUS[1] to capture gemini's exit code (not cat or tee).

5. Cleanup temporary file:
   ```bash
   rm -f "$prompt_file"
   ```

6. Evaluate execution result:
   If exit_code == 0:
     ✅ Gemini execution complete
   If exit_code != 0:
     - Check log for error patterns (see Step 6)
     - Display error-gemini-execution with details
   If interrupted (SIGINT):
     - Display interruption-message with partial changes info
</step>

<step n="6" name="Report Execution Results">
Based on execution result:

If successful (exit code 0):
   ✅ Gemini execution complete
   Proceed to Step 7 (Review Phase) unless --no-review flag is set

If failed:
   - Display error-gemini-execution with details
   - Suggest fallback to /do command
   - Skip review phase

If interrupted:
   - Display interruption-message
   - Offer to continue with review on partial changes
</step>

<step n="7" name="Review Phase">
Skip this step if:
- --no-review flag was provided
- Execution failed completely
- User declined review after interruption

1. Gather review context:
   - Read the output log file: {log_path}
   - Get git diff for changed files: `git diff --name-only`
   - Read the original plan document for comparison

2. Analyze changes:
   - Compare implementation against plan requirements
   - Check for security issues
   - Verify error handling
   - Check code style consistency
   - Assess test coverage

3. Display review results using review-format

4. Present user choices:
   [A] Accept - Accept changes as-is
   [I] Improve - Apply suggested improvements automatically
   [M] Manual - Stop for manual review/fixes
   [D] Details - Show detailed breakdown of each issue

5. Handle user choice:
   - Accept: Complete workflow, display final summary
   - Improve: Proceed to Step 8 (Improvement Cycle)
   - Manual: Display manual review guidance, complete workflow
   - Details: Show detailed review items, return to choice prompt
</step>

<step n="8" name="Improvement Cycle">
Track improvement cycles (max 3):

1. Increment cycle counter
2. If cycle > 3, display error-max-cycles and force accept
3. Apply suggested fixes to the code
4. Display improvement progress using improvement-format
5. Re-run analysis (return to Step 7, step 2)
6. Display updated review results
7. Present user choices again
</step>

<step n="9" name="Final Summary">
Display complete workflow summary:
- Execution result
- Review results (if performed)
- Improvement cycles applied (if any)
- Files created/modified
- Next steps
</step>
</process>

<rules>
<gemini-specific>
Required behaviors:
- Always use -y flag (YOLO mode) for non-interactive execution
- Always use -p flag for direct prompt input
- Capture and report full output from gemini-cli
- Clearly indicate Gemini is the executor, not Claude
</gemini-specific>

<prompt-construction>
The prompt sent to Gemini must:
- Include the complete plan document content
- Include the source document content (if available)
- Provide clear execution instructions
- Specify constraints matching /do command standards
</prompt-construction>

<output-attribution>
All output must clearly indicate:
- Execution was performed by Gemini
- Include "🤖 Executed by: gemini-cli" in reports
- Differentiate from Claude Code execution
</output-attribution>

<timeout-handling>
- Default timeout: 10 minutes (600000ms)
- If execution times out, inform user
- Suggest checking for partial results
</timeout-handling>
</rules>

<output>
<start-format>
┌──────────────────────────────────────────────────────────────────┐
│ 🚀 Starting Gemini Execution                                     │
│ 📄 Plan: docs/plans/{type}/{identifier}.md                       │
│ 📋 Type: {Feature | Fix | Refactor | Change}                     │
│ 🤖 Executor: gemini-cli (YOLO mode)                              │
│ 🧠 Model: {resolved_model}                                       │
│ 📝 Log: {log_path}                                               │
└──────────────────────────────────────────────────────────────────┘
</start-format>

<streaming-prefix>
Output from Gemini is displayed in real-time with [Gemini] prefix when needed for clarity.
</streaming-prefix>

<interruption-message>
⏹️ Execution interrupted by user (Ctrl+C)

Partial execution status:
- Files modified: {count}
- Last action: {last_action}
- Log saved to: {log_path}

You can still run review on partial changes: The review phase will analyze whatever changes were made.
</interruption-message>

<progress-format>
During execution, gemini-cli output will be displayed directly.
</progress-format>

<review-format>
┌──────────────────────────────────────────────────────────────────┐
│ 🔍 Claude Code Review                                            │
│                                                                  │
│ Analyzing changes made by Gemini...                              │
│                                                                  │
│ ✅ Pass: {pass_count} items                                      │
│ ⚠️ Warnings: {warning_count} items                               │
{warning_list}
│ ❌ Issues: {issue_count} items                                   │
{issue_list}
│                                                                  │
│ [A] Accept as-is  [I] Improve  [M] Manual fix  [D] Details       │
└──────────────────────────────────────────────────────────────────┘

Where:
- warning_list: Each warning on a separate line with format "│   - {message}"
- issue_list: Each issue on a separate line with format "│   - {category}: {message}"
</review-format>

<improvement-format>
┌──────────────────────────────────────────────────────────────────┐
│ 🔧 Applying Improvements (Cycle {cycle_number}/3)                │
│                                                                  │
{improvement_items}
│                                                                  │
│ Re-running review...                                             │
└──────────────────────────────────────────────────────────────────┘

Where:
- improvement_items: Each improvement with format:
  - "│ ✓ {completed_fix}" for applied fixes
  - "│ → {current_fix}..." for fix in progress
</improvement-format>

<no-review-skip-message>
⏭️ Skipping automatic review (--no-review flag)

To review changes later, run:
  /review {identifier}

Or manually inspect:
  git diff
  git status
</no-review-skip-message>

<final-format>
After all phases complete:

✅ Execution Complete: {{IDENTIFIER}}

Summary:
- 🤖 Executor: gemini-cli
- 🧠 Model: {resolved_model}
- 📋 Plan type: {Feature | Fix | Refactor | Change}
- 📄 Files created: {created_count}
- ✏️ Files modified: {modified_count}
- 📝 Output log: {log_path}

Review Summary: (if review was performed)
- ✅ Pass: {pass_count}
- ⚠️ Warnings: {warning_count}
- ❌ Issues: {issue_count}
- 🔄 Improvement cycles: {cycle_count}/3

Next steps:
1. Run tests to verify implementation
2. Check for any incomplete tasks
3. Commit changes if satisfied
4. Consider additional code review

---
⚠️ Note: This implementation was generated by Gemini, not Claude.
   Please review all changes before committing.
</final-format>
</output>
