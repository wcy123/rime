ifneq (,$(findstring C:, $(SystemRoot)))
  SEP := ";"
  CHEZ := scheme
else
  SEP := ":"
  CHEZ := $(shell which scheme || which chez || which chezscheme)
endif

RUN_CHEZ := "$(CHEZ)" --compile-imported-libraries --libdirs .$(SEP)$(SEP)build/chezscheme --program
RUN_GUILE := guile --r6rs -L .
SHELL := /bin/bash

TEST_CASES := $(patsubst test/%.sls, %, \
	    $(wildcard test/*-test.sls \
	               test/*/*-test.sls \
	               test/*/*/*-test.sls \
	               test/*/*/*/*-test.sls ))


all:
	@echo small libs in scheme, r6rs compatible.

.PHONY: test test-standalone

test: test-chez test-guile test-standalone
	@echo; echo "MAKE: TEST FINISH $(TEST_CASES)"

# Standalone script tests - catch bugs that unit tests miss
STANDALONE_TESTS := $(wildcard test/standalone/*.scm)
test-standalone:
	@echo "[ test-standalone ] Running standalone script tests"
	@for script in $(STANDALONE_TESTS); do \
		echo "  Running $$script..."; \
		"$(CHEZ)" --script $$script || exit 1; \
	done
	@echo "[ test-standalone ] All standalone tests passed"


define test_rule

.PHONY: test-$(2)/$(1)
test-$(2)/$(1):
	@echo "[ " test-$(2)/$(1)  " ] started " && $(3) test $(subst /, ,$(1))

test-$2: test-$(2)/$(1)

endef


$(foreach i,$(TEST_CASES),$(eval $(call test_rule,$(i),chez,$(RUN_CHEZ) bin/test.scm)))
test-chez:
	echo "ALL TEST with CHEZ OK"

$(foreach i,$(TEST_CASES),$(eval $(call test_rule,$(i),guile,$(RUN_GUILE) bin/test.scm)))
test-guile:
	echo "ALL TEST with GUILE OK"


deps:
	$(RUN_CHEZ) bin/dep.scm `find rime -iname '*.sls'`

test-cases:
	@echo "TEST CASES: "; for i in $(TEST_CASES); do \
     echo -n  "     test-guile/"$$i;  \
     echo  "     test-chez/"$$i;  \
     done
