# Deluge plugin fixes port to arch-deluge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use sub-agents (recommended) to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring both branches of `/data/arch-deluge` to parity with `arch-delugevpn` `master` for the
two deluge-level plugin fixes, by inserting one verbatim block into `build/root/install.sh` on each
branch.

**Architecture:** A single build-time insertion per branch. The block first installs the standalone
`pkg_resources` redistribution only when the interpreter lacks it (self-disabling guard), then rewrites
the three `WebPlugin` component lookups in the installed `deluge/ui/web/pluginmanager.py` with a `sed`
that matches the loader's normalised registration key. Nothing else in either repo changes.

**Tech Stack:** bash, GNU sed, pacman/uv (build-time), git. No test framework exists in this repo;
verification is `bash -n`, `shellcheck`, and a one-off fixture run of the sed.

---

## Context the engineer needs

Arch's `deluge` package backports the importlib plugin loader but not the matching Web UI lookup:
plugins register as `WebPlugin.<lowercase snake case name>` while
`deluge/ui/web/pluginmanager.py` still asks for `WebPlugin.<original name>`. Every mixed-case plugin
(Label, Scheduler, Blocklist, Extractor, AutoAdd, YaRSS2, AutoRemovePlus) misses the lookup, logs
`contains no WebUI code`, and silently loses its Web UI. Separately, setuptools v82 removed
`pkg_resources`, which third-party egg plugins such as AutoRemovePlus import themselves.

Both branches of this repo produce the *same* patched deluge — `master` installs Arch's repo package,
`libtorrentv1` builds deluge from AOR (`aur.sh --aor-package 'deluge'`, which is a `git clone` of
`gitlab.archlinux.org/archlinux/packaging/packages/deluge.git` plus `makepkg`) — so both need both fixes.

The full design, including the deliberate non-changes and the risk list, is the approved spec at
`/data/arch-deluge/docs/agent/specs/2026-10-11-deluge-plugin-lookup-port-design.md`. In short, the
risks are that the sed is silent on miss, that the stop-gap is temporary until third-party plugins
migrate, and that the two branches can drift with no parity job to catch it.

## Scope check

One subsystem, one file, one insertion per branch. No decomposition is required and no sub-project
plans are created.

## File structure

| Path | Action | Responsibility |
| --- | --- | --- |
| `/data/arch-deluge/build/root/install.sh` (branch `master`) | Modify — insert 22 lines after line 55 | Build-time plugin fixes |
| `/data/arch-deluge/build/root/install.sh` (branch `libtorrentv1`) | Modify — insert 22 lines after line 73 | Build-time plugin fixes |
| `/data/arch-deluge/docs/agent/plans/2026-10-11-deluge-plugin-lookup-port.md` | Create (this plan) | Agent record |
| `/data/arch-deluge/docs/agent/specs/2026-10-11-deluge-plugin-lookup-port-design.md` | Already committed | Approved design |

No test file, no CI job, no runtime script, no `Dockerfile`, no README, and no other build script is
touched. `libtorrentv1` is the branch currently checked out in that repo; leave it that way at the end.

## The block to insert (verbatim — tabs matter)

Copy this exactly, indentation included. It is byte-identical to the copy in the approved spec and to
`arch-delugevpn master`. The blank line separating the two halves is part of the insertion.

```bash
# deluge loads its plugins through pkg_resources, which setuptools removed in v82
# (Feb 2026) - install the standalone redistribution (source: pypa/setuptools) into
# the system python used by deluge until upstream migrates to importlib
if ! python3 -c 'import pkg_resources' &>/dev/null; then
	pacman -S --needed uv --noconfirm
	cat <<'EOF' > /tmp/pkg_resources_requirements.txt
standard-pkg-resources==1.0.0 --hash=sha256:4cb8701c863000f60637495427121c0da697b395c9088dff7e864bc741a3f2e8
EOF
	site_packages=$(python3 -c 'import site; print(site.getsitepackages()[0])')
	uv pip install --no-cache --no-deps --require-hashes --python "$(command -v python3)" \
		--target "${site_packages}" -r /tmp/pkg_resources_requirements.txt
	rm -f /tmp/pkg_resources_requirements.txt "${site_packages}/.lock"
	pacman -Rns uv --noconfirm
	python3 -c 'import pkg_resources' || { echo "[crit] Failed to install pkg_resources, exiting build process..." ; exit 1; }
fi

# Arch's deluge package backports the importlib plugin loader but not the matching web ui
# lookup, so mixed case plugins (Label, Scheduler, YaRSS2) lose their web ui - normalise
# the three lookups to match the registration
deluge_lookup_new="component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))"
sed -i "s~component\.get('WebPlugin\.' + name)~${deluge_lookup_new}~g" \
	/usr/lib/python3*/site-packages/deluge/ui/web/pluginmanager.py
```

### Task 1: Port the block to `master`

**Files:**

- Modify: `/data/arch-deluge/build/root/install.sh` (branch `master`), inserting after the `fi` that
  closes the pacman install block (currently line 55), before the existing blank line and `# custom`

- [ ] **Step 1: Prove the work is not done yet (expected-fail state)**

Run:

```bash
git -C /data/arch-deluge show master:build/root/install.sh | grep -c 'standard-pkg-resources'
git -C /data/arch-deluge show master:build/root/install.sh | grep -c 'deluge_lookup_new'
```

Expected: `0` then `0` — neither fix is present.

- [ ] **Step 2: Prove the fixture needs the sed (the behaviour under repair)**

Run:

```bash
curl -sSL -o /tmp/pluginmanager.py \
  https://raw.githubusercontent.com/deluge-torrent/deluge/deluge-2.2.0/deluge/ui/web/pluginmanager.py
grep -cF "component.get('WebPlugin.' + name)" /tmp/pluginmanager.py
```

Expected: `3` — three raw lookups that need normalising.

- [ ] **Step 3: Check out `master` and confirm a clean tree**

Run:

```bash
git -C /data/arch-deluge checkout master
git -C /data/arch-deluge rev-parse --abbrev-ref HEAD
git -C /data/arch-deluge status --porcelain
```

Expected: `master`, then no output from `status`.

- [ ] **Step 4: Insert the block after the pacman install block**

Run this exactly; it anchors on the closing lines of the pacman install block and refuses to guess if
the anchor is not unique:

```bash
python3 - <<'PY'
import pathlib

path = pathlib.Path('/data/arch-deluge/build/root/install.sh')
text = path.read_text(encoding='utf-8')
anchor = "\tpacman -S --needed $pacman_packages --noconfirm\nfi\n"
assert text.count(anchor) == 1, 'pacman install anchor not unique'

block = '''# deluge loads its plugins through pkg_resources, which setuptools removed in v82
# (Feb 2026) - install the standalone redistribution (source: pypa/setuptools) into
# the system python used by deluge until upstream migrates to importlib
if ! python3 -c 'import pkg_resources' &>/dev/null; then
\tpacman -S --needed uv --noconfirm
\tcat <<'EOF' > /tmp/pkg_resources_requirements.txt
standard-pkg-resources==1.0.0 --hash=sha256:4cb8701c863000f60637495427121c0da697b395c9088dff7e864bc741a3f2e8
EOF
\tsite_packages=$(python3 -c 'import site; print(site.getsitepackages()[0])')
\tuv pip install --no-cache --no-deps --require-hashes --python "$(command -v python3)" \\
\t\t--target "${site_packages}" -r /tmp/pkg_resources_requirements.txt
\trm -f /tmp/pkg_resources_requirements.txt "${site_packages}/.lock"
\tpacman -Rns uv --noconfirm
\tpython3 -c 'import pkg_resources' || { echo "[crit] Failed to install pkg_resources, exiting build process..." ; exit 1; }
fi

# Arch's deluge package backports the importlib plugin loader but not the matching web ui
# lookup, so mixed case plugins (Label, Scheduler, YaRSS2) lose their web ui - normalise
# the three lookups to match the registration
deluge_lookup_new="component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))"
sed -i "s~component\\.get('WebPlugin\\.' + name)~${deluge_lookup_new}~g" \\
\t/usr/lib/python3*/site-packages/deluge/ui/web/pluginmanager.py
'''
path.write_text(text.replace(anchor, anchor + '\n' + block, 1), encoding='utf-8', newline='')
print('inserted')
PY
```

Note: the block string uses `\t` for indentation so the tabs survive; the inserted file must contain
real tab characters, which Step 6 verifies against the source copy.

- [ ] **Step 5: Confirm the insertion landed where intended**

Run:

```bash
git -C /data/arch-deluge diff --stat master -- build/root/install.sh
git -C /data/arch-deluge diff master -- build/root/install.sh | head -4
```

Expected: `1 file changed, 23 insertions(+)` and a hunk header near `@@ -54,6 +54,29 @@`.

- [ ] **Step 6: Verify the inserted text is byte-identical to the known-good source**

Run:

```bash
diff \
  <(git -C /data/arch-delugevpn show master:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/^fi$/p') \
  <(git -C /data/arch-deluge show master:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/^fi$/p')
diff \
  <(git -C /data/arch-delugevpn show master:build/root/install.sh | sed -n '/^# Arch.s deluge package backports/,/pluginmanager.py$/p') \
  <(git -C /data/arch-deluge show master:build/root/install.sh | sed -n '/^# Arch.s deluge package backports/,/pluginmanager.py$/p')
```

Expected: no output from either diff — both blocks byte-identical to the source. The two blocks are
**not adjacent** in `arch-delugevpn` (the 7zip, Python-Eggs and `peer_id` steps sit between them), so
they are compared one at a time; one range would span 50 lines there and 22 here and fail every time.
Also run:

```bash
git -C /data/arch-deluge show master:build/root/install.sh | grep -n 'EOF' | head
```

Expected: exactly two lines, the `cat <<'EOF'` line and a bare `EOF` line.

- [ ] **Step 7: Syntax and lint gates**

Run:

```bash
bash -n /data/arch-deluge/build/root/install.sh && echo "bash -n: OK"
shellcheck -f gcc /data/arch-deluge/build/root/install.sh
```

Expected: `bash -n: OK`, then shellcheck output consisting only of the pre-existing findings
(`SC1091` for `upd.sh`, plus `SC2086` on the unquoted `install_paths` expansions). No new finding may
mention any line inside the inserted block.

- [ ] **Step 8: Prove the sed does what the block claims**

Extract the sed's two expressions from the file just edited and apply them to the fixture:

```bash
deluge_lookup_new="component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))"
sed -i "s~component\.get('WebPlugin\.' + name)~${deluge_lookup_new}~g" /tmp/pluginmanager.py
grep -cF "component.get('WebPlugin.' + name)" /tmp/pluginmanager.py
grep -cF "$deluge_lookup_new" /tmp/pluginmanager.py
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read()); print("parses")' /tmp/pluginmanager.py
```

Expected: `0`, then `3`, then `parses`.

- [ ] **Step 9: Structural check of the stop-gap (cannot be executed here)**

Run:

```bash
git -C /data/arch-deluge show master:build/root/install.sh | grep -n -A3 "import pkg_resources' &>/dev/null"
```

Expected: the `if !` guard is present, and inside it the `pacman -S --needed uv --noconfirm`,
`uv pip install --no-cache --no-deps --require-hashes`, and `pacman -Rns uv --noconfirm` lines. These
exact flags were exercised against the real Arch `uv 0.12.22` binary when the fix was first written,
and `uv` is packaged for both architectures this repo builds (`uv` in Arch, `uv` in ALARM). The guard
means the whole block is skipped on any image where `import pkg_resources` already works.

- [ ] **Step 10: Commit**

```bash
git -C /data/arch-deluge add build/root/install.sh
git -C /data/arch-deluge commit -m "fix deluge plugin web ui lookup and install pkg_resources for legacy eggs"
git -C /data/arch-deluge log --oneline -1
```

Expected: the new commit on `master`, message exactly as above.

### Task 2: Port the block to `libtorrentv1`

**Files:**

- Modify: `/data/arch-deluge/build/root/install.sh` (branch `libtorrentv1`), inserting after the `done`
  that closes the `glob_packages` install loop (currently line 73), before the existing blank line and
  `# custom`

- [ ] **Step 1: Prove the work is not done yet**

Run:

```bash
git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | grep -c 'standard-pkg-resources'
git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | grep -c 'deluge_lookup_new'
```

Expected: `0` then `0`.

- [ ] **Step 2: Check out `libtorrentv1` and confirm a clean tree**

Run:

```bash
git -C /data/arch-deluge checkout libtorrentv1
git -C /data/arch-deluge rev-parse --abbrev-ref HEAD
git -C /data/arch-deluge status --porcelain
```

Expected: `libtorrentv1`, then no output.

- [ ] **Step 3: Insert the block after the package install loop**

Run this exactly; the anchor is the closing `done` of the `glob_packages` loop and must be unique:

```bash
python3 - <<'PY'
import pathlib

path = pathlib.Path('/data/arch-deluge/build/root/install.sh')
text = path.read_text(encoding='utf-8')
anchor = "        exit 1\n    fi\ndone\n"
assert text.count(anchor) == 1, 'glob package loop anchor not unique'

block = '''# deluge loads its plugins through pkg_resources, which setuptools removed in v82
# (Feb 2026) - install the standalone redistribution (source: pypa/setuptools) into
# the system python used by deluge until upstream migrates to importlib
if ! python3 -c 'import pkg_resources' &>/dev/null; then
\tpacman -S --needed uv --noconfirm
\tcat <<'EOF' > /tmp/pkg_resources_requirements.txt
standard-pkg-resources==1.0.0 --hash=sha256:4cb8701c863000f60637495427121c0da697b395c9088dff7e864bc741a3f2e8
EOF
\tsite_packages=$(python3 -c 'import site; print(site.getsitepackages()[0])')
\tuv pip install --no-cache --no-deps --require-hashes --python "$(command -v python3)" \\
\t\t--target "${site_packages}" -r /tmp/pkg_resources_requirements.txt
\trm -f /tmp/pkg_resources_requirements.txt "${site_packages}/.lock"
\tpacman -Rns uv --noconfirm
\tpython3 -c 'import pkg_resources' || { echo "[crit] Failed to install pkg_resources, exiting build process..." ; exit 1; }
fi

# Arch's deluge package backports the importlib plugin loader but not the matching web ui
# lookup, so mixed case plugins (Label, Scheduler, YaRSS2) lose their web ui - normalise
# the three lookups to match the registration
deluge_lookup_new="component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))"
sed -i "s~component\\.get('WebPlugin\\.' + name)~${deluge_lookup_new}~g" \\
\t/usr/lib/python3*/site-packages/deluge/ui/web/pluginmanager.py
'''
path.write_text(text.replace(anchor, anchor + '\n' + block, 1), encoding='utf-8', newline='')
print('inserted')
PY
```

- [ ] **Step 4: Confirm the insertion landed where intended**

Run:

```bash
git -C /data/arch-deluge diff --stat libtorrentv1 -- build/root/install.sh
git -C /data/arch-deluge diff libtorrentv1 -- build/root/install.sh | head -4
```

Expected: `1 file changed, 23 insertions(+)` and a hunk header near `@@ -72,6 +72,29 @@`.

- [ ] **Step 5: Verify the inserted text is byte-identical to `master`'s copy and to the source**

Run:

```bash
diff \
  <(git -C /data/arch-delugevpn show master:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/^fi$/p') \
  <(git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/^fi$/p')
diff \
  <(git -C /data/arch-delugevpn show master:build/root/install.sh | sed -n '/^# Arch.s deluge package backports/,/pluginmanager.py$/p') \
  <(git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | sed -n '/^# Arch.s deluge package backports/,/pluginmanager.py$/p')
git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | grep -n 'EOF' | head
```

Expected: no output from either diff, and the same `EOF` lines as in Task 1 Step 6. Both operands here
are this repo's own branches, so a single range would also have worked, but the per-block form is kept
for consistency with Task 1.

- [ ] **Step 6: Syntax and lint gates**

Run:

```bash
bash -n /data/arch-deluge/build/root/install.sh && echo "bash -n: OK"
shellcheck -f gcc /data/arch-deluge/build/root/install.sh
```

Expected: `bash -n: OK`, then only pre-existing findings. The inserted block must not appear in any
finding.

- [ ] **Step 7: Prove the sed still does what the block claims**

The sed text is identical to Task 1's, so reuse the already-normalised fixture from Task 1 Step 8 by
re-downloading it and repeating the three checks:

```bash
curl -sSL -o /tmp/pluginmanager-ltv1.py \
  https://raw.githubusercontent.com/deluge-torrent/deluge/deluge-2.2.0/deluge/ui/web/pluginmanager.py
deluge_lookup_new="component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))"
sed -i "s~component\.get('WebPlugin\.' + name)~${deluge_lookup_new}~g" /tmp/pluginmanager-ltv1.py
grep -cF "component.get('WebPlugin.' + name)" /tmp/pluginmanager-ltv1.py
grep -cF "$deluge_lookup_new" /tmp/pluginmanager-ltv1.py
```

Expected: `0`, then `3`.

- [ ] **Step 8: Commit**

```bash
git -C /data/arch-deluge add build/root/install.sh
git -C /data/arch-deluge commit -m "fix deluge plugin web ui lookup and install pkg_resources for legacy eggs"
git -C /data/arch-deluge log --oneline -1
```

Expected: the new commit on `libtorrentv1`, same message as `master`'s.

### Task 3: Cross-branch verification and hand-back

**Files:**

- No file changes. Verification and state restoration only.

- [ ] **Step 1: Confirm the two branches' inserted blocks are byte-identical**

Run:

```bash
diff \
  <(git -C /data/arch-deluge show master:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/pluginmanager.py$/p') \
  <(git -C /data/arch-deluge show libtorrentv1:build/root/install.sh | sed -n '/^# deluge loads its plugins/,/pluginmanager.py$/p') \
  && echo "blocks identical"
```

Expected: `blocks identical`.

- [ ] **Step 2: Confirm neither commit touched anything else**

Run:

```bash
git -C /data/arch-deluge show --stat --format='%h %s' master | head -5
git -C /data/arch-deluge show --stat --format='%h %s' libtorrentv1 | head -5
```

Expected: each commit shows exactly one file (`build/root/install.sh`) with 23 insertions and no
deletions.

- [ ] **Step 3: Confirm the non-changes held**

Run:

```bash
git -C /data/arch-deluge diff origin/master..master --stat
git -C /data/arch-deluge diff origin/libtorrentv1..libtorrentv1 --stat
```

Expected: each branch is `build/root/install.sh` plus the spec commit; nothing under `run/`,
`Dockerfile`, `.github/`, or `README.md`.

- [ ] **Step 4: Restore the checked-out branch and confirm a clean tree**

Run:

```bash
git -C /data/arch-deluge checkout libtorrentv1
git -C /data/arch-deluge rev-parse --abbrev-ref HEAD
git -C /data/arch-deluge status --porcelain
```

Expected: `libtorrentv1`, then no output.

- [ ] **Step 5: Report, do not push**

No `git push`, no tag, no release. Report both commits and the verification output; integration is
decided by the finalising step.

## Not in scope — do not do these

- Do not add `/usr/lib/python*/site-packages/deluge` to `install_paths`, and do not unquote the
  `[[ ! -d "${i}" ]]` path check. The deluge tree gets no chown or chmod today, and it does not need
  any: GNU `sed -i` preserves the packaged mode (`644 root:root`) and `nobody` only needs read access.
- Do not touch `run/nobody/start.sh`, the `Dockerfile`, either workflow, or the README. Neither fix
  reads an environment variable, and this image has no VPN layer.
- Do not add a test file or a CI job.
- Do not upgrade the 7zip URLs (`7z2409` there versus `7z2600` in `arch-delugevpn`), add the arm64
  `!!debug` makepkg workaround, or port the `peer_id` sed. Those are separate concerns the spec
  explicitly excludes.
- Do not edit anything in `/data/arch-delugevpn`; it is the reference, not a target.

## Definition of done

1. Both branches carry the block, byte-identical to `arch-delugevpn master`'s copy.
2. One commit per branch, message `fix deluge plugin web ui lookup and install pkg_resources for legacy
   eggs`, each touching only `build/root/install.sh` (23 insertions).
3. `bash -n` clean and `shellcheck` showing no finding that mentions the inserted block, on both branches.
4. Fixture check shows 3 raw lookups become 0 raw and 3 normalised, and the file still parses.
5. `/data/arch-deluge` left checked out on `libtorrentv1` with a clean tree; nothing pushed.
