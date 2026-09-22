# Changelog

## Unreleased – 2026-09-22

Nothing changes in the game: the add-on loads the same code in the same order.

- The repository follows the project layout: the add-on lives in `apps/desktop/` with `classes/`, `views/` and
  `lang/`, the CurseForge page text in `docs/`, logo and screenshots in `assets/`.
- The release zip keeps its shape — `Warbrand-Fast-Mail/` with the `.toc` directly inside — through `move-folders` in
  `.pkgmeta`. It no longer carries the repository README.
- `apps/desktop/VERSION` repeats `## Version:` from the `.toc`. The release workflow refuses a tag when tag, `.toc`
  and `VERSION` disagree.
- `tools/build_lang.py` writes to `apps/desktop/lang/`; its output is byte-identical.
- README rewritten; it now also lists `/wfm sendall`, `/wfm check` and `/wfm reserve -`.
