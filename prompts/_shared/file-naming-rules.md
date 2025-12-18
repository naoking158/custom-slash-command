# File Naming Rules

<file-naming>
<rules>
1. Extract identifier from input (remove date prefix if present)
2. Convert to kebab-case (lowercase, hyphens)
3. Prepend today's date as YYYYMMDD
4. Result: `{{DATE}}-{{IDENTIFIER}}.md`
</rules>

<examples>
<example>
<input>ユーザー認証機能を追加</input>
<identifier>user-auth</identifier>
<filename>20241218-user-auth.md</filename>
</example>

<example>
<input>Add payment processing</input>
<identifier>payment-processing</identifier>
<filename>20241218-payment-processing.md</filename>
</example>

<example>
<input>20241215-api-refactor</input>
<identifier>api-refactor</identifier>
<filename>20241218-api-refactor.md</filename>
</example>

<example>
<input>fix login button not working</input>
<identifier>login-button-fix</identifier>
<filename>20241218-login-button-fix.md</filename>
</example>

<example>
<input>PaymentProcessor</input>
<identifier>payment-processor</identifier>
<filename>20241218-payment-processor.md</filename>
</example>
</examples>

<normalization>
1. Lowercase all characters
2. Replace spaces, slashes, underscores with hyphens
3. Convert camelCase to kebab-case
4. Collapse multiple hyphens to single hyphen
5. Remove leading/trailing hyphens
</normalization>
</file-naming>
