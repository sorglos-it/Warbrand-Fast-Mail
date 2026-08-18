# Warbrand-Fast-Mail

**Empties your bags into the mailbox by rule.**

**Fully translated: Deutsch · English · Español · Français · Italiano.** The add-on follows your game client — there is no language setting to find.

Open a mailbox and a panel appears beside it showing exactly where every item is going — "7 × Bankchar", "3 × Muli", "5 without recipient", "2 held". One button sends them, in batches of 12, to as many different characters as your rules name.

It moves **warbound** and **unbound (BoE)** items. Soulbound gear is never touched, and that is determined from the API rather than from tooltip text, so it does not depend on your client language.

Gold works the same way: everything **above a reserve you set** goes to a fixed character.

---

## Features

- **Rule engine** — a top-down list, first matching rule wins; anything unmatched goes to the character's default recipient
- **Many recipients per run** — the plan is computed once and mailed in 12-item batches, up to a hard cap of 25 mails
- **Two scopes everywhere** — rules, hold list and both default recipients exist account-wide *and* per character, the character value winning
- **Hold list with quantities** — empty means *never send*, `20` means *keep 20 and send the rest*, including splitting a partial stack
- **Self-lock** — when a rule names the character you are on, the item stays put. One rule "pet charms → Collector" sends on every character and is inert on Collector itself, so no counter-rule is needed — and a delivery is never mailed back out, whichever character the rule belongs to
- **Gold with a reserve** — postage is deducted on top of the reserve, so the reserve is left exact
- **Categories from the auction house** — the category dropdown is built from Blizzard's own browse tree, localized and always current
- **Five languages** — German, English, Spanish (ES/MX), French, Italian, picked from your client
- **No network access**, no `loadstring`, no addon communication

---

## Getting started

1. Set a default recipient: `/wfm target <name>` for this character, or `/wfm target global <name>` for all of them.
2. Add rules for anything that should go elsewhere: `/wfm rules`.
3. Open a mailbox and press **Send** on the panel, or type `/wfm send`.

A confirmation dialog with the full plan appears first. `/wfm confirm` turns it off.

Both `/warbrand-fast-mail` and `/wfm` work.

---

## Commands

| Command | Effect |
|---|---|
| `/wfm send` | Run all rules |
| `/wfm force <name>` | Ignore rules, send everything to one recipient |
| `/wfm target [global] <name>` | Default recipient |
| `/wfm gold` | Send gold minus the reserve |
| `/wfm goldtarget [global] <name>` | Gold recipient |
| `/wfm reserve <gold>` | Set the reserve (default 100) |
| `/wfm rules` | Rules window |
| `/wfm hold` | Hold list |
| `/wfm hold <itemID> 20` | Keep 20, send the rest |
| `/wfm hold <itemID> -` | Delete the entry |
| `/wfm list` | Print the distribution plan to chat |
| `/wfm settings` | Settings |
| `/wfm version` | Version and client interface |

`/wfm` on its own prints the full list.

---

## Rules

Rules are evaluated top to bottom and **the first match wins**. Each one takes a recipient, optionally a category and subcategory, a binding type, a minimum quality — or an explicit item list, which overrides all the filters above it. Rules can be disabled individually, reordered, and scoped to a single character.

*"Always send item X to Y":* new rule → recipient `Y` → drag the item into "Only these items" → Apply.

*"All armor, warbound or unbound, to Z":* new rule → recipient `Z` → category `Armor` → binding `Any` → Apply.

Items are added to a list by **dragging them onto it**. A single entry is removed with the red `x` on its row; emptying the whole list asks for confirmation first.

---

## Hold list

One list covering both "never send" and "keep some":

| Entry | Meaning |
|---|---|
| Amount **empty** | never send |
| Amount **20** | 20 stay, the rest goes out |

The amount is a floor on the bag count, not a running counter, so an interrupted or resumed run can never overshoot. If a whole stack does not fit the budget, exactly the allowed amount is split off and mailed.

---

## Safety

Sending mail automatically is only acceptable if it cannot go wrong quietly:

- Recipient names pass a strict whitelist that blocks `|` escapes, control characters, quotes and backslashes — before **every** send, including rules loaded from saved variables
- Sending to yourself is refused
- Hard cap of 25 mails per run, postage checked before every mail
- COD and attached money forced to zero on item mails — never gold by accident, never cash on delivery
- Aborts on a failed send and the moment the mailbox closes
- Bags are rescanned and rerouted before **every single** attachment, so stale slot indices are impossible by construction
- Three failed attempts per item, then it is skipped — no endless loop
- Gold specifically: the amount is recalculated immediately before sending and never taken from the dialog, the recipient is re-validated on click, and the transfer refuses to run while items are attached

---

## Languages

Five languages in six locale files, picked from your game client automatically:

| Language | Client locale |
|---|---|
| Deutsch | `deDE` |
| English | `enUS` / `enGB` |
| Español (España) | `esES` |
| Español (México) | `esMX` |
| Français | `frFR` |
| Italiano | `itIT` |

**Everything** is translated, not just the buttons: every window, every chat message, every tooltip, the confirmation dialogs and the complete slash-command help. All six files carry the same 161 strings, checked against the English base so no language can quietly fall behind.

Category names, subcategories and item qualities are not translated by hand at all — they come localized straight from the client, so they always read exactly as they do in your auction house.

Playing in a language that is not on the list? Nothing breaks: the add-on falls back to English.

**Warbrand-Fast-Mail** is a brand and stays untranslated everywhere.

---

## Requirements

World of Warcraft **Retail**, interface `120100` (patch 12.1.0). No dependencies.

---

Full documentation, source and issue tracker: **https://github.com/sorglos-it/Warbrand-Fast-Mail**

Released under the MIT license.
