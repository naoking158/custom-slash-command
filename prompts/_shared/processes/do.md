# Process: Implementation

## Step 1: Verify Prerequisites
- Confirm the plan document exists
- Read the plan and source document (spec/analysis)
- Check that all dependencies are available
- Ensure development environment is ready

## Step 2: Execute Phase by Phase
Follow the plan's phases in order:

For each step:
1. Read the step requirements from the plan
2. Reference the source document for behavioral details
3. Write the code following project conventions
4. Run the verification checks defined in the plan
5. Proceed to next step only when verification passes

## Step 3: Quality Checks
After completing each phase:
- Run linting/formatting
- Run type checking (if applicable)
- Run relevant tests
- Verify no regressions

## Step 4: Final Verification
After all phases complete:
- Run full test suite
- Verify all acceptance criteria from source document
- Check for any TODO comments left behind
- Ensure documentation is updated
