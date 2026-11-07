# Changelog

## 12.1.5.2 – 2026-11-07

- Added: runs on Classic (Era/Anniversary, TBC, Wrath, Cata, MoP) besides Retail. Without the warband only non-soulbound items are mailed by the rules.
- Fixed: open items are no longer taken for soulbound when the client cannot report the bind state.
- Changed: the version warning only applies to Retail.

## 12.1.5.1 – 2026-10-15

- Fixed: no more "Duplicate File Load" warning on English clients; the English base now loads from lang\Base.xml.

## 12.1.5.0 – 2026-10-14

### Changed

- Built for WoW 12.1.5: `## Interface:` leads with `120105`; `120100` and the older numbers stay declared as
  compatible.


### Fixed

- `/wfm hold <itemID>` for an item without an entry said it had been removed from the hold list; it now says the
  item is not on the hold list.
- The recipient of every item mail is checked again right before it is sent, as the gold recipient already was. A
  name that fails stops the run.

### Repository

Nothing changes in the game: the add-on loads the same code in the same order.

- The repository follows the project layout: the add-on lives in `apps/desktop/` with `classes/`, `views/` and
  `lang/`, the CurseForge page text in `docs/`, logo and screenshots in `assets/`.
- The release zip keeps its shape — `Warbrand-Fast-Mail/` with the `.toc` directly inside — through `move-folders` in
  `.pkgmeta`. It no longer carries the repository README.
- `apps/desktop/VERSION` repeats `## Version:` from the `.toc`. The release workflow refuses a tag when tag, `.toc`
  and `VERSION` disagree.
- `tools/build_lang.py` writes to `apps/desktop/lang/`; its output is byte-identical.
- README rewritten; it now also lists `/wfm sendall`, `/wfm check` and `/wfm reserve -`.
