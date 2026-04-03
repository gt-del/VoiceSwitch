# Rust Core Change Checklist

## Change Summary

## Error Handling

- [ ] Library-like errors use explicit error types
- [ ] No unjustified unwrap/expect
- [ ] Failure paths are explicit

## Ownership And Types

- [ ] No unnecessary clone to satisfy borrow checker
- [ ] Types express important invariants
- [ ] Public interfaces are explicit

## Observability And Tests

- [ ] Logging/tracing impact is documented
- [ ] Replayability impact is documented
- [ ] Tests added or updated

## Boundary Check

- [ ] No macOS platform semantics leaked into core
- [ ] No UI semantics leaked into core
- [ ] No FFI boundary change left unreviewed
