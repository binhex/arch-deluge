# Deluge plugin lookup port - code review residuals

| Field | Value |
| --- | --- |
| Repo | `/data/arch-deluge` |
| Branches | `master` and `libtorrentv1` |
| Commits | `master` `02033be`, `libtorrentv1` `c363cce` |
| Round reached | 10 |
| Circuit breaker cap | `CIRCUIT_BREAKER_ROUNDS = 10` |
| Reviewer A | `opencode-go/deepseek-v4.1-flash:max` |
| Reviewer B | `opencode-go/glm-5.3-flash:max` |
| Scored scope | the `+23` line insertion in `build/root/install.sh` per branch (README and `docs/agent` hunks exempt as documentation) |

## Findings from round 10

| # | Severity | File:line | Description | Status |
| --- | --- | --- | --- | --- |
| 1 | MEDIUM | `build/root/install.sh` master `77-78`, libtorrentv1 `95-96` | The `sed` has no miss detection. GNU `sed` exits 0 when the pattern is absent, so if the shipped `pluginmanager.py` changes shape the build stays green and the patch silently does not apply (or applies partially). | not fixed - risk explicitly accepted by the user |
| 2 | MEDIUM | master `76-78`, libtorrentv1 `94-96` | The rewrite's premise - that the installed loader registers normalised component names - is never verified at build time. A case-preserving loader would turn the rewrite into a regression for plugins that previously worked. | not fixed - risk explicitly accepted by the user |
| 3 | MEDIUM | whole inserted block (`57-78` / `75-96`) | No automated test and no CI gate covers either half of the change; the `pkg_resources` install path has never been exercised in a verifiable environment (no image build available in this session). | not fixed - no-test/no-CI is the approved design |
| 4 | LOW | master `61,69`, libtorrentv1 `79,87` | `pacman -S --needed uv` is a no-op when uv already exists, but `pacman -Rns uv` always runs, so a future base image shipping uv would have it removed (or the build would die on a dependency error). | not fixed - recorded as accepted |
| 5 | LOW | master `57-78`, libtorrentv1 `75-96` | The block is duplicated verbatim on both branches with no parity gate; a future edit to one branch cannot fail the other. | not fixed - the spec declines a parity CI job |
| 6 | LOW | master `68`, libtorrentv1 `86` | The `.lock` cleanup may target a filename uv does not create in this configuration (`rm -f` makes absence harmless). | not fixed - recorded as accepted |
| 7 | LOW | master `61-69`, libtorrentv1 `79-87` | External assumptions that cannot be verified offline: the `standard-pkg-resources==1.0.0` artifact and its sha256, and `uv` availability in the aarch64 (ALARM) repositories. Each failure mode aborts the build loudly. | not fixed - environment limitation, fails closed |

## Status of every finding

**No finding was fixed in any round.** At the end of round 1 the parent asked the user how to handle the three
MEDIUMs (all consequences of the minimal design the user had chosen) and the five LOWs. The user instructed:
*"Keep the minimal block, accept the risk"* and *"Record all five, change nothing"*. Rounds 2-10 therefore
re-reported the same finding families, and the block was left byte-identical to the `arch-delugevpn` reference.
Every row above is `not fixed` by explicit user decision, not by oversight or fatigue.

The accepted-by-design context is recorded in the approved spec
(`docs/agent/specs/2026-10-11-deluge-plugin-lookup-port-design.md`), which states: *"The sed is silent on miss …
That is the accepted trade-off of the minimal shape (the fail-closed variant was removed on your decision)"* and
lists the absent test/CI job as out of scope.

## Verification gap

Round 10 is the circuit-breaker round, so nothing after it was re-reviewed. Because no fix was applied in any
round, there are no un-reviewed fixes; the gap is that these findings were never **resolved**, only recorded.

## Verified during the review (not findings)

- No HIGH-severity defect was reported by either reviewer in any of the ten rounds.
- Reviewer A withdrew its round-8 concern about Arch's PEP 668 `EXTERNALLY-MANAGED` marker in round 10: `uv pip
  install --target` deliberately bypasses that check, so the block does not hit it.
- Both reviewers independently confirmed, from the real deluge 2.2.0 `pluginmanager.py` fixture, that the pattern
  matches exactly the three raw lookups (lines 63, 91, 140), that the replacement is valid Python, that the
  operation is idempotent, and that the two branches' blocks are byte-identical to each other and to the pushed
  `arch-delugevpn` reference.
- No end-to-end image build exists for either branch (no usable docker socket in this session); the first tagged
  build remains the only proof that the plugin Web UIs render and that the `pkg_resources` half installs cleanly.
