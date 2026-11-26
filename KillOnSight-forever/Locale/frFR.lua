-- Locale/frFR.lua
local ADDON_NAME = ...
KillOnSight_L_data = KillOnSight_L_data or {}
KillOnSight_L = KillOnSight_L or {}

if not KillOnSight_L.__kos_proxy then
  KillOnSight_L.__kos_proxy = true
  setmetatable(KillOnSight_L, {
    __index = function(_, k)
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
L.CMD_HELP = "Commandes : /kos help | show | add [nom] | remove <nom> | addguild <guilde> | removeguild <guilde> | list | statsprune"
L.GUILD_KOS = "KoS-Guilde"
L.HIDDEN = "Camouflé"
L.KOS = "KoS"
L.NOT_FOUND = "Introuvable : %s"
L.REMOVED_GUILD = "Guilde retirée : %s"
L.REMOVED_PLAYER = "Joueur retiré : %s"
L.SEEN = "%s repéré à proximité : %s%s"
L.SEEN_GUILD = "Guilde de %s à proximité : %s (%s)%s"
L.SEEN_HIDDEN = "Camouflé détecté : %s"
L.UI_ADD = "Add"
L.UI_ADD_GUILD = "Ajouter une guilde"
L.UI_ADD_KOS = "Ajouter KoS"
L.UI_ALERT_NEW = "Alert on new nearby enemy"
L.UI_ATTACKED_AT = "Attaqué"
L.UI_CLEAR = "Effacer"
L.UI_CLOSE = "Fermer"
L.UI_SHARE = "Partager"
L.UI_SHARE_DIALOG_TITLE = "Partager l’entrée sélectionnée"
L.UI_SHARE_COPY_HINT = "Appuyez sur Ctrl+C pour copier ce message, collez-le dans le chat puis appuyez sur Entrée."
L.UI_SHARE_IMPORT = "Importer"
L.UI_SHARE_CANCEL = "Annuler"
L.UI_SHARE_IMPORT_KOS_TITLE = "Importer cette cible KoS ?"
L.UI_SHARE_IMPORT_GUILD_TITLE = "Importer cette guilde KoS ?"
L.UI_SHARE_IMPORT_HONOR_TITLE = "Importer cette entrée Honor ?"
L.UI_SHARE_REVIEW_KOS = "Vérifiez ce nom. L’import l’ajoute à votre liste KoS."
L.UI_SHARE_REVIEW_GUILD = "Vérifiez cette guilde. L’import l’ajoute à votre liste Guild KoS."
L.UI_SHARE_REVIEW_HONOR = "Vérifiez ce nom. L’import l’ajoute à votre liste Honor."
L.UI_SHARE_SELECT_ONE = "Sélectionnez une entrée à partager."
L.UI_SHARE_IMPORTED = "%d nouvelles entrées importées."
L.UI_SHARE_TARGET_LABEL = "Partage de cible KoS"
L.UI_SHARE_GUILD_LABEL = "Partage de guilde KoS"
L.UI_SHARE_HONOR_LABEL = "Partage Honor"
L.UI_FLASH = "Clignoter"
L.UI_GUILD = "Guilde"
L.UI_FACTION = "Faction"
L.UI_INSTANCES = "Notifier en instance"
L.UI_LAST_SEEN = "Vu pour la dernière fois"
L.UI_CLASS = "Classe"
L.UI_NAME = "Nom"
L.UI_NEARBY_ALPHA = "Transparence"
L.UI_NEARBY_AUTOHIDE = "Masquer si vide"
L.UI_DISABLE_GOBLIN_TOWNS = "Désactiver les alertes à Baie-du-Butin / Gadgetzan"
L.SUBZONE_BOOTY_BAY = "Baie-du-Butin"
L.SUBZONE_GADGETZAN = "Gadgetzan"
L.UI_NEARBY_FADE = "Fondu entrée/sortie"
L.UI_NEARBY_FRAME = "Fenêtre Proches"
L.UI_NEARBY_LOCK = "Verrouiller la fenêtre"
L.UI_NEARBY_MINIMAL = "Fenêtre Proches ultra-minimale"
L.UI_NEARBY_ROWFADE = "Minuteries de fondu par ligne"
L.UI_NEARBY_ROWICONS = "Icônes de ligne (classe/crâne)"
L.UI_NEARBY_SCALE = "Échelle de la fenêtre"
L.UI_NEARBY_BACKGROUND = "Arrière-plan (Proximité)"
L.UI_NEARBY_NAME_FONT = "Police des noms à proximité"
L.UI_NEARBY_NAME_SIZE = "Taille de police des noms à proximité"
L.UI_NEARBY_MAX_ROWS = "Lignes max. à proximité"
L.UI_OPTIONS = "Options"

L.UI_OPTIONS_TITLE = "Options"
L.UI_REMOVE = "Remove"
L.UI_SOUND = "Son"
L.UI_ALERT_VOLUME = "Volume des alertes"
L.UI_STEALTH = "Détection furtive"
L.UI_STEALTH_ADD_NEARBY = "Ajouter les furtifs à la liste Proches"
L.UI_STEALTH_BANNER = "Afficher l’alerte centrale"
L.UI_STEALTH_ENABLE = "Activer la détection furtive"
L.UI_STEALTH_FADE = "Fondu de l’alerte (s)"
L.UI_STEALTH_HOLD = "Durée de l’alerte (s)"
L.UI_STEALTH_SOUND = "Jouer le son de furtivité"
L.UI_TAB_ATTACKERS = "Assaillants"
L.UI_TAB_GUILDS = "Guildes"
L.UI_TAB_PLAYERS = "Joueurs"
L.UI_TAB_STATS = "Statistiques"
L.UI_THROTTLE = "Limitation (s)"
L.UI_TITLE = "Kill on Sight"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_REMOVE_KOS = "Retirer KoS"
L.UI_CLEAR_NEARBY = "Vider la liste proche"
L.UI_NEARBY_COUNT = "Proches : %d"
L.UI_ADD_KOS_TARGET = "Ajouter KoS (cible)"
L.ERR_NO_PLAYER_TARGET = "Aucun joueur ciblé."
L.UI_BANNER_TIMING = "Durée de l’alerte"
L.UI_BANNER_HOLD_HELP = "Durée pendant laquelle l’alerte reste entièrement visible avant de s’estomper."
L.UI_BANNER_FADE_HELP = "Durée de l’estompage progressif de l’alerte."
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

L.TT_MINIMAP_TITLE = 'Kill on Sight'

L.TT_MINIMAP_LEFTCLICK = 'Clic gauche : Ouvrir/Fermer'

L.TT_MINIMAP_RIGHTCLICK = 'Clic droit : Menu'

L.TT_ON_KOS = 'Sur la liste KoS'

L.TT_GUILD_KOS = 'KoS de guilde'

L.TT_LEVEL_FMT = 'Niveau %s'

L.UI_STEALTH_CHAT = "Chat notification"

L.UI_NEARBY_SOUND = "Nearby list sound"


-- Added/updated for new 3.0.x UI & features
L.UI_ADD = "Ajouter"
L.UI_REMOVE = "Retirer"
L.UI_OPTIONS = "Options"
L.UI_TYPE = "Type"
L.UI_ZONE = "Zone"
L.UI_ALERT_NEW = "Alerter lors d'un nouvel ennemi à proximité"
L.UI_STEALTH_CHAT = "Notification dans le chat"
L.UI_NEARBY_SOUND = "Son de la liste à proximité"
L.UI_ALERTS = "KoS / Guilde"
L.UI_TARGETED_ALERTS_HEADING = "Alertes de ciblage"
L.UI_NEARBY_HEADING = "À proximité"
L.TT_MINIMAP_TITLE = "Kill on Sight"
L.TT_MINIMAP_LEFTCLICK = "Clic gauche : Ouvrir/Fermer"
L.TT_MINIMAP_RIGHTCLICK = "Clic droit : Menu"
L.TT_ON_KOS = "Sur la liste KoS"
L.TT_GUILD_KOS = "KoS de guilde"
L.TT_LEVEL_FMT = "Niveau %s"
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

L.RETAIL_NEARBY_LIMITED_NAMEPLATES_OFF = "La détection Proximité est limitée car les barres de nom ennemies sont DÉSACTIVÉES. Activez les barres de nom ennemies (Interface > Noms) pour une détection complète. Vous pouvez les basculer avec la touche V."
L.NEARBY_DISABLED_INSTANCE = "Nearby est désactivé dans les champs de bataille et les arènes."
L.TT_SPEC_LOADING = "Inspection…"

-- Profiles (options presets)
L.UI_PROFILES = L.UI_PROFILES or "Profiles"
L.UI_PROFILE_NEW = L.UI_PROFILE_NEW or "New"
L.UI_PROFILE_COPY = L.UI_PROFILE_COPY or "Copy"
L.UI_PROFILE_RESET = L.UI_PROFILE_RESET or "Reset"
L.UI_PROFILE_DELETE = L.UI_PROFILE_DELETE or "Delete"

-- Profiles UI
L.UI_PROFILE_NEW_NAME = "Entrez un nom pour le nouveau profil :"

-- Nearby right-click announcements (v3.4.9)
L.UI_ANNOUNCE = "Annoncer"
L.UI_ANNOUNCE_SAY = "Dire"
L.UI_ANNOUNCE_PARTY = "Groupe"
L.UI_ANNOUNCE_RAID = "Raid"
L.UI_ANNOUNCE_GUILD = "Guilde"
L.UI_ANNOUNCE_LOCAL = "Défense locale"


-- Honor list and Stats actions (v3.5.1)
L.UI_TAB_HONOR = "Honneur"
L.UI_ADD_HONOR = "Ajouter à la liste d’honneur"
L.UI_REMOVE_HONOR = "Retirer de la liste d’honneur"
L.UI_ADD_GUILD_KOS = "Ajouter la guilde à la liste KoS"
L.UI_HONOURED = "Honoré"
L.UI_HON_TAG = "Hon"

L.UI_TARGETED_ALERT = "Un ennemi vous cible"
L.UI_TARGETED_WARNING = "UN ENNEMI VOUS CIBLE : %s"

-- Enemy-targeting sound selector (English fallback where translation is pending).
L.UI_TARGET_SOUND_SELECT = L.UI_TARGET_SOUND_SELECT or 'Targeting sound'
L.UI_TARGET_SOUND_PREVIEW = L.UI_TARGET_SOUND_PREVIEW or 'Preview'
L.UI_TARGET_SOUND_HIGH_THREAT = L.UI_TARGET_SOUND_HIGH_THREAT or 'High Threat (Default)'
L.UI_TARGET_SOUND_NEARBY = L.UI_TARGET_SOUND_NEARBY or 'Nearby Detection'
L.UI_TARGET_SOUND_RADAR = L.UI_TARGET_SOUND_RADAR or 'Radar Sweep'
L.UI_TARGET_SOUND_SIREN = L.UI_TARGET_SOUND_SIREN or 'Warning Siren'
L.UI_TARGET_SOUND_PULSE = L.UI_TARGET_SOUND_PULSE or 'Double Pulse'
L.UI_TARGET_SOUND_CHIME = L.UI_TARGET_SOUND_CHIME or 'Alert Chime'

-- Profile actions and Guild-KoS removal labels.
L.UI_PROFILE_EDIT = 'Modifier'
L.UI_PROFILE_RENAME = 'Renommer le profil :'
L.UI_PROFILE_ERR_EMPTY = 'Le nom ne peut pas être vide.'
L.UI_PROFILE_ERR_EXISTS = 'Un profil portant ce nom existe déjà.'
L.UI_PROFILE_ERR_INVALID = 'Ce nom ne peut pas être utilisé.'
L.UI_REMOVE_GUILD_KOS = 'Retirer la guilde de la liste KoS'
L.UI_NEARBY_LAST_NAMES = "Afficher les noms de famille dans Nearby"
