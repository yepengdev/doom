---
name: refactor-code
description: |
  Use when the user asks to refactor, restructure, clean up, improve, modernize, deduplicate,
  simplify, or pay down technical debt in existing code. Also when they say "rewrite this but
  keep the same behavior", "extract", "rename", "move", "inline", "split", "consolidate", or
  "decouple". Do NOT trigger for adding new features, fixing bugs, or writing tests — only
  structural improvements that preserve observable behavior.
---

# Refactoring Code

## Core Principle

**Refactoring changes structure, not behavior.** Every refactoring step must
preserve what the code does. If you are also fixing a bug or adding a feature,
do that as a separate step (ideally a separate commit/PR) and call it out to
the user explicitly.

## Workflow

### 1. Understand before touching

- Read the full file(s) involved. Understand the inputs, outputs, side effects,
  and callers before moving anything.
- Search for all call sites (`grep` for exported names, imports, references).
  A refactored name or signature must be updated everywhere it is used.
- Run the test suite / build / linter **before** starting so you know the
  starting baseline is green (`npm test`, `npm run lint`, `tsc --noEmit`, etc.).

### 2. Plan the refactoring

Outline the smallest possible steps. Present the plan to the user for approval
if the refactoring spans multiple files or is risky.

Example plan:
1. Extract `computeDiscount` from `OrderSummary.tsx` into `lib/pricing.ts`
2. Inline the duplicated `formatCurrency` calls
3. Remove the `any` cast in `PaymentForm.tsx` by refining the type
4. Run tests and lint — confirm green

### 3. One refactoring at a time

Make exactly one structural change per step. Between each step:

- Keep the code **compiling** at every step (or as close as possible).
- Run the relevant toolchain after each step:
  `npx tsc --noEmit && npm run lint` (or the equivalents for the stack).
- If a step would leave the code broken, split it further or use a temporary
  adapter/transition type.

### 4. Verify behavior preservation

- Tests must pass **before and after** each step.
- If test coverage is thin for the area being refactored, tell the user: "I
  suggest adding characterization tests before refactoring this module."
- Do NOT add tests as part of a refactoring step unless explicitly asked.
  Refactoring and test-writing are separate concerns.

### 5. Use the type system as a safety net

- Before removing or changing a public API, trace every call site.
- When renaming a symbol, prefer the IDE-safe rename (or `sed` across known
  files) but verify with `tsc --noEmit` afterward.
- Add stricter types as part of a refactoring (`any` → `unknown` → concrete)
  but do so incrementally — one type at a time.

## Common Refactoring Patterns

| Pattern | What to do |
|---|---|
| **Extract function/method** | Pull a block into a named function with explicit parameters and return type. Update all callers. |
| **Rename symbol** | Rename the declaration + every reference. Use the type checker to confirm. |
| **Move file** | Update imports in the moved file AND every file that imports it. Check for relative path changes. |
| **Inline variable/function** | Replace a trivial variable or delegation with the expression directly, then remove the original. |
| **Split module** | Divide a large file into cohesive modules. Re-export from a barrel `index.ts` to keep public API stable. |
| **Merge modules** | Consolidate small, related modules into one. Update all imports. |
| **Extract type/interface** | Pull an inline type annotation into a named type or interface. Use it everywhere the shape appears. |
| **Replace conditional with polymorphism** | Introduce an interface + implementations instead of `if/switch` on a discriminant. |
| **Remove dead code** | Search for references. If none found (excluding self-references), remove the code. Verify with `tsc`. |
| **Decouple / extract dependency** | Introduce an interface/abstraction at module boundaries. Wire via dependency injection or a factory. |
| **Simplify expression** | Reduce nesting, combine redundant conditions, extract complex predicates. |
| **Standardize conventions** | Align code with the project's prevailing style (named exports vs default, error handling, file structure). |
| **Deprecate before removing** | Keep the old export but add `@deprecated` in a JSDoc comment pointing to the replacement. Remove in a follow-up step. |

## Project-Specific Conventions

Check the project's `AGENTS.md` (or equivalent) before refactoring to
understand:

- **Framework version** (e.g., Next.js App Router, React 19 Server Components)
- **File organization** (e.g., colocated tests, `src/__tests__/` mirror)
- **Naming conventions** (e.g., PascalCase for components, camelCase for utils)
- **State patterns** (e.g., React hooks, Zustand, Redux)
- **Import style** (e.g., `@/` alias, relative imports, barrel files)

Do NOT change the project's framework, toolchain, or dependency versions as
part of a refactoring unless explicitly asked.

## Files to Update When Moving Code

When moving a symbol to a new file:

1. The source file — remove the symbol and its export
2. The target file — add the symbol (and any new imports it needs)
3. Every file that imported the symbol from the old location
4. Barrel exports (`index.ts`) if either file is re-exported through one
5. Barrel exports in the new location if applicable
6. Mock paths in test files if the module is mocked

Always use `npx tsc --noEmit` to verify no dangling imports remain.

## What NOT to Do

- Do NOT add new features, fix bugs, or write tests during refactoring steps.
  (Flag them: "I noticed a bug in `calculateTotal` — should I fix that
  separately?")
- Do NOT reformat / reindent / restyle unrelated code in the same step.
- Do NOT upgrade dependencies during a refactoring session.
- Do NOT change public API signatures without confirming there are no external
  consumers (other apps, published packages, etc.).
- Do NOT commit until the full refactoring compiles, passes lint, and the test
  suite is green.
- Do NOT leave commented-out code. Remove it or add a clear TODO with a
  justification.
