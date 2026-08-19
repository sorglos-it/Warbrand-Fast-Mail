# Warbrand-Fast-Mail

[![World of Warcraft](https://img.shields.io/badge/World%20of%20Warcraft-Retail-00AEFF?logo=battledotnet&logoColor=white)](#requirements)
[![Interface](https://img.shields.io/badge/interface-120100-0b7285.svg)](#versioning)
[![Type](https://img.shields.io/badge/type-add--on-8e44ad.svg)](#installation)
[![Languages](https://img.shields.io/badge/UI-DE%20%7C%20EN%20%7C%20ES%20%7C%20FR%20%7C%20IT-4c1.svg)](#languages)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)](#architecture)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C.svg?logo=paypal)](https://www.paypal.com/donate/?hosted_button_id=6CDEVZGJWTNQQ)

A World of Warcraft add-on that **empties your bags into the mailbox by rule**. Open a mailbox, and a panel appears next to it showing exactly where every item is going — "7 × Bankchar", "3 × Muli", "5 without recipient", "2 held". Press one button and it sends them, in batches of 12, to as many different recipients as your rules name.

It moves **warbound** and **unbound (BoE)** items. Soulbound gear is never touched, and the add-on determines that from the API rather than from tooltip text, so it does not depend on your client language.

Gold works the same way: everything **above a reserve you set** goes to a fixed character, with the amount recalculated immediately before the transfer rather than taken from the confirmation dialog.

## Features

- **Rule engine** — a top-down list, first matching rule wins; anything unmatched goes to the character's default recipient
- **Multiple recipients per run** — the plan is computed once and mailed in 12-item batches, up to a hard cap of 25 mails
- **Two scopes everywhere** — rules, hold list and both default recipients exist account-wide and per character, the character value beating the account one
- **Hold list with quantities** — an empty amount means *never send*, `20` means *keep 20 and send the rest*, including partial-stack splitting
- **Self-lock** — when a rule names the character you are on, the item stays put, even if that rule is scoped to somebody else, so a delivery is never mailed straight back out
- **Gold transfer with reserve** — sends everything above the reserve, postage deducted on top so the reserve stays exact
- **Categories from the auction house** — the category dropdown is derived from Blizzard's own browse tree, localized and always current, instead of the dead entries in `Enum.ItemClass`
- **Five languages** — German, English, Spanish (ES/MX), French, Italian, picked from the client locale
- **No network access** — no `loadstring`, no addon comms, nothing leaves your client

## Requirements

- World of Warcraft **Retail** (Interface `120100` / patch 12.1.0; older interface versions `120007`, `120005`, `120001` are declared as compatible)
- Nothing else — no library dependencies, no external add-ons

## Installation

1. Download the latest release and unpack it.
2. Copy the `Warbrand-Fast-Mail` folder into the AddOns directory:

   | OS | Path |
   |---|---|
   | Windows | `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\` |
   | macOS | `/Applications/World of Warcraft/_retail_/Interface/AddOns/` |

   The result must look like this — the folder name and the `.toc` name have to match, or the client will not list the add-on:

   ```
   World of Warcraft\_retail_\Interface\AddOns\Warbrand-Fast-Mail\Warbrand-Fast-Mail.toc
   ```

3. Restart the client, or type `/reload` if it is already running.
4. Check that it loaded: `/wfm version` prints the add-on version, the WoW version it was built for, and your client's interface number.

If the interface number differs from the one shown above, update the first entry in `## Interface:` and the first three digits of `## Version:` in the `.toc`. See [Versioning](#versioning) for what a mismatch means.

### Enabling it

The add-on is `## DefaultState: Enabled`, so it is active after the restart. It also registers an entry in the **AddOn Compartment** (the icon next to the minimap) that opens the rules window.

## Usage

Open any mailbox. The panel appears to the right of the mail frame and shows the distribution plan before anything is sent.

1. Set a default recipient: `/wfm target <name>` (this character) or `/wfm target global <name>` (all characters).
2. Optionally add rules for anything that should go elsewhere — `/wfm rules`.
3. Press **Send** on the panel, or type `/wfm send`.

A confirmation dialog with the full plan appears first; it can be switched off with `/wfm confirm`.

## Slash commands

Two aliases drive the same command: `/warbrand-fast-mail` (the full name) and `/wfm`. The short form is used throughout this table and in the in-game help. There is deliberately no generic `/warbrand` — that is the kind of name another add-on claims, and the last registration wins.

| Command | Effect |
|---|---|
| `/wfm send` | Run all rules |
| `/wfm force <name>` | Ignore rules, send everything to one recipient |
| `/wfm target <name>` | Default recipient, this character |
| `/wfm target global <name>` | Default recipient, all characters |
| `/wfm gold` | Send gold minus the reserve |
| `/wfm goldtarget <name>` | Gold recipient, this character |
| `/wfm goldtarget global <name>` | Gold recipient, all characters |
| `/wfm reserve <gold>` | Set the reserve (default 100) |
| `/wfm settings` | Settings window |
| `/wfm rules` | Rules window |
| `/wfm hold` | Hold list (also `/wfm ignore`, `/wfm keep`) |
| `/wfm hold <itemID>` | Show the current entry |
| `/wfm hold <itemID> 20` | Keep 20, send the rest |
| `/wfm hold <itemID> -` | Delete the entry |
| `/wfm hold char <itemID> 20` | Same, for this character only |
| `/wfm list` | Print the distribution plan to chat |
| `/wfm unbound` | Toggle whether the default rule also takes BoE |
| `/wfm confirm` | Toggle the confirmation dialog |
| `/wfm ui` | Toggle the panel |
| `/wfm debug` | Toggle debug output |
| `/wfm version` | Version, target WoW version, client interface |

## Rules

Rules are evaluated top to bottom and **the first match wins**. Whatever matches nothing goes to the character's default recipient.

| Field | Effect |
|---|---|
| Recipient | Required, `Name` or `Name-Realm` |
| Category / subcategory | e.g. Armor / Plate — names come localized from the client |
| Binding | Any / Warbound / Unbound (BoE) |
| Minimum quality | Poor … Heirloom |
| Only these items | Item list; **when filled, the filters above no longer apply** |
| Scope | All characters, or this character only |

*"Always send item X to Y":* new rule → recipient `Y` → drag the item into "Only these items" → Apply.

*"All armor, warbound or unbound, to Z":* new rule → recipient `Z` → category `Armor` → binding `Any` → Apply. ("Any" covers exactly warbound + unbound; soulbound is never included.)

Rules can be disabled individually and reordered with `^` / `v` — order decides when they overlap. A character-scoped rule remembers its owner; on other characters it is inactive and shown greyed out with the owner's name.

### Self-lock

When a rule points at the character currently logged in, the item stays put and evaluation stops. A single account-wide rule is therefore enough:

| Logged in as | Pet charm | Source |
|---|---|---|
| Warrior | → Collector | rule |
| Miner | → Collector | rule |
| **Collector** | **stays put** | self-lock |

The stop matters: falling through to the next rule could let a broader rule mail the items straight back out again.

**Scope does not weaken this.** A rule that names this character holds its delivery even when the rule itself does not fire here — for example a rule scoped to *another* character:

| | |
|---|---|
| Rule, scoped to **Bankchar** | armor → **Collector** |
| Logged in as Bankchar | armor → Collector, the rule fires |
| Logged in as **Collector** | **armor stays put**, although the rule is inert here |

Without that, the rule would be invisible on Collector, the armor it had just delivered would fall through to the default recipient, and the next run would mail it straight back.

## Hold list

One list with an amount column, covering both "never send" and "keep some":

| Entry | Meaning |
|---|---|
| Amount **empty** | never send |
| Amount **20** | 20 stay, the rest goes out |

`0` reads as empty. New entries start empty, because that is the safe reading when you drag an item onto a hold list.

The amount is a **lower bound on the bag count**, not a running counter:

```
available(itemID) = GetItemCount(itemID) - held(itemID)
```

Attached items have already left the bags, so the value shrinks on its own and lands exactly on the held amount. Nothing has to be tracked across steps, and an interrupted or resumed run cannot overshoot.

**Partial stacks:** if a whole stack does not fit the budget, `C_Container.SplitContainerItem` splits off exactly the allowed amount. `ClearCursor()` always follows, so a failed drop returns the pieces to the bag instead of leaving them on the cursor.

250 potions in stacks of 100/100/50, keep 20:

| Step | Stack | Budget | Action | Bags after |
|---|---|---|---|---|
| 1 | 100 | 230 | whole stack | 150 |
| 2 | 100 | 130 | whole stack | 50 |
| 3 | 50 | 30 | **split 30** | 20 |
| 4 | — | 0 | done | 20 |

## Gold

```
sendable = GetMoney() - reserve - postage
```

Postage (30 copper) is deducted on top of the reserve, so the reserve is left exactly intact. If the result is ≤ 0 the button stays disabled. Default reserve: **100 gold**.

## Detection logic

Three stages, first unambiguous answer wins. The result is always exactly one of `warbound` / `unbound` / `soulbound`:

1. `C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc)` combined with `C_Item.IsBound(loc)` — language-independent and authoritative. Soulbound items are never allowed in the warband bank, warbound ones always are.
2. `bindType` (field 14 from `GetItemInfo`) against `Enum.ItemBind` `ToWoWAccount` / `ToBnetAccount` / `*UntilEquipped` (numerically 7/8/9).
3. Tooltip scan via `C_TooltipInfo.GetBagItem` against Blizzard's own localized GlobalStrings. No hardcoded text fragments.

Equipped "warbound until equipped" pieces are soulbound and already drop out at stage 1.

## Safety

- Recipient names go through a strict whitelist that blocks `|` escapes, control characters, quotes and backslashes — before every `SendMail`, including rules loaded from SavedVariables
- Sending to yourself is refused
- Confirmation dialog with the full distribution plan (can be disabled)
- Hard cap of 25 mails per run
- Postage checked against `GetMoney()` before every `SendMail`
- `SetSendMailCOD(0)` and `SetSendMailMoney(0)` enforced on item runs — never gold, never COD
- Aborts on `MAIL_FAILED` and as soon as the mailbox closes
- Bags are rescanned and rerouted before **every single** attachment, so stale slot indices are structurally impossible
- Three failed attempts per item, then skip — no endless loop
- On partial stacks the cursor is checked against the **itemID**, not the link string, and cleared unconditionally afterwards
- Gold specifically: the amount is recalculated immediately before `SendMail` and never taken from the dialog; the recipient is re-validated against the whitelist on click; the transfer aborts if items are attached or an item run is in progress, and vice versa
- No network access, no `loadstring`, no addon communication

## Versioning

```
12 . 1 . 0 . 2
└──┬──┘   │   └── addon build counter
   │      └────── WoW patch
   └───────────── WoW version this copy was built for
```

The first three digits are the WoW version this copy was written against — here **12.1.0** (Midnight, "Curse of Ula'tek", interface `120100`). Only the fourth digit counts up for add-on changes.

The value is not decoration: on load the add-on compares it against `select(4, GetBuildInfo())`.

| Difference | Behavior |
|---|---|
| none | silent |
| patch only (e.g. client 12.1.7) | silent on login, yellow note on `/wfm version` |
| major or minor (e.g. 12.2.0) | red warning on login |

A pure patch bump is not an error, just a hint to update the `## Interface:` line. A branch change means: check the API.

## Releasing

Tagging is the whole process. [`release.yml`](.github/workflows/release.yml) runs [BigWigs' packager](https://github.com/BigWigsMods/packager) on any `v*` tag, builds the zip according to [`.pkgmeta`](.pkgmeta) and uploads it to CurseForge:

```bash
git tag v12.1.0.2 && git push origin v12.1.0.2
```

The tag name decides the release type: a tag containing `alpha` or `beta` is uploaded as such, anything else as a full release. Keep the tag and `## Version:` in the `.toc` in step — nothing checks that for you.

Two things have to exist once, and both can only be created by the project owner:

| What | Where |
|---|---|
| `## X-Curse-Project-ID: <id>` in the `.toc` | the id sits in the *About Project* box on the CurseForge page; the line is already there, commented out |
| Repository secret `CF_API_TOKEN` | generate at [curseforge.com/account/api-tokens](https://www.curseforge.com/account/api-tokens), then add it under *Settings → Secrets and variables → Actions* |

Until both exist the workflow still runs and still builds the zip — it only skips the upload. It is therefore safe to have in place beforehand.

`.pkgmeta` keeps `tools/`, `screenshots/`, `logo.png` and `curseforge.md` out of the package. `curseforge.md` is the text for the project page itself, not something to ship to players.

GitHub releases stay manual. Adding `GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}` to the workflow's `env:` block, plus `contents: write` under `permissions:`, hands those to the packager as well.

## Languages

`DE`, `EN`, `FR`, `ES` (ES/MX), `IT`. The strings live as XML in `lang\`:

```
lang\enUS.xml   lang\deDE.xml   lang\frFR.xml
lang\esES.xml   lang\esMX.xml   lang\itIT.xml
```

The TOC uses the `[TextLocale]` path variable:

```
lang\enUS.xml
lang\[TextLocale].xml
```

The client substitutes its own locale code and loads exactly one translation next to the English base. A missing language falls back to English — no error, no special case. A missing single key resolves to the key name instead of `nil`.

The XML files are real `<Ui>` documents with a `<Script>` block calling a temporary global registrar that `Core.lua` sets back to `nil` once loading is done.

**Do not edit them by hand.** `tools/build_lang.py` generates all six from one source and refuses to write a file that is missing keys, has unknown keys, or whose format placeholders (`%d`, `%s`) differ from the English base.

## Architecture

```
Warbrand-Fast-Mail.toc
Locale.lua           language registry (metatable, fallback)
lang\*.xml           DE/EN/FR/ES/IT, loaded via [TextLocale]
Lib/Util.lua         output, validation, API compat shims      (stateless)
Lib/Widgets.lua      windows, dropdown, scoped item list       (UI toolkit)
Lib/Categories.lua   category tree from the auction house      (read-only)
Lib/Hold.lua         hold list, partial-stack budget           (read-only)
Lib/Scanner.lua      bag scan, binding state, metadata         (read-only)
Lib/Rules.lua        rule matching, resolution, plan           (pure logic)
Lib/Mailer.lua       state machine, multiple recipients        (writing)
Lib/Gold.lua         gold transfer with reserve                (writing)
Core.lua             SavedVariables, public API, slash commands
UI.lua               panel at the mailbox
Config.lua           rules, hold and settings windows
tools/build_lang.py  generator for lang\*.xml (not loaded in game)
```

`Lib/` is freely reusable. `Util` and `Widgets` have no dependencies, `Hold` depends only on `Util`, `Scanner` on `Util` + `Hold`. `Widgets` deliberately avoids `UIDropDownMenu`, `FauxScrollFrame` and the newer `MenuUtil` API — Blizzard has already rebuilt both generations.

## SavedVariables

- `WarbrandFastMailDB` — account-wide: rules, hold list, default recipient, gold recipient, reserve, window positions
- `WarbrandFastMailCharDB` — per character: default recipient, gold recipient, own hold list

## Support

If this add-on saved you time, you can support further development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=6CDEVZGJWTNQQ)

## License

MIT © 2026 Thomas Weirich
