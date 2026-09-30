# Contributing to MoonPlan

Issues and pull requests are welcome. Please keep the core deterministic,
dependency-light, and explainable.

Before opening a pull request, run:

```bash
moon fmt
moon test --deny-warn
moon build --target js
node integration/juju-planner-contract.test.js
```

When changing a recommendation rule, add a test that explains the intended
trade-off. Do not convert unknown information into a guessed travel time or
silently weaken a hard constraint.
