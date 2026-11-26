---
name: architect
description: Design the structure of a change that crosses function, module or service boundaries before writing it — trace every system it touches, sketch two different designs, compare them on state ownership and canonical paths, and stop at a recommendation. Writes no implementation code. Use for /my:architect, "design this before we build it", or boundary-crossing changes (設計してから実装, 境界をまたぐ変更).
argument-hint: "<feature or boundary change>"
disable-model-invocation: true
---

# Architect

Settle the structure before the code. A change that crosses a boundary costs the most to undo once callers depend on its shape, so agree on that shape first.

Write no implementation code. The output is a design and a recommendation, then stop.

## 1. Trace

From the code, map everything the change touches, with `file:line` for each:

- The systems, modules and services on the path, and the entry points (handlers, jobs, CLI) that reach it.
- Every caller of what will change, and what each one assumes.
- The persistence and process boundaries: tables, caches, queues, files, RPCs. Who writes each, who reads it.
- The old paths the change could replace.

When the area is unfamiliar, `/my:how` first. When the reach is unclear, `/my:blast-radius`.

## 2. Sketch two designs

Two designs that differ in structure, not in naming. For each:

- The data structures, and the types or signatures at each boundary.
- Which component owns each piece of state.
- Where errors are raised, where they are handled, and what the caller sees.
- Which old paths it deletes, and how the callers move over.

## 3. Compare and recommend

Score both on:

- **One owner per state**: can two components write the same state?
- **One canonical path per operation**: is there exactly one way to do each thing, or a new one beside an old one?
- **Least knowledge for callers**: what must a caller know to use it correctly?
- **Invalid states impossible**: do the types or the structure rule out the states that must never exist, or does a check at runtime have to catch them?

Recommend one, and say why the other lost. When an uncertainty can be settled by an experiment (does the library allow this, is this fast enough), build a throwaway prototype in `${TMPDIR:-/tmp}` when it takes minutes, and report what it showed; otherwise propose it and what it must show. Never build it into the repository.

Stop here and wait for agreement before anyone implements.

Adapted from pstack `architect` (github.com/cursor/plugins, MIT).
