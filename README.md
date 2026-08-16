# Warbrand-Fast-Mail

WoW-Addon (Retail). Verteilt kriegsmeutengebundene und ungebundene Gegenstände
regelbasiert per Post an mehrere Empfänger — in 12er-Paketen, vollautomatisch.

## Installation

```
World of Warcraft\_retail_\Interface\AddOns\Warbrand-Fast-Mail\
```

`/reload` oder Client neu starten.
Interface-Version prüfen: `/wfm version` im Spiel (oder
`/dump select(4, GetBuildInfo())`). Weicht sie ab, die erste Zahl in
`## Interface:` **und** die ersten drei Stellen von `## Version:` nachziehen.

## Was ist neu in 12.1.0.1

### Bugfix: Button „Behalten" ohne Funktion

Beim Umbau des Einstellungsfensters wurden `BuildKeepWindow` und
`Config:ToggleKeep` mit ausgeschnitten — der Button rief eine `nil`-Methode.
Er entfällt jetzt komplett, die Behaltemengen sind in die Ignorierliste
gewandert.

### Eine Liste statt zwei: Behalteliste

Ignorieren und Behalten waren dasselbe Problem in zwei Listen. Jetzt eine,
mit Mengenspalte:

| Eintrag | Bedeutung |
|---|---|
| Menge **leer** | nie verschicken (das alte „Ignorieren") |
| Menge **20** | 20 bleiben liegen, der Rest geht raus |

`0` wird als „leer" gelesen — „behalte 0" wäre nur ein Eintrag, der nichts tut.
Neue Einträge starten auf **leer**, weil das die sichere Lesart ist, wenn man
ein Item auf eine Behalteliste zieht.

Alte Profile werden automatisch zusammengeführt: `ignore` → `true`,
`keep` → Zahl. Die alten Tabellen werden dabei entfernt.

### Suche in Behalteliste und Regeln

Beide Fenster haben ein Suchfeld. Die Behalteliste filtert nach Itemname und
Item-ID, die Regelliste zusätzlich nach Name, Empfänger, Kategorie, Besitzer
und den Items in der Regel.

Itemnamen sind nicht immer im Client-Cache. Fehlt einer, fordert das Addon ihn
per `C_Item.RequestLoadItemDataByID` an und aktualisiert die offene Liste bei
`GET_ITEM_INFO_RECEIVED` — die Suche nach Namen funktioniert also auch für
Items, die beim Öffnen noch nicht geladen waren.

### Kategorien aus dem Auktionshaus

`Enum.ItemClass` schleppt tote Einträge mit (Projektile, Köcher, zwei
`*Obsolete`-Klassen) und `GetItemClassInfo` liefert dafür brav lokalisierte
Namen — die landeten bisher im Dropdown, obwohl kein aktuelles Item sie je
trifft.

Blizzard pflegt mit `AuctionCategories` bereits den Browse-Baum von allem,
was tatsächlich handelbar ist. Das Addon lädt `Blizzard_AuctionHouseUI` bei
Bedarf nach und leitet Kategorien und Unterkategorien daraus ab — lokalisiert
und immer auf Patch-Stand.

Eine Kategorie wird nur übernommen, wenn **alle** ihre Filter dieselbe
Klasse nennen; gemischte werden verworfen statt geraten.

Fällt das Nachladen aus, greift eine explizite Liste lebender Item-Klassen
(oben in `Lib/Categories.lua`, eine Zeile zum Nachpflegen).

### Gegenregel: war schon drin, jetzt sichtbar

Die automatische Selbst-Sperre gibt es seit 12.1.0.0: zeigt die **gewinnende**
Regel auf den laufenden Charakter, bleibt der Gegenstand liegen und die
Auswertung stoppt. Für `[Ehrenabzeichen] → Sammelchar` als globale Regel
braucht es also keine Gegenregel — auf dem Sammelchar feuert sie nicht, es
entsteht kein Porto.

Neu ist nur, dass man es **sieht**: solche Regeln stehen in der Liste mit
`(hier inaktiv)` und erklären sich im Tooltip. Vorher sah das aus wie ein
Defekt.

### Mehrsprachig über den Client

`DE`, `EN`, `FR`, `ES` (ES/MX), `IT`. Die Strings liegen als XML in `lang\`:

```
lang\enUS.xml   lang\deDE.xml   lang\frFR.xml
lang\esES.xml   lang\esMX.xml   lang\itIT.xml
```

Der TOC nutzt die Pfadvariable `[TextLocale]`:

```
lang\enUS.xml
lang\[TextLocale].xml
```

Der Client setzt dafür seinen eigenen Locale-Code ein und lädt genau eine
Übersetzung neben der englischen Basis. Fehlt eine Sprache, bleibt es bei
Englisch — kein Fehler, keine Sonderbehandlung. Fehlt ein einzelner
Schlüssel, liefert die Metatabelle den Schlüsselnamen statt `nil`.

Die XML-Dateien sind echte `<Ui>`-Dokumente mit einem `<Script>`-Block; die
`<Script>`-Blöcke rufen einen temporären globalen Registrar, den `Core.lua`
nach dem Laden wieder auf `nil` setzt.

**Nicht von Hand editieren.** `tools/build_lang.py` erzeugt alle sechs Dateien
aus einer Quelle und bricht ab, wenn eine Sprache Schlüssel fehlen, unbekannte
Schlüssel hat oder die Format-Platzhalter (`%d`, `%s`) von der englischen Basis
abweichen.

### Version bleibt stehen

Während der Entwicklung bleibt `12.1.0.1` fest. Die vierte Stelle wandert
erst bei einer Veröffentlichung.

## Versionsschema

```
12 . 1 . 0 . 5
└──┬──┘   │   └── Build-Zähler des Addons
   │      └────── WoW-Patch
   └───────────── WoW-Version, für die gebaut wurde
```

Die ersten drei Stellen sind die WoW-Version, gegen die diese Kopie geschrieben
wurde — hier **12.1.0** (Midnight, „Curse of Ula'tek", Interface `120100`). Nur
die vierte Stelle zählt bei Addon-Änderungen hoch.

Der Wert ist keine Deko: Beim Laden vergleicht das Addon ihn gegen
`select(4, GetBuildInfo())`.

| Abweichung | Verhalten |
|---|---|
| keine | still |
| nur Patch (z. B. Client 12.1.7) | still beim Login, gelber Hinweis bei `/wfm version` |
| Major oder Minor (z. B. 12.2.0) | rote Warnung beim Login |

Ein reiner Patch-Sprung ist kein Fehler, sondern nur ein Wink, die
`## Interface:`-Zeile nachzuziehen. Ein Zweigwechsel dagegen heißt: API prüfen.

`/wfm version` zeigt Version, Ziel-WoW-Version, Client-Version und die rohe
Interface-Nummer.

## Was war neu in 1.5.0 (jetzt 12.1.0.5)

### Beide Standard-Empfänger, beide Ebenen

Bisher lag der Gegenstands-Empfänger nur am Panel und der Gold-Empfänger nur
account-weit in den Einstellungen. Jetzt haben **beide** dieselbe zweistufige
Auflösung wie Regeln und Ignorierliste:

| Ebene | Speicher | |
|---|---|---|
| Nur dieser Charakter | `Warbrand-Fast-MailCharDB` | **schlägt** die untere Ebene |
| Alle Charaktere | `Warbrand-Fast-MailDB` | greift, wenn oben leer |

Das Einstellungsfenster ist entsprechend in zwei beschriftete Blöcke geteilt.
Leeres Feld = Ebene darunter benutzen. Unten steht immer, was gerade **wirksam**
ist.

Damit reicht für Twinks eine einmalige account-weite Einstellung, und einzelne
Charaktere weichen davon ab, wo nötig:

| Charakter | Char-Wert | Gegenstände | Gold |
|---|---|---|---|
| Krieger | — | Bankchar *(global)* | Goldchar *(global)* |
| Twink | `Twinkbank` | Twinkbank *(char)* | Goldchar *(global)* |
| **Bankchar** | — | **bleibt liegen** | Goldchar *(global)* |
| **Goldchar** | — | Bankchar *(global)* | **inaktiv** |

Auf dem Zielcharakter selbst wird der eigene Name automatisch inert — die
account-weite Einstellung kann also überall stehen bleiben.

Zeigt der Charakter-Wert auf ihn selbst, wird das beim Speichern abgelehnt
(sinnlos). Account-weit ist es erlaubt, weil es dort genau auf einem Charakter
inert sein *soll*.

`Übernehmen` validiert erst alle vier Empfängerfelder und schreibt danach — ein
Tippfehler in einem Feld kann den Rest nicht halb angewendet zurücklassen.

Schnellbefehle: `/wfm target <name>` (dieser Char), `/wfm target global <name>`,
dito `/wfm goldtarget`. Ohne Argument zeigen beide alle drei Werte.

## Was war neu in 1.4.0 (jetzt 12.1.0.4)

### Bugfix: zweites Fenster öffnete hinter dem ersten

Regeln, Ignorieren, Behalten und Einstellungen waren voneinander unabhängige
Frames in derselben Strata (`HIGH`, wie `MailFrame`). `SetToplevel(true)` hebt
ein Fenster nur beim **Klick** an, nicht beim Anzeigen — das zweite Fenster
erschien also darunter, und das erste blieb offen.

Neu: alle vier gehören zu einer exklusiven Gruppe. Beim Öffnen werden die
anderen geschlossen, das neue kommt in Strata `DIALOG` und bekommt `:Raise()`.

### Geltungsbereiche

Regeln, Ignorierliste und Behaltemengen haben jetzt je zwei Ebenen:

| | Speicher | Wirkung |
|---|---|---|
| **A** – Alle Charaktere | `Warbrand-Fast-MailDB` | gilt überall |
| **C** – Nur dieser Charakter | `Warbrand-Fast-MailCharDB` | gilt nur hier, **schlägt A** |

In den Listen steht das Kürzel links vor jedem Eintrag; ein Klick darauf schiebt
den Eintrag zwischen den Ebenen hin und her. Das Dropdown „Neue Einträge"
bestimmt nur, wo *neu hinzugefügte* Items landen. `Leeren` räumt ausschließlich
die dort gewählte Ebene.

Regeln bekommen das Feld **Geltung**. Eine Char-Regel merkt sich ihren Besitzer;
auf fremden Charakteren ist sie inaktiv und wird in der Liste grau mit dem
Besitzernamen angezeigt. Erneutes Speichern stiehlt sie nicht — der Besitzer
bleibt erhalten.

### Selbst-Sperre: der Sammelchar-Fall

Zeigt die **gewinnende** Regel auf den Charakter, der gerade läuft, bleibt der
Gegenstand liegen und die Auswertung stoppt. Damit braucht der Sammelchar
**keinen** eigenen Ignorier-Eintrag:

Eine einzige globale Regel `Haustier-Glücksbringer → Sammelchar` genügt.

| läuft auf | Glücksbringer | Quelle |
|---|---|---|
| Krieger | → Sammelchar | Regel |
| Bergbauchar | → Sammelchar | Regel |
| **Sammelchar** | **bleibt liegen** | Selbst-Sperre |

Das Panel und `/wfm list` zeigen das als „X bleiben hier". Wichtig: die Sperre
stoppt die Auswertung, statt zur nächsten Regel durchzufallen — sonst könnte
eine allgemeinere Regel die gerade angekommenen Items gleich wieder wegschicken.

## Was war neu in 1.3.0 (jetzt 12.1.0.3)

### Behaltemenge pro Item

„Ich habe 100 Heiltränke, behalte 20, verschick den Rest."
Panel-Button **Behalten** (oder `/wfm keep`): Item hineinziehen, Zahl eintragen.

Die Menge ist als **Untergrenze auf den Taschenbestand** formuliert, nicht als
mitlaufender Zähler:

```
verfuegbar(itemID) = GetItemCount(itemID) - behalten(itemID)
```

Angehängte Gegenstände haben die Taschen bereits verlassen, der Wert schrumpft
also von allein und landet exakt auf der Behaltemenge. Es muss nichts über
Schritte hinweg mitgezählt werden — ein abgebrochener oder fortgesetzter Lauf
kann nicht überschießen.

**Teilstapel-Versand:** Passt der ganze Stapel nicht ins Budget, wird per
`C_Container.SplitContainerItem` exakt die erlaubte Menge abgespalten und mit
`ClickSendMailItemButton` in einen freien Anhangslot gelegt. Danach *immer*
`ClearCursor()` — schlägt das Ablegen fehl, wandern die Stücke zurück in die
Tasche statt am Cursor zu hängen.

Beispiel mit 250 Tränken in 3 Stapeln (100/100/50), behalten 20:

| Schritt | Stapel | Budget | Aktion | Taschen danach |
|---|---|---|---|---|
| 1 | 100 | 230 | ganzer Stapel | 150 |
| 2 | 100 | 130 | ganzer Stapel | 50 |
| 3 | 50 | 30 | **30 abspalten** | 20 |
| 4 | — | 0 | fertig | 20 |

Die Behaltemenge gilt account-weit als Einstellung, wird aber gegen die Taschen
des laufenden Charakters geprüft — „jeder Char behält 20" ist die Lesart.

Der Verteilplan zählt jetzt **Stück** statt Stapel, weil das mit Behaltemengen
die aussagekräftige Zahl ist.

Schnellbefehle: `/wfm keep` (Fenster), `/wfm keep 191383 20`, `/wfm keep 191383 0` (löschen).

## Was war neu in 1.2.0 (jetzt 12.1.0.2)

### Gold senden

Panel-Button „Gold senden" überweist alles **oberhalb einer Rücklage** an einen fest
hinterlegten Charakter. Standard-Rücklage: **100 Gold**.

```
sendbar = GetMoney() - Ruecklage - Porto
```

Porto (30 Kupfer) wird zusätzlich zur Rücklage abgezogen — die Rücklage bleibt
exakt stehen. Ist das Ergebnis <= 0, bleibt der Button deaktiviert.

Einstellungen unter `/wfm settings` (oder Panel-Button „Einstellungen"):
Gold-Empfänger, Rücklage in Gold, Sicherheitsabfragen, Betreff.

Schnellbefehle: `/wfm gold`, `/wfm goldtarget <name>`, `/wfm reserve 250`.

Schutzmaßnahmen speziell für Gold:
- Betrag wird **unmittelbar vor** `SendMail` neu berechnet, nie aus dem Dialog übernommen.
- Empfängername wird beim Klick erneut gegen die Whitelist geprüft und mit dem
  Dialoginhalt abgeglichen.
- Bricht ab, wenn im Postfenster Gegenstände hängen — `SendMail` würde die mitschicken.
- Bricht ab, solange ein Item-Versand läuft, und umgekehrt.
- `SetSendMailCOD(0)` erzwungen, `SetSendMailMoney(0)` nach jedem Versuch zurückgesetzt.
- Rücklage wird auf 0…9.999.999 Gold begrenzt und bei defekten SavedVars auf 100 g zurückgesetzt.

## Was war neu in 1.1.0 (jetzt 12.1.0.1)

### Bugfix: Panel öffnete nicht mit dem Briefkasten

`MAIL_SHOW` feuert **bevor** Blizzard `ShowUIPanel(MailFrame)` aufruft. Der alte
Handler prüfte `MailFrame:IsShown()` zu diesem Zeitpunkt — Ergebnis `false`, Panel
wurde sofort wieder versteckt. Ob es überhaupt erschien, hing davon ab, ob zufällig
später ein `BAG_UPDATE_DELAYED` kam.

Neu: `MailFrame:HookScript("OnShow"/"OnHide")` statt Event-Race, zusätzlich ein
`C_Timer.After(0, ...)`-Fallback und Behandlung von `Blizzard_MailFrame` als
Load-on-Demand-Addon.

### Regel-Engine

Regelliste, von oben nach unten ausgewertet, **erste passende Regel gewinnt**.
Was keine Regel trifft, geht an den Standard-Empfänger des Charakters.

Jede Regel hat:

| Feld | Wirkung |
|---|---|
| Empfänger | Pflichtfeld, `Name` oder `Name-Realm` |
| Kategorie / Unterkategorie | z. B. Rüstung / Platte — Namen kommen lokalisiert vom Client |
| Bindung | Egal / Kriegsmeute / Ungebunden (BoE) |
| Mindestqualität | Arm … Erbstück |
| Nur diese Items | Item-Liste; **wenn befüllt, zählen die Filter oben nicht mehr** |

**Beispiel „Item X immer an Y":** Neue Regel → Empfänger `Y` → Item in die Liste
„Nur diese Items" ziehen → Übernehmen.

**Beispiel „alle Rüstungsteile, Kriegsmeute oder ungebunden, an Z":**
Neue Regel → Empfänger `Z` → Kategorie `Rüstung` → Bindung `Egal` → Übernehmen.
(„Egal" umfasst genau Kriegsmeute + Ungebunden; Seelengebundenes wird nie erfasst.)

Regeln lassen sich einzeln deaktivieren (Checkbox) und mit `^` / `v` umsortieren —
die Reihenfolge entscheidet bei Überschneidungen.

### Ignorierliste

Eigenes Fenster. Items per Drag & Drop hineinziehen, Link einfügen oder itemID
tippen. Diese Gegenstände werden nie verschickt, unabhängig von allen Regeln.

## Bedienung

Briefkasten öffnen → Panel erscheint rechts daneben. Es zeigt den Verteilplan
(„7 x Bankchar", „3 x Muli", „5 ohne Empfänger", „2 ignoriert") vor dem Versand.

| Befehl | Wirkung |
|---|---|
| `/wfm send` | Alle Regeln ausführen |
| `/wfm force <name>` | Regeln ignorieren, alles an einen Empfänger |
| `/wfm target <name>` | Standard-Empfänger, dieser Char |
| `/wfm target global <name>` | Standard-Empfänger, alle Chars |
| `/wfm gold` | Gold abzüglich Rücklage senden |
| `/wfm goldtarget <name>` | Gold-Empfänger, dieser Char |
| `/wfm goldtarget global <name>` | Gold-Empfänger, alle Chars |
| `/wfm reserve <gold>` | Rücklage setzen (Standard 100) |
| `/wfm settings` | Einstellungen |
| `/wfm rules` | Regelfenster |
| `/wfm hold` | Behalteliste (auch `/wfm ignore`, `/wfm keep`) |
| `/wfm hold <itemID>` | aktuellen Eintrag anzeigen |
| `/wfm hold <itemID> 20` | 20 behalten, Rest senden |
| `/wfm hold <itemID> -` | Eintrag löschen |
| `/wfm hold char <itemID> 20` | dito, nur für diesen Charakter |
| `/wfm list` | Verteilplan im Chat |
| `/wfm unbound` | Standardregel nimmt auch BoE an/aus |
| `/wfm confirm` | Sicherheitsabfrage an/aus |
| `/wfm ui` | Panel an/aus |
| `/wfm debug` | Debug-Ausgabe an/aus |
| `/wfm version` | Version, Ziel-WoW und Client-Interface |

## Erkennungslogik

Drei Stufen, die erste eindeutige Antwort gewinnt. Ergebnis ist immer genau einer
der Zustände `warbound` / `unbound` / `soulbound`:

1. `C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc)` + `C_Item.IsBound(loc)`
   — sprachunabhängig und maßgeblich. Seelengebundenes ist in der Kriegsmeutenbank
   nie erlaubt, Kriegsmeutengebundenes immer.
2. `bindType` (Feld 14 aus `GetItemInfo`) gegen `Enum.ItemBind`
   `ToWoWAccount` / `ToBnetAccount` / `*UntilEquipped` (numerisch 7/8/9).
3. Tooltip-Scan über `C_TooltipInfo.GetBagItem` gegen Blizzards eigene lokalisierte
   GlobalStrings. Keine hartcodierten Textbausteine.

Angelegte „Kriegsmeutengebunden bis angelegt"-Teile sind seelengebunden und fallen
bereits in Stufe 1 heraus.

## Sicherheitsmaßnahmen

- Empfängername: strikte Whitelist, blockt `|`-Escapes, Steuerzeichen, Quotes,
  Backslashes — vor jedem `SendMail`, auch bei Regeln aus den SavedVariables.
- Versand an sich selbst wird abgelehnt.
- Bestätigungsdialog mit vollständigem Verteilplan (abschaltbar).
- Harte Obergrenze 25 Mails pro Lauf.
- Porto gegen `GetMoney()` vor jedem `SendMail`.
- `SetSendMailCOD(0)` / `SetSendMailMoney(0)` erzwungen — nie Gold, nie Nachnahme.
- Abbruch bei `MAIL_FAILED` und sobald der Briefkasten schließt.
- Taschen werden vor **jedem einzelnen** Anhängen neu gescannt und neu geroutet;
  veraltete Slot-Indizes sind konstruktiv ausgeschlossen.
- Drei Fehlversuche pro Gegenstand, dann überspringen — kein Endlos-Loop.
- Beim Teilstapel-Versand wird der Cursor gegen die **itemID** geprüft (nicht gegen
  den Link-String) und anschließend bedingungslos geleert.
- Keine Netzwerkzugriffe, kein `loadstring`, keine Addon-Kommunikation.

## Architektur

```
Warbrand-Fast-Mail.toc
Locale.lua        Sprach-Registry (Metatabelle, Fallback)
lang\*.xml        DE/EN/FR/ES/IT, per [TextLocale] geladen
Lib/Categories.lua Kategorienbaum aus dem Auktionshaus            (lesend)
Lib/Util.lua      Ausgabe, Validierung, API-Compat-Shims       (zustandslos)
Lib/Widgets.lua   Fenster, Dropdown, gescopte Item-Liste        (UI-Toolkit)
Lib/Hold.lua      Behalteliste, Teilstapel-Budget              (lesend)
Lib/Scanner.lua   Taschenscan + Bindungszustand + Metadaten    (lesend)
Lib/Rules.lua     Regel-Matching, Auflösung, Verteilplan       (reine Logik)
Lib/Mailer.lua    Zustandsautomat, mehrere Empfänger           (schreibend)
Lib/Gold.lua      Goldüberweisung mit Rücklage                 (schreibend)
Core.lua          SavedVariables, öffentliche API, Slash-Befehle
UI.lua            Panel am Briefkasten
Config.lua        Regel-, Behalte- und Einstellungsfenster
tools/build_lang.py  Generator für lang\*.xml (nicht im Spiel geladen)
```

`Lib/` ist frei wiederverwendbar. `Util` und `Widgets` sind abhängigkeitsfrei,
`Keep` hängt nur an `Util`, `Scanner` an `Util` + `Keep`. `Widgets` verzichtet bewusst auf `UIDropDownMenu`,
`FauxScrollFrame` und die neue `MenuUtil`-API — beide Generationen wurden von
Blizzard bereits umgebaut.

## SavedVariables

- `Warbrand-Fast-MailDB` — account-weit: Regeln, Behalteliste, Standard-Empfänger,
  Gold-Empfänger, Rücklage, Fensterpositionen
- `Warbrand-Fast-MailCharDB` — pro Charakter: Standard-Empfänger, Gold-Empfänger,
  eigene Behalteliste

## Lizenz

MIT © 2026 Thomas Weirich
