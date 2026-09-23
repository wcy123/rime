# Claude Instructions for Rime Project

## Bug Fix Workflow

When you find a problem in the code:

1. **Create a branch**
   ```bash
   git checkout -b fix-<problem-description>
   ```

2. **Create a unit test to reproduce the bug**
   - Add test in `test/rime/loop/<feature>-test.sls`
   - Test should FAIL initially (reproducing the bug)
   - Verify the test fails before fixing

3. **Fix the bug**
   - Make minimal changes to fix the issue
   - Explain root cause before applying fix
   - Update documentation if behavior changes

4. **Create a pull request**
   - Write clear commit message with "Co-Authored-By: Claude <noreply@anthropic.com>"
   - Push branch and create PR
   - Include: what was broken, root cause, how fixed

5. **Fix any CI errors**
   - All three platforms must pass: Ubuntu, macOS, Windows
   - Check logs if CI fails
   - Fix and push until all CI passes

## Documentation Verification

**CRITICAL**: Always ensure all examples in `doc/loop.md` work in the real world.

- Every code example must be tested with actual Chez Scheme execution
- Include actual output in comments (not guessed output)
- If you update functionality, update ALL affected examples
- Run verification script to test all examples

## Adding New Keywords

When adding a new keyword (e.g., `:step`):

1. **Add to exports** in `rime/loop/keywords.sls`:
   ```scheme
   (export ... :step ...)
   ```

2. **Add to exports** in `rime/loop.sls`:
   ```scheme
   (export loop ... :step ...)
   ```

3. **Define the keyword** in `rime/loop/keywords.sls`:
   ```scheme
   (define-keyword :step)
   ```

4. **Add to keyword? predicate list** in `rime/loop/keywords.sls`:
   ```scheme
   (define (keyword? e)
     (exists (lambda (keyword) ...)
       (list ... (syntax :step) ...)))
   ```

5. **Implement in plugin** (e.g., `rime/loop/count.sls`):
   ```scheme
   (syntax-case e (:count ... :step ...))
   ```

6. **Test thoroughly**:
   - Unit tests in `test/rime/loop/<feature>-test.sls`
   - Standalone script test
   - Documentation examples

## Project Structure

- `rime/loop/` - Loop macro implementation
  - `core.sls` - Parser and code generator
  - `keywords.sls` - Keyword definitions
  - `<feature>.sls` - Individual feature plugins (count, collect, etc.)
- `test/rime/loop/` - Test files for each feature
- `doc/loop.md` - User documentation with examples

## Testing

**IMPORTANT**: Test framework compilation may cache results, hiding keyword registration bugs.
Always verify fixes work with multiple methods:

1. **Unit tests**: `make test-chez/rime/loop/<feature>-test`
   - May pass even with missing keywords due to caching
   - Delete `build/` to force recompilation

2. **Full test suite**: `make test-chez`
   - Comprehensive but still subject to caching

3. **Standalone script test** (CRITICAL for keywords):
   ```bash
   cat > /tmp/test-<feature>.scm << 'EOF'
   #!r6rs
   (import (rnrs (6)) (rime loop))
   (write (loop :for i :from 1 :to 5 :count :step 2))
   EOF
   scheme --script /tmp/test-<feature>.scm
   ```
   - This will ALWAYS fail if keyword not registered
   - Most reliable test for keyword issues

4. **Documentation examples**: Run `test-doc-examples.scm`
   - Verifies all examples work in real world

Tests must be comprehensive and cover:
- Basic usage
- Edge cases
- Combined features
- Error conditions

## Code Style

- Use evidence-based approach - verify everything
- Ask for approval before applying fixes
- Keep changes minimal and focused
- Document WHY, not just WHAT
- Include real examples with verified output
