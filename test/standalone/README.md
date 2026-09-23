# Standalone Script Tests

These tests run as standalone Scheme scripts to catch bugs that the regular
test suite misses due to compilation/caching behavior.

## Why These Tests Exist

The regular test suite (`make test-chez`) compiles all code together in one
session. Chez Scheme's macro expander can sometimes succeed even with missing
keyword registrations during batch compilation, but fail when loading libraries
fresh in a standalone script.

**Keyword registration bugs** are a prime example - they're NOT caught by unit
tests but ARE caught by standalone scripts.

## Running These Tests

```bash
make test-standalone
```

This runs all `.scm` files in this directory as standalone scripts and verifies
they exit with status 0.

## When to Add Tests Here

Add a standalone test when:
1. Testing keyword registration (`:step`, `:by`, etc.)
2. Testing library exports and visibility
3. Testing fresh-load behavior that differs from batch compilation
4. Any bug that unit tests don't reproduce but standalone scripts do
