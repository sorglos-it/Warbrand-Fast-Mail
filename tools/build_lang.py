#!/usr/bin/env python3
"""Builds Warbrand-Fast-Mail/lang/*.xml from one translation table.

Keeping every language in a single source makes gaps mechanically
detectable: the generator refuses to write a file that is missing keys.
"""
import json, pathlib, html

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANG = ROOT / 'lang'

en = json.loads((ROOT / 'tools' / 'en_base.json').read_text(encoding='utf-8'))
de = json.loads((ROOT / 'tools' / 'de_base.json').read_text(encoding='utf-8'))

# strip the surrounding quotes that came out of the Lua source
unq = lambda d: {k: v[1:-1] for k, v in d.items()}
en, de = unq(en), unq(de)

# ---------------------------------------------------------------- new keys
NEW = {
 'enUS': {
  'UI_HOLD':        "Hold list",
  'HOLD_TITLE':     "Warbrand-Fast-Mail - Hold list",
  'HOLD_HINT':      "Empty amount = keep everything, never mail it.",
  'HOLD_COL':       "Keep",
  'HOLD_ALL':       "all",
  'HOLD_SET':       "Keeping %s x %s",
  'HOLD_CLEARED':   "Removed from the hold list: %s",
  'HOLD_BADNUM':    "Invalid amount: %s",
  'HOLD_TIP':       "Empty = never mail this item. A number = keep that many, mail the rest.",
  'HELP_HOLD':      "/wfm hold [itemID] [amount] - hold list",
  'SEARCH':         "Search",
  'SEARCH_HINT':    "Filter by name or item ID",
  'SEARCH_NONE':    "Nothing matches the filter.",
  'SEARCH_RULES':   "Filter by name, recipient or category",
  'CFG_INERT':      "inert here",
  'CFG_INERT_TIP':  "This rule points at the current character, so its items stay put. No mail, no postage.",
  'CAT_SOURCE_AH':  "Categories taken from the auction house.",
  'CAT_SOURCE_FB':  "Auction house not loaded, using the built-in category list.",
  'LOCALE_INFO':    "Language: %s",
  'CHECK_LINE':     "%s  keep=%s (%s)  bags: scan=%d, GetItemCount=%d  budget=%s",
  'CHECK_NONE':     "%s is not on the hold list.",
  'CHECK_UNLIMITED': "unlimited",
  'HELP_CHECK':     "/wfm check <itemID> - the numbers behind a hold entry",
  'UI_SENDALL':      "Items + gold",
  'UI_SENDALL_TIP':  "Mails every item first and puts the gold on the last mail to its recipient, so you pay one postage less.",
 },
 'deDE': {
  'UI_HOLD':        "Behalten",
  'HOLD_TITLE':     "Warbrand-Fast-Mail - Behalteliste",
  'HOLD_HINT':      "Leere Anzahl = alles behalten, nie verschicken.",
  'HOLD_COL':       "Behalten",
  'HOLD_ALL':       "alle",
  'HOLD_SET':       "Behalte %s x %s",
  'HOLD_CLEARED':   "Aus der Behalteliste entfernt: %s",
  'HOLD_BADNUM':    "Ungueltige Anzahl: %s",
  'HOLD_TIP':       "Leer = nie verschicken. Zahl = so viele behalten, den Rest verschicken.",
  'HELP_HOLD':      "/wfm hold [itemID] [anzahl] - Behalteliste",
  'SEARCH':         "Suche",
  'SEARCH_HINT':    "Nach Name oder Item-ID filtern",
  'SEARCH_NONE':    "Nichts passt zum Filter.",
  'SEARCH_RULES':   "Nach Name, Empfaenger oder Kategorie filtern",
  'CFG_INERT':      "hier inaktiv",
  'CFG_INERT_TIP':  "Diese Regel zeigt auf den aktuellen Charakter, die Gegenstaende bleiben liegen. Keine Post, kein Porto.",
  'CAT_SOURCE_AH':  "Kategorien aus dem Auktionshaus uebernommen.",
  'CAT_SOURCE_FB':  "Auktionshaus nicht geladen, eingebaute Kategorieliste in Benutzung.",
  'LOCALE_INFO':    "Sprache: %s",
  'CHECK_LINE':     "%s  behalten=%s (%s)  Taschen: Scan=%d, GetItemCount=%d  Budget=%s",
  'CHECK_NONE':     "%s steht nicht auf der Behalteliste.",
  'CHECK_UNLIMITED': "unbegrenzt",
  'HELP_CHECK':     "/wfm check <itemID> - Zahlen hinter einem Behalte-Eintrag",
  'UI_SENDALL':      "Items + Gold",
  'UI_SENDALL_TIP':  "Verschickt erst alle Gegenstaende und haengt das Gold an die letzte Mail an seinen Empfaenger. Spart ein Porto.",
 },
}

# ---------------------------------------------------------------- FR / ES / IT
FR = {
 'LOADED': "v%s charge. |cffffff00/wfm|r pour l'aide.",
 'UI_TITLE': "Warbrand-Fast-Mail", 'UI_FALLBACK': "Destinataire par defaut, ce personnage",
 'UI_SEND': "Envoyer", 'UI_RULES': "Regles", 'UI_IGNORE': "Ignorer", 'UI_SCAN': "Rescanner",
 'UI_NOTHING': "Rien a envoyer", 'UI_UNBOUND': "La regle par defaut prend aussi les objets non lies",
 'UI_PLANLINE': "%d x |cffffff00%s|r", 'UI_UNROUTED': "|cff888888%d sans destinataire|r",
 'UI_IGNORED': "|cff888888%d ignores|r",
 'UI_TOOLTIP': "Joint les objets selon les regles et les envoie automatiquement.",
 'CFG_TITLE': "Warbrand-Fast-Mail - Regles", 'CFG_HINT': "La premiere regle qui correspond gagne. L'ordre compte.",
 'CFG_NEW': "Nouvelle regle", 'CFG_EDIT': "Modifier la regle", 'CFG_APPLY': "Appliquer",
 'CFG_DELETE': "Supprimer", 'CFG_NORULES': "Aucune regle pour l'instant.", 'CFG_NAME': "Nom",
 'CFG_RECIPIENT': "Destinataire", 'CFG_CATEGORY': "Categorie", 'CFG_SUBCAT': "Sous-categorie",
 'CFG_BIND': "Liaison", 'CFG_QUALITY': "Qualite minimale",
 'CFG_ONLYITEMS': "Uniquement ces objets (remplace les filtres ci-dessus)",
 'CFG_DROPHERE': "Glissez un objet ici ou collez un lien / ID", 'CFG_CLEAR': "Vider",
 'CFG_ANY': "Peu importe", 'CFG_ALL': "Tous", 'CFG_UNNAMED': "Regle %d",
 'CFG_RULE_SAVED': "Regle enregistree : %s", 'CFG_RULE_DEL': "Regle supprimee : %s",
 'IGN_TITLE': "Warbrand-Fast-Mail - Liste d'exclusion", 'IGN_HINT': "Ces objets ne sont jamais envoyes.",
 'BIND_ANY': "Peu importe", 'BIND_WARBOUND': "Bataillon", 'BIND_UNBOUND': "Non lie (BoE)",
 'NO_MAILBOX': "La boite aux lettres n'est pas ouverte.", 'MAILBOX_CLOSED': "Annule : boite aux lettres fermee.",
 'BUSY': "Un envoi est deja en cours.", 'NOTHING': "Rien a envoyer.",
 'BAD_NAME': "Nom de destinataire invalide : %s", 'NO_SELF': "Impossible de s'envoyer du courrier.",
 'NO_MONEY': "Annule : pas assez d'argent pour l'affranchissement.",
 'SEND_FAILED': "Annule : le serveur a refuse le courrier.",
 'CAP': "Annule : limite de securite de %d courriers atteinte.",
 'SKIP': "Ignore (impossible a joindre) : %s", 'START': "Envoi de %d objet(s) a %d destinataire(s) ...",
 'TO': "-> |cffffff00%s|r", 'DONE': "Termine. %d objet(s) en %d courrier(s).",
 'ABORTED': "Annule. %d objet(s) deja envoyes.",
 'TARGET_SET': "Destinataire par defaut : |cffffff00%s|r", 'TARGET_NONE': "Aucun destinataire par defaut.",
 'CONFIRM': "Envoyer |cffffff00%d|r objet(s) ?\\n\\n%s\\n|cffff2020Verifiez bien les noms.|r",
 'HELP_HEADER': "Commandes :", 'HELP_SEND': "/wfm send - executer toutes les regles",
 'HELP_FORCE': "/wfm force <nom> - tout envoyer a un destinataire",
 'HELP_TARGET': "/wfm target [global] <nom> - destinataire par defaut",
 'HELP_RULES': "/wfm rules - fenetre des regles", 'HELP_IGNORE': "/wfm ignore - liste d'exclusion",
 'HELP_LIST': "/wfm list - apercu de la repartition",
 'HELP_UNBOUND': "/wfm unbound - objets non lies oui/non",
 'HELP_CONFIRM': "/wfm confirm - demande de confirmation oui/non",
 'HELP_UI': "/wfm ui - panneau oui/non", 'HELP_DEBUG': "/wfm debug - sortie de debogage oui/non",
 'IGNORE_ADD': "Ignore : %s", 'IGNORE_DEL': "N'est plus ignore : %s",
 'TOGGLE_ON': "|cff20ff20oui|r", 'TOGGLE_OFF': "|cffff2020non|r",
 'UNBOUND_STATE': "La regle par defaut prend les objets non lies : %s",
 'CONFIRM_STATE': "Demande de confirmation : %s", 'DEBUG_STATE': "Debogage : %s",
 'UI_GOLD': "Envoyer l'or", 'UI_SETTINGS': "Reglages",
 'UI_GOLD_LINE': "Or : %s |cff888888->|r |cffffff00%s|r",
 'UI_GOLD_NONE': "|cff888888Aucun destinataire pour l'or|r",
 'GOLD_NONE': "Aucun destinataire d'or valide (/wfm settings).",
 'GOLD_NOTHING': "Rien a envoyer apres la reserve.",
 'GOLD_ATTACH': "Annule : des objets sont joints dans la fenetre de courrier.",
 'GOLD_CONFIRM': "Envoyer |cffffff00%s|r a\\n\\n|cff33ff99%s|r ?\\n\\nRestera : %s\\n\\n|cffff2020Verifiez bien le nom.|r",
 'GOLD_SENT': "%s envoye a |cffffff00%s|r.", 'GOLD_FAILED': "Transfert d'or refuse par le serveur.",
 'HELP_GOLD': "/wfm gold - envoyer l'or moins la reserve",
 'HELP_SETTINGS': "/wfm settings - ouvrir les reglages",
 'SET_TITLE': "Warbrand-Fast-Mail - Reglages", 'SET_HINT': "Vide = utiliser la valeur du compte.",
 'SET_GOLDRCPT': "Destinataire de l'or", 'SET_RESERVE': "Garder (or)",
 'SET_RESERVEHINT': "Par defaut : 100", 'SET_SENDABLE': "Envoyable actuellement : %s",
 'SET_GOLDCONFIRM': "Confirmer avant l'envoi d'or", 'SET_CONFIRM': "Confirmer avant l'envoi du courrier",
 'SET_SUBJECT': "Objet du courrier", 'SET_SAVED': "Reglages enregistres.",
 'SET_BADRESERVE': "Reserve invalide : %s",
 'UI_KEEP': "Garder", 'KEEP_TITLE': "Warbrand-Fast-Mail - Quantites gardees",
 'KEEP_HINT': "Ce nombre reste dans les sacs, le reste part.", 'KEEP_COL': "Garder",
 'KEEP_SET': "Garde %d x %s", 'KEEP_CLEARED': "Quantite gardee supprimee : %s",
 'KEEP_BADNUM': "Quantite invalide : %s", 'HELP_KEEP': "/wfm keep [itemID] [quantite] - quantite gardee",
 'SCOPE_GLOBAL': "Tous les personnages", 'SCOPE_CHAR': "Seulement %s",
 'SCOPE_THIS': "Seulement ce personnage", 'SCOPE_LABEL': "Portee",
 'SCOPE_NEW': "Nouvelles entrees :", 'SCOPE_MARK_G': "T", 'SCOPE_MARK_C': "P",
 'SCOPE_TIP': "Cliquez pour basculer entre tous les personnages et celui-ci uniquement.",
 'SCOPE_CLEARTIP': "Ne vide que la portee choisie ci-dessous.",
 'UI_STAYING': "|cff888888%d restent ici|r",
 'STAY_HINT': "Une regle pointant sur le personnage actuel garde ses objets ici.",
 'SET_SEC_CHAR': "Seulement ce personnage (%s)", 'SET_SEC_GLOBAL': "Tous les personnages",
 'SET_ITEMRCPT': "Destinataire par defaut, objets",
 'SET_INHERIT': "Vide = utiliser la valeur du compte.",
 'SET_EFFECTIVE': "En vigueur : objets %s, or %s", 'SET_NOTSET': "|cff888888non defini|r",
 'TARGET_GLOBAL': "Destinataire par defaut du compte : |cffffff00%s|r",
 'TARGET_CHAR': "Ce personnage : |cffffff00%s|r", 'TARGET_EFF': "En vigueur : |cffffff00%s|r",
 'GOLD_TARGET_G': "Destinataire d'or du compte : |cffffff00%s|r",
 'GOLD_TARGET_C': "Destinataire d'or de ce personnage : |cffffff00%s|r",
 'HELP_GOLDTGT': "/wfm goldtarget [global] <nom> - destinataire de l'or",
 'VERSION_LINE': "v%s, concu pour WoW %s.", 'VERSION_CLIENT': "Le client tourne en %s (interface %d).",
 'VERSION_MATCH': "|cff20ff20correspond|r",
 'VERSION_MISMATCH': "|cffff2020Concu pour WoW %s, le client tourne en %s. Cherchez une mise a jour.|r",
 'VERSION_PATCH': "|cffaaaa20Concu pour WoW %s, le client tourne en %s. Meme branche, TOC a rafraichir.|r",
 'HELP_VERSION': "/wfm version - version et interface du client",
 'UI_HOLD': "Garder", 'HOLD_TITLE': "Warbrand-Fast-Mail - Liste de retenue",
 'HOLD_HINT': "Quantite vide = tout garder, ne jamais envoyer.", 'HOLD_COL': "Garder",
 'HOLD_ALL': "tout", 'HOLD_SET': "Garde %s x %s",
 'HOLD_CLEARED': "Retire de la liste de retenue : %s", 'HOLD_BADNUM': "Quantite invalide : %s",
 'HOLD_TIP': "Vide = ne jamais envoyer. Un nombre = garder ce nombre, envoyer le reste.",
 'HELP_HOLD': "/wfm hold [itemID] [quantite] - liste de retenue",
 'SEARCH': "Recherche", 'SEARCH_HINT': "Filtrer par nom ou ID d'objet",
 'SEARCH_NONE': "Rien ne correspond au filtre.",
 'SEARCH_RULES': "Filtrer par nom, destinataire ou categorie",
 'CFG_INERT': "inactive ici",
 'CFG_INERT_TIP': "Cette regle pointe sur le personnage actuel, ses objets restent en place. Pas de courrier, pas de frais.",
 'CAT_SOURCE_AH': "Categories reprises de l'hotel des ventes.",
 'CAT_SOURCE_FB': "Hotel des ventes non charge, liste de categories integree utilisee.",
 'LOCALE_INFO': "Langue : %s",
 'CHECK_LINE': "%s  garder=%s (%s)  sacs : scan=%d, GetItemCount=%d  budget=%s", 'CHECK_NONE': "%s n'est pas dans la liste de retenue.", 'CHECK_UNLIMITED': "illimite", 'HELP_CHECK': "/wfm check <itemID> - chiffres derriere une entree de retenue",
 'UI_SENDALL': "Objets + or",
 'UI_SENDALL_TIP': "Envoie d'abord tous les objets puis joint l'or au dernier courrier destine a son destinataire. Un affranchissement de moins.",
}

ES = {
 'LOADED': "v%s cargado. |cffffff00/wfm|r para la ayuda.",
 'UI_TITLE': "Warbrand-Fast-Mail", 'UI_FALLBACK': "Destinatario por defecto, este personaje",
 'UI_SEND': "Enviar", 'UI_RULES': "Reglas", 'UI_IGNORE': "Ignorar", 'UI_SCAN': "Reescanear",
 'UI_NOTHING': "Nada que enviar", 'UI_UNBOUND': "La regla por defecto tambien toma objetos no ligados",
 'UI_PLANLINE': "%d x |cffffff00%s|r", 'UI_UNROUTED': "|cff888888%d sin destinatario|r",
 'UI_IGNORED': "|cff888888%d ignorados|r",
 'UI_TOOLTIP': "Adjunta objetos segun las reglas y los envia automaticamente.",
 'CFG_TITLE': "Warbrand-Fast-Mail - Reglas", 'CFG_HINT': "Gana la primera regla que coincide. El orden importa.",
 'CFG_NEW': "Nueva regla", 'CFG_EDIT': "Editar regla", 'CFG_APPLY': "Aplicar",
 'CFG_DELETE': "Borrar", 'CFG_NORULES': "Todavia no hay reglas.", 'CFG_NAME': "Nombre",
 'CFG_RECIPIENT': "Destinatario", 'CFG_CATEGORY': "Categoria", 'CFG_SUBCAT': "Subcategoria",
 'CFG_BIND': "Ligadura", 'CFG_QUALITY': "Calidad minima",
 'CFG_ONLYITEMS': "Solo estos objetos (anula los filtros de arriba)",
 'CFG_DROPHERE': "Arrastra un objeto aqui o pega un enlace / ID", 'CFG_CLEAR': "Vaciar",
 'CFG_ANY': "Indiferente", 'CFG_ALL': "Todos", 'CFG_UNNAMED': "Regla %d",
 'CFG_RULE_SAVED': "Regla guardada: %s", 'CFG_RULE_DEL': "Regla borrada: %s",
 'IGN_TITLE': "Warbrand-Fast-Mail - Lista de ignorados", 'IGN_HINT': "Estos objetos nunca se envian.",
 'BIND_ANY': "Indiferente", 'BIND_WARBOUND': "Banda", 'BIND_UNBOUND': "No ligado (BoE)",
 'NO_MAILBOX': "El buzon no esta abierto.", 'MAILBOX_CLOSED': "Cancelado: buzon cerrado.",
 'BUSY': "Ya hay un envio en curso.", 'NOTHING': "Nada que enviar.",
 'BAD_NAME': "Nombre de destinatario invalido: %s", 'NO_SELF': "No puedes enviarte correo a ti mismo.",
 'NO_MONEY': "Cancelado: no hay oro suficiente para el franqueo.",
 'SEND_FAILED': "Cancelado: el servidor rechazo el correo.",
 'CAP': "Cancelado: limite de seguridad de %d correos alcanzado.",
 'SKIP': "Omitido (no se puede adjuntar): %s", 'START': "Enviando %d objeto(s) a %d destinatario(s) ...",
 'TO': "-> |cffffff00%s|r", 'DONE': "Listo. %d objeto(s) en %d correo(s).",
 'ABORTED': "Cancelado. %d objeto(s) ya enviados.",
 'TARGET_SET': "Destinatario por defecto: |cffffff00%s|r", 'TARGET_NONE': "Sin destinatario por defecto.",
 'CONFIRM': "Enviar |cffffff00%d|r objeto(s)?\\n\\n%s\\n|cffff2020Comprueba bien los nombres.|r",
 'HELP_HEADER': "Comandos:", 'HELP_SEND': "/wfm send - ejecutar todas las reglas",
 'HELP_FORCE': "/wfm force <nombre> - enviar todo a un destinatario",
 'HELP_TARGET': "/wfm target [global] <nombre> - destinatario por defecto",
 'HELP_RULES': "/wfm rules - ventana de reglas", 'HELP_IGNORE': "/wfm ignore - lista de ignorados",
 'HELP_LIST': "/wfm list - vista previa del reparto",
 'HELP_UNBOUND': "/wfm unbound - objetos no ligados si/no",
 'HELP_CONFIRM': "/wfm confirm - confirmacion si/no",
 'HELP_UI': "/wfm ui - panel si/no", 'HELP_DEBUG': "/wfm debug - salida de depuracion si/no",
 'IGNORE_ADD': "Ignorado: %s", 'IGNORE_DEL': "Ya no se ignora: %s",
 'TOGGLE_ON': "|cff20ff20si|r", 'TOGGLE_OFF': "|cffff2020no|r",
 'UNBOUND_STATE': "La regla por defecto toma objetos no ligados: %s",
 'CONFIRM_STATE': "Confirmacion: %s", 'DEBUG_STATE': "Depuracion: %s",
 'UI_GOLD': "Enviar oro", 'UI_SETTINGS': "Ajustes",
 'UI_GOLD_LINE': "Oro: %s |cff888888->|r |cffffff00%s|r",
 'UI_GOLD_NONE': "|cff888888Sin destinatario de oro|r",
 'GOLD_NONE': "No hay un destinatario de oro valido (/wfm settings).",
 'GOLD_NOTHING': "No queda nada tras la reserva.",
 'GOLD_ATTACH': "Cancelado: hay objetos adjuntos en la ventana de correo.",
 'GOLD_CONFIRM': "Enviar |cffffff00%s|r a\\n\\n|cff33ff99%s|r ?\\n\\nSe queda: %s\\n\\n|cffff2020Comprueba bien el nombre.|r",
 'GOLD_SENT': "%s enviado a |cffffff00%s|r.", 'GOLD_FAILED': "El servidor rechazo la transferencia de oro.",
 'HELP_GOLD': "/wfm gold - enviar oro menos la reserva",
 'HELP_SETTINGS': "/wfm settings - abrir los ajustes",
 'SET_TITLE': "Warbrand-Fast-Mail - Ajustes", 'SET_HINT': "Vacio = usar el valor de la cuenta.",
 'SET_GOLDRCPT': "Destinatario de oro", 'SET_RESERVE': "Reservar (oro)",
 'SET_RESERVEHINT': "Por defecto: 100", 'SET_SENDABLE': "Enviable ahora mismo: %s",
 'SET_GOLDCONFIRM': "Confirmar antes de enviar oro", 'SET_CONFIRM': "Confirmar antes de enviar correo",
 'SET_SUBJECT': "Asunto del correo", 'SET_SAVED': "Ajustes guardados.",
 'SET_BADRESERVE': "Reserva invalida: %s",
 'UI_KEEP': "Guardar", 'KEEP_TITLE': "Warbrand-Fast-Mail - Cantidades guardadas",
 'KEEP_HINT': "Esta cantidad se queda en las bolsas, el resto se envia.", 'KEEP_COL': "Guardar",
 'KEEP_SET': "Guardando %d x %s", 'KEEP_CLEARED': "Cantidad guardada eliminada: %s",
 'KEEP_BADNUM': "Cantidad invalida: %s", 'HELP_KEEP': "/wfm keep [itemID] [cantidad] - cantidad guardada",
 'SCOPE_GLOBAL': "Todos los personajes", 'SCOPE_CHAR': "Solo %s",
 'SCOPE_THIS': "Solo este personaje", 'SCOPE_LABEL': "Ambito",
 'SCOPE_NEW': "Entradas nuevas:", 'SCOPE_MARK_G': "T", 'SCOPE_MARK_C': "P",
 'SCOPE_TIP': "Haz clic para alternar entre todos los personajes y solo este.",
 'SCOPE_CLEARTIP': "Solo vacia el ambito elegido abajo.",
 'UI_STAYING': "|cff888888%d se quedan aqui|r",
 'STAY_HINT': "Una regla que apunta al personaje actual mantiene sus objetos aqui.",
 'SET_SEC_CHAR': "Solo este personaje (%s)", 'SET_SEC_GLOBAL': "Todos los personajes",
 'SET_ITEMRCPT': "Destinatario por defecto, objetos",
 'SET_INHERIT': "Vacio = usar el valor de la cuenta.",
 'SET_EFFECTIVE': "En vigor: objetos %s, oro %s", 'SET_NOTSET': "|cff888888sin definir|r",
 'TARGET_GLOBAL': "Destinatario por defecto de la cuenta: |cffffff00%s|r",
 'TARGET_CHAR': "Este personaje: |cffffff00%s|r", 'TARGET_EFF': "En vigor: |cffffff00%s|r",
 'GOLD_TARGET_G': "Destinatario de oro de la cuenta: |cffffff00%s|r",
 'GOLD_TARGET_C': "Destinatario de oro de este personaje: |cffffff00%s|r",
 'HELP_GOLDTGT': "/wfm goldtarget [global] <nombre> - destinatario de oro",
 'VERSION_LINE': "v%s, creado para WoW %s.", 'VERSION_CLIENT': "El cliente corre %s (interfaz %d).",
 'VERSION_MATCH': "|cff20ff20coincide|r",
 'VERSION_MISMATCH': "|cffff2020Creado para WoW %s, el cliente corre %s. Busca una actualizacion.|r",
 'VERSION_PATCH': "|cffaaaa20Creado para WoW %s, el cliente corre %s. Misma rama, revisa el TOC.|r",
 'HELP_VERSION': "/wfm version - version e interfaz del cliente",
 'UI_HOLD': "Guardar", 'HOLD_TITLE': "Warbrand-Fast-Mail - Lista de retencion",
 'HOLD_HINT': "Cantidad vacia = guardarlo todo, no enviar nunca.", 'HOLD_COL': "Guardar",
 'HOLD_ALL': "todo", 'HOLD_SET': "Guardando %s x %s",
 'HOLD_CLEARED': "Eliminado de la lista de retencion: %s", 'HOLD_BADNUM': "Cantidad invalida: %s",
 'HOLD_TIP': "Vacio = no enviar nunca. Un numero = guardar esa cantidad y enviar el resto.",
 'HELP_HOLD': "/wfm hold [itemID] [cantidad] - lista de retencion",
 'SEARCH': "Buscar", 'SEARCH_HINT': "Filtrar por nombre o ID de objeto",
 'SEARCH_NONE': "Nada coincide con el filtro.",
 'SEARCH_RULES': "Filtrar por nombre, destinatario o categoria",
 'CFG_INERT': "inactiva aqui",
 'CFG_INERT_TIP': "Esta regla apunta al personaje actual, sus objetos se quedan. Sin correo, sin franqueo.",
 'CAT_SOURCE_AH': "Categorias tomadas de la casa de subastas.",
 'CAT_SOURCE_FB': "Casa de subastas no cargada, se usa la lista de categorias integrada.",
 'LOCALE_INFO': "Idioma: %s",
 'CHECK_LINE': "%s  guardar=%s (%s)  bolsas: escaneo=%d, GetItemCount=%d  presupuesto=%s", 'CHECK_NONE': "%s no esta en la lista de retencion.", 'CHECK_UNLIMITED': "ilimitado", 'HELP_CHECK': "/wfm check <itemID> - cifras tras una entrada de retencion",
 'UI_SENDALL': "Objetos + oro",
 'UI_SENDALL_TIP': "Envia primero todos los objetos y adjunta el oro al ultimo correo a su destinatario. Un franqueo menos.",
}

IT = {
 'LOADED': "v%s caricato. |cffffff00/wfm|r per l'aiuto.",
 'UI_TITLE': "Warbrand-Fast-Mail", 'UI_FALLBACK': "Destinatario predefinito, questo personaggio",
 'UI_SEND': "Invia", 'UI_RULES': "Regole", 'UI_IGNORE': "Ignora", 'UI_SCAN': "Riscansiona",
 'UI_NOTHING': "Niente da inviare", 'UI_UNBOUND': "La regola predefinita prende anche gli oggetti non legati",
 'UI_PLANLINE': "%d x |cffffff00%s|r", 'UI_UNROUTED': "|cff888888%d senza destinatario|r",
 'UI_IGNORED': "|cff888888%d ignorati|r",
 'UI_TOOLTIP': "Allega gli oggetti secondo le regole e li spedisce automaticamente.",
 'CFG_TITLE': "Warbrand-Fast-Mail - Regole", 'CFG_HINT': "Vince la prima regola che corrisponde. L'ordine conta.",
 'CFG_NEW': "Nuova regola", 'CFG_EDIT': "Modifica regola", 'CFG_APPLY': "Applica",
 'CFG_DELETE': "Elimina", 'CFG_NORULES': "Ancora nessuna regola.", 'CFG_NAME': "Nome",
 'CFG_RECIPIENT': "Destinatario", 'CFG_CATEGORY': "Categoria", 'CFG_SUBCAT': "Sottocategoria",
 'CFG_BIND': "Legame", 'CFG_QUALITY': "Qualita minima",
 'CFG_ONLYITEMS': "Solo questi oggetti (ignora i filtri sopra)",
 'CFG_DROPHERE': "Trascina qui un oggetto o incolla link / ID", 'CFG_CLEAR': "Svuota",
 'CFG_ANY': "Indifferente", 'CFG_ALL': "Tutti", 'CFG_UNNAMED': "Regola %d",
 'CFG_RULE_SAVED': "Regola salvata: %s", 'CFG_RULE_DEL': "Regola eliminata: %s",
 'IGN_TITLE': "Warbrand-Fast-Mail - Lista ignorati", 'IGN_HINT': "Questi oggetti non vengono mai spediti.",
 'BIND_ANY': "Indifferente", 'BIND_WARBOUND': "Compagnia", 'BIND_UNBOUND': "Non legato (BoE)",
 'NO_MAILBOX': "La cassetta postale non e aperta.", 'MAILBOX_CLOSED': "Annullato: cassetta postale chiusa.",
 'BUSY': "C'e gia un invio in corso.", 'NOTHING': "Niente da inviare.",
 'BAD_NAME': "Nome destinatario non valido: %s", 'NO_SELF': "Non puoi spedire a te stesso.",
 'NO_MONEY': "Annullato: oro insufficiente per l'affrancatura.",
 'SEND_FAILED': "Annullato: il server ha rifiutato la posta.",
 'CAP': "Annullato: raggiunto il limite di sicurezza di %d messaggi.",
 'SKIP': "Saltato (impossibile allegare): %s", 'START': "Invio di %d oggetto/i a %d destinatario/i ...",
 'TO': "-> |cffffff00%s|r", 'DONE': "Fatto. %d oggetto/i in %d messaggio/i.",
 'ABORTED': "Annullato. %d oggetto/i gia inviati.",
 'TARGET_SET': "Destinatario predefinito: |cffffff00%s|r", 'TARGET_NONE': "Nessun destinatario predefinito.",
 'CONFIRM': "Inviare |cffffff00%d|r oggetto/i?\\n\\n%s\\n|cffff2020Controlla bene i nomi.|r",
 'HELP_HEADER': "Comandi:", 'HELP_SEND': "/wfm send - esegui tutte le regole",
 'HELP_FORCE': "/wfm force <nome> - manda tutto a un destinatario",
 'HELP_TARGET': "/wfm target [global] <nome> - destinatario predefinito",
 'HELP_RULES': "/wfm rules - finestra delle regole", 'HELP_IGNORE': "/wfm ignore - lista ignorati",
 'HELP_LIST': "/wfm list - anteprima della ripartizione",
 'HELP_UNBOUND': "/wfm unbound - oggetti non legati si/no",
 'HELP_CONFIRM': "/wfm confirm - conferma si/no",
 'HELP_UI': "/wfm ui - pannello si/no", 'HELP_DEBUG': "/wfm debug - output di debug si/no",
 'IGNORE_ADD': "Ignorato: %s", 'IGNORE_DEL': "Non piu ignorato: %s",
 'TOGGLE_ON': "|cff20ff20si|r", 'TOGGLE_OFF': "|cffff2020no|r",
 'UNBOUND_STATE': "La regola predefinita prende gli oggetti non legati: %s",
 'CONFIRM_STATE': "Conferma: %s", 'DEBUG_STATE': "Debug: %s",
 'UI_GOLD': "Invia oro", 'UI_SETTINGS': "Impostazioni",
 'UI_GOLD_LINE': "Oro: %s |cff888888->|r |cffffff00%s|r",
 'UI_GOLD_NONE': "|cff888888Nessun destinatario per l'oro|r",
 'GOLD_NONE': "Nessun destinatario valido per l'oro (/wfm settings).",
 'GOLD_NOTHING': "Dopo la riserva non resta nulla da inviare.",
 'GOLD_ATTACH': "Annullato: ci sono oggetti allegati nella finestra della posta.",
 'GOLD_CONFIRM': "Inviare |cffffff00%s|r a\\n\\n|cff33ff99%s|r ?\\n\\nRimane: %s\\n\\n|cffff2020Controlla bene il nome.|r",
 'GOLD_SENT': "%s inviato a |cffffff00%s|r.", 'GOLD_FAILED': "Trasferimento d'oro rifiutato dal server.",
 'HELP_GOLD': "/wfm gold - invia l'oro meno la riserva",
 'HELP_SETTINGS': "/wfm settings - apri le impostazioni",
 'SET_TITLE': "Warbrand-Fast-Mail - Impostazioni", 'SET_HINT': "Vuoto = usa il valore dell'account.",
 'SET_GOLDRCPT': "Destinatario dell'oro", 'SET_RESERVE': "Trattieni (oro)",
 'SET_RESERVEHINT': "Predefinito: 100", 'SET_SENDABLE': "Inviabile adesso: %s",
 'SET_GOLDCONFIRM': "Conferma prima di inviare oro", 'SET_CONFIRM': "Conferma prima di inviare posta",
 'SET_SUBJECT': "Oggetto della posta", 'SET_SAVED': "Impostazioni salvate.",
 'SET_BADRESERVE': "Riserva non valida: %s",
 'UI_KEEP': "Trattieni", 'KEEP_TITLE': "Warbrand-Fast-Mail - Quantita trattenute",
 'KEEP_HINT': "Questa quantita resta nelle borse, il resto parte.", 'KEEP_COL': "Trattieni",
 'KEEP_SET': "Trattengo %d x %s", 'KEEP_CLEARED': "Quantita trattenuta rimossa: %s",
 'KEEP_BADNUM': "Quantita non valida: %s", 'HELP_KEEP': "/wfm keep [itemID] [quantita] - quantita trattenuta",
 'SCOPE_GLOBAL': "Tutti i personaggi", 'SCOPE_CHAR': "Solo %s",
 'SCOPE_THIS': "Solo questo personaggio", 'SCOPE_LABEL': "Ambito",
 'SCOPE_NEW': "Nuove voci:", 'SCOPE_MARK_G': "T", 'SCOPE_MARK_C': "P",
 'SCOPE_TIP': "Clicca per passare da tutti i personaggi a solo questo.",
 'SCOPE_CLEARTIP': "Svuota solo l'ambito scelto qui sotto.",
 'UI_STAYING': "|cff888888%d restano qui|r",
 'STAY_HINT': "Una regola che punta al personaggio attuale tiene qui i suoi oggetti.",
 'SET_SEC_CHAR': "Solo questo personaggio (%s)", 'SET_SEC_GLOBAL': "Tutti i personaggi",
 'SET_ITEMRCPT': "Destinatario predefinito, oggetti",
 'SET_INHERIT': "Vuoto = usa il valore dell'account.",
 'SET_EFFECTIVE': "In vigore: oggetti %s, oro %s", 'SET_NOTSET': "|cff888888non impostato|r",
 'TARGET_GLOBAL': "Destinatario predefinito dell'account: |cffffff00%s|r",
 'TARGET_CHAR': "Questo personaggio: |cffffff00%s|r", 'TARGET_EFF': "In vigore: |cffffff00%s|r",
 'GOLD_TARGET_G': "Destinatario dell'oro dell'account: |cffffff00%s|r",
 'GOLD_TARGET_C': "Destinatario dell'oro di questo personaggio: |cffffff00%s|r",
 'HELP_GOLDTGT': "/wfm goldtarget [global] <nome> - destinatario dell'oro",
 'VERSION_LINE': "v%s, creato per WoW %s.", 'VERSION_CLIENT': "Il client gira su %s (interfaccia %d).",
 'VERSION_MATCH': "|cff20ff20corrisponde|r",
 'VERSION_MISMATCH': "|cffff2020Creato per WoW %s, il client gira su %s. Cerca un aggiornamento.|r",
 'VERSION_PATCH': "|cffaaaa20Creato per WoW %s, il client gira su %s. Stesso ramo, aggiorna il TOC.|r",
 'HELP_VERSION': "/wfm version - versione e interfaccia del client",
 'UI_HOLD': "Trattieni", 'HOLD_TITLE': "Warbrand-Fast-Mail - Lista di ritenzione",
 'HOLD_HINT': "Quantita vuota = trattieni tutto, non spedire mai.", 'HOLD_COL': "Trattieni",
 'HOLD_ALL': "tutto", 'HOLD_SET': "Trattengo %s x %s",
 'HOLD_CLEARED': "Rimosso dalla lista di ritenzione: %s", 'HOLD_BADNUM': "Quantita non valida: %s",
 'HOLD_TIP': "Vuoto = non spedire mai. Un numero = trattieni quella quantita e spedisci il resto.",
 'HELP_HOLD': "/wfm hold [itemID] [quantita] - lista di ritenzione",
 'SEARCH': "Cerca", 'SEARCH_HINT': "Filtra per nome o ID oggetto",
 'SEARCH_NONE': "Niente corrisponde al filtro.",
 'SEARCH_RULES': "Filtra per nome, destinatario o categoria",
 'CFG_INERT': "inattiva qui",
 'CFG_INERT_TIP': "Questa regola punta al personaggio attuale, i suoi oggetti restano. Nessuna posta, nessun costo.",
 'CAT_SOURCE_AH': "Categorie prese dalla casa d'aste.",
 'CAT_SOURCE_FB': "Casa d'aste non caricata, uso l'elenco di categorie integrato.",
 'LOCALE_INFO': "Lingua: %s",
 'CHECK_LINE': "%s  trattieni=%s (%s)  borse: scansione=%d, GetItemCount=%d  budget=%s", 'CHECK_NONE': "%s non e nella lista di ritenzione.", 'CHECK_UNLIMITED': "illimitato", 'HELP_CHECK': "/wfm check <itemID> - numeri dietro una voce di ritenzione",
 'UI_SENDALL': "Oggetti + oro",
 'UI_SENDALL_TIP': "Spedisce prima tutti gli oggetti e allega l'oro all'ultimo messaggio al suo destinatario. Un'affrancatura in meno.",
}

# ---------------------------------------------------------------- assemble
en.update(NEW['enUS'])
de.update(NEW['deDE'])
LANGS = {'enUS': en, 'deDE': de, 'frFR': FR, 'esES': ES, 'itIT': IT}

problems = []
for code, tbl in LANGS.items():
    missing = sorted(set(en) - set(tbl))
    extra   = sorted(set(tbl) - set(en))
    if missing: problems.append(f"{code}: fehlende Schluessel {missing}")
    if extra:   problems.append(f"{code}: unbekannte Schluessel {extra}")
    # format specifiers must match the English base exactly
    import re as _re
    for k in set(tbl) & set(en):
        spec = lambda s: _re.findall(r'%[-0-9.]*[a-zA-Z]', s)
        if sorted(spec(tbl[k])) != sorted(spec(en[k])):
            problems.append(f"{code}.{k}: Platzhalter {spec(tbl[k])} != {spec(en[k])}")

if problems:
    print("ABBRUCH:")
    for p in problems: print("  " + p)
    raise SystemExit(1)

LANG.mkdir(exist_ok=True)
HEADER = ('<Ui xmlns="http://www.blizzard.com/wow/ui/"\n'
          '    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n'
          '    xsi:schemaLocation="http://www.blizzard.com/wow/ui/\n'
          '    https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/FrameXML/UI.xsd">\n')

def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\\\\n', '\\n') + '"'

for code, tbl in LANGS.items():
    lines = []
    for k in sorted(tbl):
        v = tbl[k].replace('\\', '\\\\').replace('"', '\\"')
        v = v.replace('\\\\n', '\\n')
        lines.append(f'            {k:<16} = "{v}",')
    body = "\n".join(lines)
    xml = (HEADER +
           f'    <!-- Warbrand-Fast-Mail language file: {code}\n'
           f'         Generated - do not edit by hand, edit tools/build_lang.py.\n'
           f'         Keys missing here fall back to lang\\enUS.xml. -->\n'
           '    <Script><![CDATA[\n'
           f'        WarbrandFastMail_RegisterLocale("{code}", {{\n'
           f'{body}\n'
           '        })\n'
           '    ]]></Script>\n'
           '</Ui>\n')
    (LANG / f'{code}.xml').write_text(xml, encoding='utf-8')
    print(f"  lang/{code}.xml  {len(tbl)} Schluessel")

# esMX shares the Spanish file
(LANG / 'esMX.xml').write_text(
    (LANG / 'esES.xml').read_text(encoding='utf-8').replace('"esES"', '"esMX"'), encoding='utf-8')
print("  lang/esMX.xml  (Kopie von esES)")
print("\nOK -", len(en), "Schluessel je Sprache, Platzhalter geprueft.")
