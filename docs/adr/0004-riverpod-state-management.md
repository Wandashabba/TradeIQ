# 0004. Riverpod for Flutter state management

Date: 2026-07-02
Status: Accepted

## Context

Needed one consistent state-management pattern across all Flutter feature
modules, chosen before any screens were built, given the app's heavy
async/offline-sync requirements.

## Decision

Use Riverpod (`flutter_riverpod`) throughout the app.

## Consequences

- Compile-safe, testable providers; strong support for the offline-first
  sync work (Task 19-20).
- New Flutter hires need to learn Riverpod specifically, not BLoC or plain
  Provider.
