# Warbrand-Fast-Mail

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CurseForge](https://img.shields.io/badge/CurseForge-Warbrand--Fast--Mail-F16436?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/warbrand-fast-mail)
[![World of Warcraft](https://img.shields.io/badge/World%20of%20Warcraft-Retail-00AEFF?logo=battledotnet&logoColor=white)](#requirements)
[![Interface](https://img.shields.io/badge/interface-120100-0b7285.svg)](#versioning)
[![Languages](https://img.shields.io/badge/UI-DE%20%7C%20EN%20%7C%20ES%20%7C%20FR%20%7C%20IT-4c1.svg)](#languages)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white)](#development)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C.svg?logo=paypal)](https://www.paypal.com/donate/?hosted_button_id=6CDEVZGJWTNQQ)

A World of Warcraft add-on that **empties your bags into the mailbox by rule**. Open a mailbox and a panel next to
it shows where every item will go — "7 × Bankchar", "3 × Muli", "5 without recipient", "2 held" — and one button
sends them. Warbound and unbound (BoE) items only, soulbound gear is never touched; gold above a reserve can go along.

| Folder | Purpose | Language | Start | Build |
|---|---|---|---|---|
| `apps/desktop` | the add-on for the WoW Retail client | Lua 5.1, XML | open a mailbox in game, or type `/wfm` | push a tag `v<version>` → [`release.yml`](.github/workflows/release.yml) packs `Warbrand-Fast-Mail-v<version>.zip` and uploads it to CurseForge |

## Start in 3 steps

1. **Install:** in the CurseForge app search for *Warbrand-Fast-Mail* and click *Install*. Without the app, see
   [Installing from the zip](#installing-from-the-zip).
2. **Open it in game:** start the game (restart it if it was running) and open any mailbox — the panel appears to the
   right of it. The entry in the AddOn Compartment (the icon next to the minimap) opens the rules window.
3. **First rule:** set where everything goes by default with `/wfm target <name>` (this character) or
   `/wfm target global <name>` (all characters). Add rules for anything that should go elsewhere with `/wfm rules`,
   then press **Send** on the panel. A confirmation with the full plan comes first; `/wfm confirm` switches it off.

## Features

- **Rules** — a top-down list, the first matching rule wins; anything unmatched goes to the default recipient
- **Many recipients per run** — the plan is computed once and mailed in batches of 12 items, at most 25 mails per run
- **Two scopes everywhere** — rules, hold list, reserve and both default recipients exist account-wide and per
  character; the character value wins
- **Hold list with amounts** — empty means *never send*, `20` means *keep 20 and send the rest*, splitting a stack if
  needed
- **Self-lock** — when a rule names the character you are on, the item stays put, so a delivery is never mailed
  straight back out
- **Gold with a reserve** — everything above the reserve goes to a fixed character; postage is deducted on top, so the
  reserve stays exact
- **Categories from the auction house** — the category list comes from Blizzard's own browse tree, localized and current
- **Five languages** — German, English, Spanish (ES/MX), French, Italian, picked from the client
- **No network access** — no `loadstring`, no add-on communication, nothing leaves your client

## Requirements

World of Warcraft **Retail**, interface `120100` (patch 12.1.0); `120007`, `120005` and `120001` are declared as
compatible too. Nothing else — no libraries, no other add-ons.

## Installing from the zip

1. Download the zip from [CurseForge](https://www.curseforge.com/wow/addons/warbrand-fast-mail) or
   [Releases](https://github.com/sorglos-it/Warbrand-Fast-Mail/releases) and unpack it.
2. Copy the `Warbrand-Fast-Mail` folder into the AddOns folder:

   | OS | Path |
   |---|---|
   | Windows | `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\` |
   | macOS | `/Applications/World of Warcraft/_retail_/Interface/AddOns/` |

   The folder name and the `.toc` name have to match, or the game does not list the add-on:
   `...\Interface\AddOns\Warbrand-Fast-Mail\Warbrand-Fast-Mail.toc`
3. Start or restart the game. `/wfm version` shows the add-on version, the WoW version it was built for and your
   client's interface number.

If the interface number differs from `120100`, the first entry of `## Interface:` and the first three digits of
`## Version:` in `Warbrand-Fast-Mail.toc` are due for an update — see [Versioning](#versioning).

## Update

- **CurseForge app:** click *Update*.
- **Zip:** delete the old `Warbrand-Fast-Mail` folder in `AddOns`, then copy in the new one.

Your settings stay: they live in the game's SavedVariables — `WarbrandFastMailDB` (account-wide: rules, hold list,
default and gold recipient, reserve, window positions) and `WarbrandFastMailCharDB` (per character: default and gold
recipient, reserve, own hold list).

## Slash commands

`/wfm` and `/warbrand-fast-mail` do the same; `/wfm` alone lists the commands in game. There is deliberately no
`/warbrand` — another add-on could claim that name, and the last one registered wins.

| Command | Effect |
|---|---|
| `/wfm send` | Run all rules (mailbox open) |
| `/wfm sendall` | Items and gold in one run — the gold rides on the last mail to its recipient, one postage less |
| `/wfm force <name>` | Ignore the rules, send everything to one recipient |
| `/wfm target <name>` | Default recipient, this character (`target global <name>`: all characters) |
| `/wfm gold` | Send gold minus the reserve |
| `/wfm goldtarget <name>` | Gold recipient, this character (`goldtarget global <name>`: all characters) |
| `/wfm reserve <gold>` | Reserve for this character (`reserve global <gold>`: all characters; default 100) |
| `/wfm reserve -` | This character uses the account-wide reserve again |
| `/wfm rules` | Rules window |
| `/wfm hold` | Hold list window (also `/wfm ignore`, `/wfm keep`) |
| `/wfm hold <itemID>` | Show the entry for one item |
| `/wfm hold <itemID> 20` | Keep 20, send the rest (`hold char <itemID> 20`: this character only) |
| `/wfm hold <itemID> -` | Delete the entry |
| `/wfm check <itemID>` | The numbers behind a hold entry |
| `/wfm list` | Print the distribution plan to chat |
| `/wfm settings` | Settings window |
| `/wfm unbound` | Whether the default rule also takes unbound (BoE) items |
| `/wfm confirm` | Confirmation dialog on/off |
| `/wfm ui` | Panel on/off |
| `/wfm debug` | Debug output on/off |
| `/wfm version` | Version, target WoW version, client interface |

## Rules

Rules are checked top to bottom and **the first match wins**. Whatever matches nothing goes to the default recipient.

| Field | Effect |
|---|---|
| Recipient | Required, `Name` or `Name-Realm` |
| Category / subcategory | e.g. Armor / Plate — names come localized from the client |
| Binding | Any / Warbound / Unbound (BoE) — "Any" means exactly these two, never soulbound |
| Minimum quality | Poor … Heirloom |
| Only these items | Item list; **when filled, the filters above no longer apply** |
| Scope | All characters, or this character only |

*"Always send item X to Y":* new rule → recipient `Y` → drag the item onto "Only these items" → Apply.

*"All armor, warbound or unbound, to Z":* new rule → recipient `Z` → category `Armor` → binding `Any` → Apply.

Items are added to a list by dragging them onto it; the red `x` on a row removes one entry, emptying a whole list asks
first. Rules can be switched off one by one and reordered with `^` / `v` — the order decides when they overlap. A
character rule remembers its owner and shows greyed out, with the owner's name, on other characters.

### Self-lock

When a rule names the character you are logged in with, the item stays put and no further rule is tried — otherwise a
broader rule could mail the delivery straight back out. One account-wide rule is therefore enough:

| Logged in as | Pet charm | Why |
|---|---|---|
| Warrior | → Collector | rule |
| Miner | → Collector | rule |
| **Collector** | **stays put** | self-lock |

This holds even for a rule that does not fire on this character. A rule scoped to **Bankchar** that sends armor to
**Collector** mails the armor when you play Bankchar — and keeps it put when you play Collector, although the rule is
inactive there. Without that, the armor would fall through to Collector's default recipient and go straight back.

## Hold list

One list with an amount column covers "never send" and "keep some":

| Amount | Meaning |
|---|---|
| empty (or `0`) | never send |
| `20` | 20 stay, the rest goes out |

New entries start empty — the safe reading when you drag an item onto a hold list. The amount is a floor for your
bags, not a running counter: before every attachment the add-on counts the bags again and lets only what is above the
amount go, so an interrupted or resumed run can never send too much. If a whole stack does not fit, exactly the
allowed amount is split off: 250 potions in stacks of 100/100/50 with 20 held sends 100, 100 and a split-off 30, and
20 stay.

## Gold

`sendable = GetMoney() − reserve − postage`. Postage (30 copper) is deducted on top, so the reserve stays exact. If
nothing is left, the button stays disabled. Default reserve: **100 gold**.

## Safety

Mailing automatically is only acceptable if it cannot go wrong quietly:

- Recipient names pass a strict whitelist (no `|` escapes, control characters, quotes or backslashes) before **every**
  send, including rules loaded from SavedVariables
- Sending to yourself is refused
- Confirmation dialog with the full plan (can be switched off)
- At most 25 mails per run; postage is checked against your money before every mail
- Item mails always carry 0 money and 0 COD — never gold by accident, never cash on delivery
- Stops on a failed send and the moment the mailbox closes
- The bags are rescanned before **every single** attachment, so stale slot numbers cannot happen
- Three failed attempts per item, then it is skipped — no endless loop
- Split stacks are checked by item ID on the cursor, and the cursor is always cleared afterwards
- Gold: the amount is recalculated right before sending, never taken from the dialog; the recipient is checked again on
  click; gold and item runs never overlap

**Warbound or soulbound?** The add-on asks the game, not the tooltip text, so it works in every client language:
first whether the item may go into the warband bank (`C_Bank.IsItemAllowedInBankType` with `C_Item.IsBound`), then
its bind type from `GetItemInfo`, and only as a last resort the tooltip against Blizzard's own localized strings.
"Warbound until equipped" pieces that have been equipped are soulbound and stay.

## Versioning

```
12 . 1 . 0 . 5
└──┬──┘   │   └── add-on build counter
   │      └────── WoW patch
   └───────────── WoW version this copy was built for
```

The first three numbers are the WoW version the add-on was written against — here **12.1.0** (interface `120100`);
only the fourth counts add-on changes. On login the add-on compares them with the running client:

| Difference | Behavior |
|---|---|
| none | silent |
| patch only (e.g. client 12.1.7) | silent on login, yellow note on `/wfm version` |
| major or minor (e.g. 12.2.0) | red warning on login |

A patch difference only means the `## Interface:` line wants a refresh; a branch change means: check the API.

## Languages

German, English, French, Spanish (ES and MX) and Italian — every window, chat message, tooltip and the slash-command
help. The game loads `lang\enUS.xml` plus the file for its own language through the `[TextLocale]` path in the `.toc`;
any other language falls back to English, and a missing single text shows its key instead of an error. Category names,
subcategories and item qualities come from the client itself. "Warbrand-Fast-Mail" is a name and stays untranslated.

## Development

```
apps/desktop/                  the add-on, packaged as Warbrand-Fast-Mail/
├── Warbrand-Fast-Mail.toc     load order, metadata, ## Version:
├── VERSION                    same number as ## Version:
├── Core.lua                   SavedVariables, public API, slash commands
├── classes/                   Locale (language registry), Util, Widgets (window toolkit),
│                              Categories, Hold, Scanner, Rules, Mailer, Gold
├── views/                     UI.lua (mailbox panel), Config.lua (rules, hold, settings windows)
└── lang/                      enUS, deDE, esES, esMX, frFR, itIT (generated)
docs/curseforge.md             text of the CurseForge project page
assets/                        logo and screenshots for the project page
tools/build_lang.py            generator for apps/desktop/lang/*.xml
```

**Try a change in game:** copy the *contents* of `apps/desktop` into
`World of Warcraft\_retail_\Interface\AddOns\Warbrand-Fast-Mail\` (`VERSION` may stay out) and type `/reload`. A
changed `.toc` or a new file needs a restart of the game.

**Languages:** do not edit `apps/desktop/lang/*.xml` by hand. `python tools/build_lang.py` writes all six from one
table and refuses to write a file with missing or unknown keys or `%d`/`%s` placeholders that differ from English. It
needs the English and German base tables `tools/en_base.json` and `tools/de_base.json`, which are not in the
repository yet.

**Modules:** `classes/` is freely reusable. `Util` and `Widgets` have no dependencies, `Hold` needs only `Util`,
`Scanner` needs `Util` and `Hold`. `Widgets` deliberately avoids `UIDropDownMenu`, `FauxScrollFrame` and the newer
`MenuUtil` — Blizzard has rebuilt both generations already.

**Releasing:** raise `## Version:` in `apps/desktop/Warbrand-Fast-Mail.toc` and `apps/desktop/VERSION` to the same
number, commit and push, then tag and push the tag:

```bash
git tag v12.1.0.6
git push origin v12.1.0.6
```

Two lines on purpose: `&&` does not work in Windows PowerShell 5.1, and this form runs in bash, PowerShell 5.1 and 7.
The workflow refuses to package when tag, `## Version:` and `VERSION` disagree. It then runs
[BigWigs' packager](https://github.com/BigWigsMods/packager), which builds the zip as [`.pkgmeta`](.pkgmeta) says —
the contents of `apps/desktop` as `Warbrand-Fast-Mail/`, without the repository files — uploads it to CurseForge
(project `1655846`) and attaches it to a GitHub release. A tag containing `alpha` or `beta` is uploaded as such,
anything else as a full release. The upload token `CF_API_TOKEN` is an *environment* secret of the `curseforge`
environment, which is why the job declares `environment: curseforge` — without it the token stays empty and the upload
is skipped silently.

## License

MIT © 2026 Sorglos Thomas Weirich — see [LICENSE](LICENSE).

## Donate via PayPal

If this add-on saves you time, you can support further development:

**[➡️ Donate via PayPal](https://www.paypal.com/donate/?hosted_button_id=6CDEVZGJWTNQQ)**
