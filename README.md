# 🎯 Push_Swap Test Suite — Ultimate Tester (WOW Edition)

[![Test Status](https://img.shields.io/badge/tests-ready-brightgreen.svg)](https://github.com/)
[![Valgrind](https://img.shields.io/badge/valgrind-checked-blue.svg)](https://valgrind.org/)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

Welcome to the dazzling, battle-tested Push_Swap Test Suite — a polished, automated test runner for your `push_swap` and `checker` projects. This README shows you how to run rocket-fast correctness checks, stress tests, and valgrind leak checks — all with clear PASS/FAIL output and helpful debugging hints. Prepare for results that go from "meh" to "wow". 🚀

---

## Why this is awesome

- ✅ Covers correctness: already-sorted, edge cases, parsing, duplicates, overflows
- ✅ Validates both standard and bonus checker behavior
- ✅ Stress tests with 10 / 100 / 500 inputs
- ✅ Memory leak detection with `valgrind` (full leak-check)
- ✅ Clear, human-friendly symbols: [OK], [KO], [NO LEAK ✅], [LEAK ❌]
- ✅ Easy to configure — point to your executables or keep them in PATH
- ✅ Designed for local dev and CI pipelines

---

## Table of contents

- Quick start
- Configuration
- What this script tests
- Examples & sample outputs
- CI integration (GitHub Actions)
- Troubleshooting & tips
- Contributing

---

## Quick start (3 steps)

```bash
git clone git@github.com:hicham-bnh/push_swap_tester.git
```

1. Make sure your programs are compiled:
   - `push_swap` (the generator of operations)
   - `checker` (or optional `checker_bonus`)
   - `checker_linux`

2. Make the test script executable:
```bash
chmod +x test_push_swap.sh
chmod +x checker_linux
```

3. Run the full test suite:
```bash
./test_push_swap.sh
```

That's it. Expect a colorful, structured report summarizing all test categories and leak checks.

---

## Configuration

At the top of the script you can define the paths used for testing. Example:

```bash
# Edit the top of test_push_swap.sh to change these if necessary
PUSH_SWAP="./push_swap"         # path to push_swap binary
CHECKER="./checker"             # path to checker binary
CHECKER_BONUS="./checker_bonus" # optional bonus checker
VALGRIND="valgrind --leak-check=full --show-leak-kinds=all"
```

If your executables are already on your PATH, you can set these to just `push_swap` and `checker`. You can also copy the script into the same folder as your binaries for convenience.

To test only a specific section: either comment out the other sections inside the script, or create a small wrapper that only invokes the functions you want (e.g., `./test_push_swap.sh --sorted` if you add flag handling).

---

## What the script tests (summary)

- Already sorted stacks (single and multi-element)
- Strict error handling: duplicates, non-numeric input, integer overflows
- Input parsing / edge cases (empty input, extra spaces, newline termination)
- Correct sorting for small (3), medium (5–20) and larger sets
- Adaptive sorting: verifies number of operations where applicable
- Stress tests: deterministic random sets for 10, 100, and 500 elements
- Memory leak detection via valgrind for both `checker` and `push_swap` workflows
- Bonus: verifies that every operation produced by `push_swap` is accepted by `checker` (if bonus checker implemented)

---

## Expected output (beautiful & explicit)

The script prints section headers and line-by-line results. Example sample:

```text
=== ALREADY SORTED STACKS ===
[OK] Stack already sorted (0 ops)
[OK] Stack already sorted --simple (0 ops)

=== PARSING & ERRORS ===
[OK] Rejects duplicate values
[OK] Rejects non-numeric input
[OK] Rejects integer overflow

=== SORTING TESTS ===
[OK] 3 numbers -> 2 ops (valid)
[OK] 5 numbers -> 8 ops (valid)
[KO] 100 numbers -> produced invalid result
     Received: KO
     Expected: OK
     push_swap output: <ops...>

=== STRESS TESTS ===
✓ 10 numbers → OK
✓ 100 numbers → OK
✓ 500 numbers → OK

=== MEMORY LEAKS ===
[NO LEAK ✅] checker '2 1'
[NO LEAK ✅] push_swap 'random_100'
[LEAK ❌] push_swap 'edge_case_overflow'
```

At the end you see a synthesized result, e.g., `ALL TESTS PASSED 🎉` or a concise failure summary.

---

## Manual test examples

Run individual checks manually to debug:

```bash
# Simple check of a single operation sequence
RES=$(printf "sa\n" | ./checker 2 1 3)
echo "Result: $RES"  # -> OK

# Sequence with pb and sb
RES=$(printf "pb\nsb\n" | ./checker 1 3 2)
echo "Result: $RES"  # -> KO
```

Tip: use `printf` (not `echo`) to ensure each instruction ends with a newline — checkers expect newline-terminated commands.



---

## Troubleshooting & tips

- "command not found": ensure `PUSH_SWAP`/`CHECKER` paths are correct and that the files are executable.
- Valgrind false positives: check suppression files or re-run local with `--leak-check=full --show-leak-kinds=all` to get precise info.
- Empty input: tests consider empty input and already-sorted stacks as OK.
- Output mismatch: capture both `push_swap` produced operations and `checker` response to see where behavior diverges.

Debugging flow:
1. Reproduce failing test input manually.
2. Run `./push_swap <args> | tee ops.txt` to capture operations.
3. Validate `printf "$(cat ops.txt)\n" | ./checker <numbers>` to see checker response.
4. Run valgrind around the failing program for leaks.

---

## Make it yours

- Add a `--filter` option to run only named test categories.
- Add a `--ci` mode to reduce test size and produce machine-readable JSON results.
- Add a results badge via a small server or GitHub Action artifact to display pass/fail on README.

---

## Contributing

Love this README? Great — contributions welcome. Please open issues or PRs with:
- New test cases
- Edge-case proposals
- CI improvements and performance tuning

---

## License

MIT — do whatever you like, just keep attribution 🙂.

---

Thanks for using the Push_Swap Test Suite — now go break it, fix it, and show off the glorious green [OK]s. Want me to also add a one-click GitHub Action file or a pretty badge that shows live test status? I can generate it for you. ✨