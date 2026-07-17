#!/usr/bin/env bash
# DEFECT: empty-suite masked green by --passWithNoTests. This stub stands in for
# `jest --passWithNoTests` run over a suite that collects ZERO tests. jest prints a
# GREEN "Test Suites: 1 passed" line (the seductive false signal a loose "N passed"
# match would read as covered) while "Tests: 0 total" shows nothing actually ran, and
# it exits 0 because the flag masks the empty run. The behavioral gate must refuse
# this (unverifiable-suite) and never let the suite-count line pass as coverage.
echo "PASS  no-op placeholder"
echo "Test Suites: 1 passed, 1 total"
echo "Tests:       0 total"
echo "Snapshots:   0 total"
echo "Ran all test suites."
exit 0
