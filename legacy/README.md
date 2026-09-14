# Legacy sources

These are the original files, kept verbatim for reference and diffing. They are
**not** loaded by anything and are not part of the build.

| File | Notes |
|---|---|
| `Amdim_side.lua` | The original 1,155-line monolith. Superseded by `src/admin/` plus `src/shared/`. |
| `Tester_side.lua` | Was a single empty byte — the receiver was never written. Superseded by `src/tester/`. |

Use `dist/Admin.lua` and `dist/Tester.lua` instead. See the root `README.md`.

Two behaviours here are known to be broken and are deliberately **not**
reproduced in the rewrite:

1. **The broadcast never left the machine.** Attributes were set on a
   client-created `ReplicatedStorage` folder, which does not replicate to the
   server or to other clients. See `docs/SYNC.md`.
2. **The plot cleaner deleted player characters.** Any `Model` with a
   `Humanoid` within 60 studs of the plot pivot was destroyed, which includes
   other players standing nearby. See `PlotService.classify` and its tests.
