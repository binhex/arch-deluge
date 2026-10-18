# Port the deluge plugin fixes to arch-deluge (both branches)

- **Status:** approved design, implementation pending
- **Date:** 2026-10-11
- **Source of truth:** `/data/arch-delugevpn` `master` (commit `20f1108`, pushed)
- **Targets:** `/data/arch-deluge` on `master` and `libtorrentv1`

## Problem

Two independent defects stop Deluge plugins loading on images built from this repo.
Both were fixed in `arch-delugevpn`; neither exists here yet.

1. **Plugin WebUI components are dropped.** Arch's `deluge` package backports the importlib
   plugin loader (upstream commit `dab761f3`, shipped as Arch patch
   `0004-feat-pluginmanager-new-plugin-finder-using-stdlib-wi.patch`) but not the matching
   web UI lookup. Plugins register as `WebPlugin.<lowercase snake case name>` while
   `deluge/ui/web/pluginmanager.py` still asks for `WebPlugin.<original name>`. Every mixed
   case plugin (Label, Scheduler, Blocklist, Extractor, AutoAdd, YaRSS2, AutoRemovePlus)
   misses the lookup, logs `contains no WebUI code` and silently loses its web UI.
2. **`pkg_resources` is gone.** setuptools v82 (Feb 2026) removed it, and Arch now ships
   setuptools 84. Third-party egg plugins that import it themselves — AutoRemovePlus does,
   in `autoremoveplus/common.py` — raise `ModuleNotFoundError` the moment they instantiate.

## Goal

Bring both branches of this repo to the same state as `arch-delugevpn` `master` for these
two deluge-level fixes: about 18 added lines per branch, in one contiguous block.

## Scope

**In scope:** the two blocks below, inserted into `build/root/install.sh` on `master` and
`libtorrentv1`.

**Out of scope:** environment variables, runtime scripts (`run/nobody/start.sh`),
`Dockerfile`, workflows, README, tests and CI. Neither fix reads an environment variable,
and this image has no VPN layer, so nothing VPN-related applies.

## What changes

One edit per branch: insert the following block **verbatim** (byte-identical to the
`arch-delugevpn` original) immediately before the `# custom` section header.

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

Order inside the block is significant only in that the stop-gap runs first, matching the
source's relative order. The block is reproduced verbatim, so its indentation is tabs, exactly
as it appears in `arch-delugevpn`'s `build/root/install.sh`.

## Placement per branch

Both branches run the block **after deluge is installed**, so the sed has a file to edit and
the `import pkg_resources` guard tests the interpreter Deluge actually uses.

| Branch | Anchor | Why there |
| --- | --- | --- |
| `master` | after the `pacman -S --needed $pacman_packages --noconfirm` block's closing `fi` | deluge comes from the Arch repo package |
| `libtorrentv1` | after the `glob_packages` install loop's `done` | deluge is built from AOR and installed with `pacman -U` |

The sed targets an absolute glob (`/usr/lib/python3*/site-packages/deluge/ui/web/pluginmanager.py`),
so it does not depend on this repo's `install_paths`, which is
`/home/nobody,/usr/share/GeoIP` and does not include the deluge tree.

## Why both branches need the sed

`master` runs `pacman_packages="deluge"` (Arch's repo package, carrying patches
`0001`-`0006`). `libtorrentv1` runs `aur.sh --aor-package 'deluge' --aur-package
'libtorrent-rasterbar-1_2-git'`, and `aur.sh` implements AOR as
`git clone https://gitlab.archlinux.org/archlinux/packaging/packages/<package>.git` followed
by `makepkg`. That is the same official PKGBUILD, so the same patches apply and the same
defective loader is produced.

In both cases Arch's patches also remove every `pkg_resources` import from Deluge itself, so
the stop-gap exists **only** for third-party eggs such as AutoRemovePlus.

## Deliberate non-changes

- `install_paths` stays `/home/nobody,/usr/share/GeoIP`. Adding
  `/usr/lib/python*/site-packages/deluge` would force unquoting the path check and would
  change the runtime chown. It is not needed: GNU `sed -i` preserves the packaged mode
  (`644 root:root`) and `nobody` only needs read access.
- The quoted path check `if [[ ! -d "${i}" ]]` stays as-is. It is latent in this repo
  because no configured install path contains a wildcard.
- No test file and no CI job are added, matching the `arch-delugevpn` state after its
  simplification, and no review ledger is carried over.

## Verification

Minimal, by agreement. Run from the repo root on each branch:

1. `bash -n build/root/install.sh`
2. `shellcheck build/root/install.sh` — expect no findings beyond those already present.
3. Functional check of the sed against a real deluge 2.2.0 `pluginmanager.py` fixture. The
   expression below is inlined instead of using the block's `deluge_lookup_new` variable; the
   replacement text is identical.

   ```bash
   fixture=/tmp/pluginmanager.py
   curl -sSL -o "$fixture" \
     https://raw.githubusercontent.com/deluge-torrent/deluge/deluge-2.2.0/deluge/ui/web/pluginmanager.py
   grep -cF "component.get('WebPlugin.' + name)" "$fixture"        # expect 3
   sed -i "s~component\.get('WebPlugin\.' + name)~component.get('WebPlugin.' + name.lower().replace('-', '_').replace(' ', '_'))~g" "$fixture"
   grep -cF "component.get('WebPlugin.' + name)" "$fixture"        # expect 0
   grep -cF "name.lower().replace('-', '_').replace(' ', '_')" "$fixture"   # expect 3
   python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$fixture"
   ```

4. Structural check of the stop-gap: its `uv pip install` flag set was exercised against the
   real Arch `uv 0.12.22` binary in an earlier session, and `uv` is packaged for both amd64
   (Arch) and aarch64 (ALARM), so the port reuses proven flags. The `import pkg_resources`
   guard makes the whole block a no-op wherever the module is present.

**Not covered:** a real image build. This environment has no usable docker socket, so the
image build remains the final proof.

## Commit plan

1. This spec, committed in this repo at
   `docs/agent/specs/2026-10-11-deluge-plugin-lookup-port-design.md` on both branches.
2. One commit per branch with the ported block, same message on both, for example
   `fix deluge plugin web ui lookup and install pkg_resources for legacy eggs`.

No push, tag or release — integration is decided by the finalising step.

## Risks and limitations

- **The sed is silent on miss.** If a future Arch deluge changes the lookup shape, the build
  still succeeds and the original bug returns. This is the accepted trade-off of the minimal
  shape; the fail-closed variant was removed by explicit decision.
- The `pkg_resources` stop-gap is temporary. Third-party eggs still need the module until
  they migrate (upstream deluge PRs #488 and #501 remain open).
- The two branches now carry identical blocks. If one deluge provenance changes, they can
  drift; the `arch-delugevpn` repo detected that with a CI parity job, and no equivalent is
  being added here.
