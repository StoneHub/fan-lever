# Fan Lever

Read README.md, ARCHITECTURE.md and STATUS.md before changing hardware control.
Keep the XPC interface restricted to validated notches and signed peers. Preserve automatic recovery and per-fan hardware limits. Never disable system thermal management.

## Delivery speed (solo repository)
Monroe is the only user. Merge authorized fixes and features to the default branch as soon as the checks you can run pass. Do not wait on CI runners or per-PR device validation. Monroe's end-to-end use when he updates is the acceptance test. Say plainly what you could not run, leave a short "test when you sit down" list in the PR, and fix forward on breakage before starting new work. Data, secrets, installs on his devices, destructive actions and public releases keep their own gates.
