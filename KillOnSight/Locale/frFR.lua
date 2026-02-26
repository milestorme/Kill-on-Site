-- Locale/frFR.lua
local ADDON_NAME = ...
KillOnSight_L_data = KillOnSight_L_data or {}
KillOnSight_L_used = KillOnSight_L_used or {}
KillOnSight_L = KillOnSight_L or {}

if not KillOnSight_L.__kos_proxy then
  KillOnSight_L.__kos_proxy = true
  setmetatable(KillOnSight_L, {
    __index = function(_, k)
      KillOnSight_L_used[k] = true
      local v = KillOnSight_L_data[k]
      if v == nil then
        return k -- fallback so missing keys are obvious
      end
      return v
    end,
  })
end

local L = KillOnSight_L_data

if not (GetLocale() == "frFR") then return end

L.ACTIVITY = "%s à proximité : %s (%s)%s"
L.ADDED_GUILD = "Guilde ajoutée à %s : %s"
L.ADDED_PLAYER = "Joueur ajouté à %s : %s"
L.ADDON_PREFIX = "KILLONSIGHT"
L.CMD_HELP = "Commandes : /kos help | show | add [nom] | remove <nom> | addguild <guilde> | removeguild <guilde> | list | sync | statsprune"
L.GUILD_KOS = "KoS-Guilde"
L.HIDDEN = "Camouflé"
L.KOS = "KoS"
L.NOT_FOUND = "Introuvable : %s"
L.REMOVED_GUILD = "Guilde retirée : %s"
L.REMOVED_PLAYER = "Joueur retiré : %s"
L.SEEN = "%s repéré à proximité : %s%s"
L.SEEN_GUILD = "Guilde de %s à proximité : %s (%s)%s"
L.SEEN_HIDDEN = "Camouflé détecté : %s"
L.SYNC_COOLDOWN = "Synchronisation en recharge : %ds restantes."
L.SYNC_DISABLED = "La synchronisation nécessite d'être dans une guilde."
L.SYNC_SENT = "Demande de synchronisation envoyée."
L.SYNC_TOO_OLD = "Synchronisation échouée : le pair est trop en retard (oldest=%s, current=%s)."
L.UI_ADD = "Ajouter"
L.UI_ADD_GUILD = "Ajouter une guilde"
L.UI_ADD_KOS = "Ajouter KoS"
L.UI_CLEAR = "Effacer"
L.UI_CLOSE = "Fermer"
L.UI_FLASH = "Clignoter"
L.UI_GUILD = "Guilde"
L.UI_ALERTS = "KoS / Guilde"
L.UI_NEARBY_HEADING = "À proximité"
L.UI_LAST_SEEN = "Vu pour la dernière fois"
L.UI_CLASS = "Classe"
L.UI_NAME = "Nom"
L.UI_NEARBY_AUTOHIDE = "Masquer si vide"
L.UI_DISABLE_GOBLIN_TOWNS = "Désactiver les alertes à Baie-du-Butin / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Baie-du-Butin"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FRAME = "Fenêtre Proches"
L.UI_NEARBY_LOCK = "Verrouiller la fenêtre"
L.UI_NEARBY_SCALE = "Échelle de la fenêtre"
L.UI_NEARBY_NAME_FONT = "Police des noms à proximité"
L.UI_NEARBY_NAME_SIZE = "Taille de police des noms à proximité"
L.UI_NEARBY_RANGE_CLAMP = "Portée de détection (style Classic)"

L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Options"
L.UI_REMOVE = "Retirer"
L.UI_SOUND = "Son"
L.UI_STEALTH = "Détection furtive"
L.UI_STEALTH_ADD_NEARBY = "Ajouter les furtifs à la liste Proches"
L.UI_STEALTH_BANNER = "Afficher l'alerte centrale"
L.UI_STEALTH_CHAT = "Notification dans le chat"
L.UI_STEALTH_ENABLE = "Activer la détection furtive"
L.UI_STEALTH_FADE = "Fondu de l'alerte (s)"
L.UI_STEALTH_HOLD = "Durée de l'alerte (s)"
L.UI_STEALTH_SOUND = "Jouer le son de furtivité"
L.UI_STEALTH_FLASH = "Flash écran en furtivité"
L.UI_SYNC = "Synchroniser"
L.UI_TAB_ATTACKERS = "Assaillants"
L.UI_TAB_GUILDS = "Guildes"
L.UI_TAB_PLAYERS = "Joueurs"
L.UI_TAB_STATS = "Statistiques"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "Retirer KoS"
L.UI_CLEAR_NEARBY = "Vider la liste proche"
L.UI_NEARBY_COUNT = "Proches : %d"
L.UI_ADD_KOS_TARGET = "Ajouter KoS (cible)"
L.ERR_NO_PLAYER_TARGET = "Aucun joueur ciblé."
L.UI_BANNER_TIMING = "Durée de l'alerte"
L.UI_BANNER_HOLD_HELP = "Durée pendant laquelle l'alerte reste entièrement visible avant de s'estomper."
L.UI_BANNER_FADE_HELP = "Durée de l'estompage progressif de l'alerte."
L.UI_LIST_PLAYERS = "Joueurs : %s"
L.UI_LIST_GUILDS = "Guildes : %s"

L.MSG_LOADED = "Chargé. Tapez /kos show"
L.UI_NEARBY_HEADER = "Nom / Niveau / Heure"

L.STEALTH_DETECTED_TITLE = "Joueur en camouflage détecté !"

L.UI_STATS_TITLE = "Statistiques des ennemis"
L.UI_STATS_KOS_TAG = "KoS"
L.UI_TAG_KOS = "KoS"
L.UI_TAG_GUILD = "Guilde"
L.UI_STATS_KOS_ONLY = "KoS uniquement"
L.UI_STATS_PVP_ONLY = "JcJ uniquement"
L.UI_STATS_RESET = "Réinitialiser"
L.UI_STATS_SEEN = "Vu"
L.UI_STATS_WINS = "Victoire"
L.UI_STATS_LOSES = "Défaite"
L.UI_STATS_RESET_CONFIRM = "Réinitialiser les statistiques des ennemis ?"
L.UI_STATS_FIRSTSEEN = "Première vue"
L.UI_STATS_SORT_LASTSEEN = "Dernière vue"
L.UI_STATS_SORT_NAME = "Nom"
L.UI_STATS_SORT_SEEN = "Vu"
L.UI_STATS_SORT_WINS = "Victoires"
L.UI_STATS_SORT_LOSES = "Défaites"

L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "Clic gauche : Ouvrir/Fermer"
L.TT_MINIMAP_RIGHTCLICK = "Clic droit : Menu"
L.TT_KOS = "Tuer à vue"
L.TT_GUILD = "Guilde"
L.TT_NOT_TARGETABLE = "Impossible à cibler pour le moment"
L.TT_GUILD_KOS = "KoS de guilde"
L.TT_LEVEL_FMT = "Niveau %s"

L.UI_NEARBY_SOUND = "Son de la liste à proximité"

L.UI_ATTACKERS_TITLE = "Assaillants"

-- Notes / Spy import
L.UI_NOTE = L.UI_NOTE or "Note"
L.UI_NOTE_EDIT = L.UI_NOTE_EDIT or "Edit Note"
L.UI_NOTE_SAVE = L.UI_NOTE_SAVE or "Save"
L.UI_NOTE_CLEAR = L.UI_NOTE_CLEAR or "Clear"
L.UI_NOTE_CANCEL = L.UI_NOTE_CANCEL or "Cancel"
L.UI_NOTE_EMPTY = L.UI_NOTE_EMPTY or "(No note)"
L.UI_IMPORTSPY_NONE = L.UI_IMPORTSPY_NONE or "Spy import complete - no new KoS entries found."
L.UI_IMPORTSPY_RESULT = L.UI_IMPORTSPY_RESULT or "Spy import complete: %d added, %d already existed."
L.UI_NOTES = "Notes"

L.UI_NEARBY_BG_DARKNESS = "Opacité du fond de la fenêtre À proximité"

-- Battleground options
L.UI_BATTLEGROUNDS = "Champs de bataille"
L.UI_BG_MUTE_SOUNDS = "Couper tous les sons de notification en champs de bataille"
