---
paths: "**/*.ts,**/*.tsx,**/tsconfig.json,**/package.json"
description: TypeScript style rules — strict mode, no `any`, ESM-first, narrow types over wide ones.
---

# TypeScript style rules

Loaded whenever you touch a `.ts` / `.tsx` file or a TypeScript packaging file.

## Compiler

`tsconfig.json` must include:

```jsonc
{
  "compilerOptions": {
    "strict": true,                       // umbrella for the strict family
    "noUncheckedIndexedAccess": true,     // forces `T | undefined` on indexed access
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "verbatimModuleSyntax": true,         // import type vs import discipline
    "isolatedModules": true,
    "moduleResolution": "Bundler",
    "module": "ESNext",
    "target": "ES2022"
  }
}
```

ESM-first. CJS only when consuming a legacy dep that hasn't shipped ESM.

## Types

- **No `any`.** If a value is truly unknowable, use `unknown` and narrow with a type guard.
- **No `as` assertions** unless you can prove the runtime invariant. `value as Foo` is a lie until proven; prefer `satisfies Foo` when narrowing literals.
- **Discriminated unions over flag bags.** `type State = { status: 'idle' } | { status: 'loading' } | { status: 'error', error: Error }`.
- **`readonly` arrays + `Readonly<T>` for params** that you don't intend to mutate.
- **`as const` for literal unions.** `const colors = ['red', 'green'] as const` infers `readonly ['red', 'green']`.

## Imports

- **`import type { Foo } from './foo'`** when only the type is used. Cuts the runtime cost in some bundlers.
- **Default exports only when there's a single canonical export.** Otherwise named exports.
- **Path aliases** in `tsconfig.json#paths` for deep imports; tooling-friendly.

## React / TSX (when applicable)

- **Function components, not classes.** Hooks for everything except error boundaries.
- **`useState` typed at the call site**: `useState<string | null>(null)`, not `useState(null)`.
- **`useEffect` dependency arrays are exhaustive.** Use the eslint rule `react-hooks/exhaustive-deps`.
- **No prop-drilling beyond 2 levels**; lift to context or a state library at that depth.
- **No inline functions in JSX hot paths** — they break React.memo memoization.

## Async patterns

- **`async/await` over raw promises.** `try/catch` for error handling.
- **`Promise.all` for parallel independent work**, `Promise.allSettled` when partial failures are acceptable.
- **No floating promises.** If a promise is fire-and-forget, document it with `void promise` or `.catch(handler)`.

## Tooling

- **`tsc --noEmit` in CI**, never `--skipLibCheck` in your own code (only allowed when a dep ships broken types).
- **`eslint` with `@typescript-eslint/recommended-type-checked`.** Type-aware lint catches what plain lint misses.
- **`prettier`** for formatting. Don't argue about style; let the formatter decide.
- **Vitest or Jest** for tests. Vitest's ESM support is better for ESM-first projects.

## Anti-patterns

- ❌ `// @ts-ignore` without a comment explaining why. Use `// @ts-expect-error <reason>` instead — it fails the build when the underlying issue is fixed.
- ❌ Type assertions to silence the compiler (`as unknown as T`). Almost always a sign that the type modeling is wrong.
- ❌ Enums (use `as const` literal unions; cheaper and tree-shakeable).
- ❌ `null` and `undefined` used interchangeably. Pick one for "missing" semantics in your codebase.
- ❌ Default exports that are arrow functions — they show up in stack traces as `default`.
