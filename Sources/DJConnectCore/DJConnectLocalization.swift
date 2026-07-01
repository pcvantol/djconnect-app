import Foundation

public enum DJConnectLocalization {
    public static let supportedLanguageCodes = ["en", "nl", "de", "fr", "es"]
    public static let englishLanguageCode = "en"
    public static let dutchLanguageCode = "nl"

    public static func localized(language: String, english: String, dutch: String) -> String {
        let code = supportedLanguageCode(language)
        if code == dutchLanguageCode {
            return dutch
        }
        return translations[english]?[code] ?? english
    }

    public static func localized(locale: Locale = .current, english: String, dutch: String) -> String {
        localized(language: locale.language.languageCode?.identifier ?? "", english: english, dutch: dutch)
    }

    public static func localized(key: String, language: String, fallback: String, arguments: CVarArg...) -> String {
        let format = translations[key]?[supportedLanguageCode(language)] ?? fallback
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: Locale(identifier: supportedLanguageCode(language)), arguments: arguments)
    }

    public static func preferredLanguageCode(_ preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let preferredLanguage = preferredLanguages.first?.lowercased() ?? ""
        return supportedLanguageCode(preferredLanguage)
    }

    public static func supportedLanguageCode(_ language: String) -> String {
        let normalized = normalizedLanguageCode(language)
        return supportedLanguageCodes.contains(normalized) ? normalized : englishLanguageCode
    }

    public static func normalizedLanguageCode(_ language: String) -> String {
        language
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init)?
            .lowercased() ?? ""
    }

    private static let translations: [String: [String: String]] = [
        "About": [
            "de": "Info",
            "fr": "A propos",
            "es": "Acerca de"
        ],
        "About DJConnect": [
            "de": "Uber DJConnect",
            "fr": "A propos de DJConnect",
            "es": "Acerca de DJConnect"
        ],
        "Allow Camera": [
            "de": "Kamera erlauben",
            "fr": "Autoriser la camera",
            "es": "Permitir camara"
        ],
        "Allow notifications": [
            "de": "Mitteilungen erlauben",
            "fr": "Autoriser les notifications",
            "es": "Permitir notificaciones"
        ],
        "Ask DJ": [
            "de": "Ask DJ",
            "fr": "Ask DJ",
            "es": "Ask DJ"
        ],
        "Ask DJ answered": [
            "de": "Ask DJ hat geantwortet",
            "fr": "Ask DJ a repondu",
            "es": "Ask DJ ha respondido"
        ],
        "Ask DJ is unreachable": [
            "de": "Ask DJ ist nicht erreichbar",
            "fr": "Ask DJ est inaccessible",
            "es": "Ask DJ no esta disponible"
        ],
        "Ask DJ notifications": [
            "de": "Ask DJ-Mitteilungen",
            "fr": "Notifications Ask DJ",
            "es": "Notificaciones de Ask DJ"
        ],
        "Ask something about the music or give your DJ a command.": [
            "de": "Frag etwas zur Musik oder gib deinem DJ einen Befehl.",
            "fr": "Pose une question sur la musique ou donne une consigne a ton DJ.",
            "es": "Pregunta algo sobre la musica o dale una orden a tu DJ."
        ],
        "Camera": [
            "de": "Kamera",
            "fr": "Camera",
            "es": "Camara"
        ],
        "Camera access for pairing": [
            "de": "Kamerazugriff zum Koppeln",
            "fr": "Acces camera pour l'association",
            "es": "Acceso a la camara para enlazar"
        ],
        "Cancel": [
            "de": "Abbrechen",
            "fr": "Annuler",
            "es": "Cancelar"
        ],
        "Clear Logs?": [
            "de": "Protokolle loschen?",
            "fr": "Effacer les journaux ?",
            "es": "Borrar registros?"
        ],
        "Close": [
            "de": "Schliessen",
            "fr": "Fermer",
            "es": "Cerrar"
        ],
        "Connected": [
            "de": "Verbunden",
            "fr": "Connecte",
            "es": "Conectado"
        ],
        "Continue": [
            "de": "Fortfahren",
            "fr": "Continuer",
            "es": "Continuar"
        ],
        "Done": [
            "de": "Fertig",
            "fr": "Termine",
            "es": "Listo"
        ],
        "Enter the Home Assistant URL and pair code.": [
            "de": "Gib die Home Assistant-URL und den Kopplungscode ein.",
            "fr": "Saisis l'URL Home Assistant et le code d'association.",
            "es": "Introduce la URL de Home Assistant y el codigo de enlace."
        ],
        "Home Assistant is unreachable.": [
            "de": "Home Assistant ist nicht erreichbar.",
            "fr": "Home Assistant est inaccessible.",
            "es": "Home Assistant no esta disponible."
        ],
        "Koppeling verwijderd.": [
            "de": "Kopplung entfernt.",
            "fr": "Association supprimee.",
            "es": "Enlace eliminado."
        ],
        "Legal": [
            "de": "Rechtliches",
            "fr": "Mentions legales",
            "es": "Legal"
        ],
        "Loading release notes...": [
            "de": "Versionshinweise werden geladen...",
            "fr": "Chargement des notes de version...",
            "es": "Cargando notas de la version..."
        ],
        "Manual": [
            "de": "Manuell",
            "fr": "Manuel",
            "es": "Manual"
        ],
        "More": [
            "de": "Mehr",
            "fr": "Plus",
            "es": "Mas"
        ],
        "Music DNA": [
            "de": "Music DNA",
            "fr": "Music DNA",
            "es": "Music DNA"
        ],
        "Next": [
            "de": "Weiter",
            "fr": "Suivant",
            "es": "Siguiente"
        ],
        "No connection to Home Assistant": [
            "de": "Keine Verbindung zu Home Assistant",
            "fr": "Aucune connexion a Home Assistant",
            "es": "Sin conexion con Home Assistant"
        ],
        "Not connected to Home Assistant": [
            "de": "Nicht mit Home Assistant verbunden",
            "fr": "Non associe a Home Assistant",
            "es": "No enlazado con Home Assistant"
        ],
        "Not now": [
            "de": "Jetzt nicht",
            "fr": "Pas maintenant",
            "es": "Ahora no"
        ],
        "Now Playing": [
            "de": "Lauft gerade",
            "fr": "Lecture",
            "es": "Sonando"
        ],
        "Pair code is incorrect. Check the code in Home Assistant.": [
            "de": "Der Kopplungscode ist falsch. Prufe den Code in Home Assistant.",
            "fr": "Le code d'association est incorrect. Verifie le code dans Home Assistant.",
            "es": "El codigo de enlace no es correcto. Compruebalo en Home Assistant."
        ],
        "Pair with Home Assistant": [
            "de": "Mit Home Assistant koppeln",
            "fr": "Associer a Home Assistant",
            "es": "Enlazar con Home Assistant"
        ],
        "Pairing is stale. Open Home Assistant setup and enter the new pair code here.": [
            "de": "Die Kopplung ist abgelaufen. Offne die Home Assistant-Einrichtung und gib hier den neuen Code ein.",
            "fr": "L'association a expire. Ouvre la configuration Home Assistant et saisis ici le nouveau code.",
            "es": "El enlace ha caducado. Abre la configuracion de Home Assistant e introduce aqui el nuevo codigo."
        ],
        "Pairing successful": [
            "de": "Kopplung erfolgreich",
            "fr": "Association reussie",
            "es": "Enlace correcto"
        ],
        "Previous": [
            "de": "Zuruck",
            "fr": "Precedent",
            "es": "Anterior"
        ],
        "Privacy": [
            "de": "Datenschutz",
            "fr": "Confidentialite",
            "es": "Privacidad"
        ],
        "Queue": [
            "de": "Warteschlange",
            "fr": "File d'attente",
            "es": "Cola"
        ],
        "Refresh": [
            "de": "Aktualisieren",
            "fr": "Actualiser",
            "es": "Actualizar"
        ],
        "Settings": [
            "de": "Einstellungen",
            "fr": "Reglages",
            "es": "Ajustes"
        ],
        "Skip": [
            "de": "Uberspringen",
            "fr": "Ignorer",
            "es": "Omitir"
        ],
        "Start Demo Mode": [
            "de": "Demo-Modus starten",
            "fr": "Demarrer le mode demo",
            "es": "Iniciar modo demo"
        ],
        "Track Insight": [
            "de": "Track Insight",
            "fr": "Track Insight",
            "es": "Track Insight"
        ],
        "Update Required": [
            "de": "Update erforderlich",
            "fr": "Mise a jour requise",
            "es": "Actualizacion necesaria"
        ],
        "Voice request": [
            "de": "Sprachanfrage",
            "fr": "Demande vocale",
            "es": "Solicitud de voz"
        ],
        "What's New": [
            "de": "Neuigkeiten",
            "fr": "Nouveautes",
            "es": "Novedades"
        ],
        "pairing.error.clientTypeMismatch": [
            "en": "The app type selected in Home Assistant does not match this app. Choose the DJConnect %@ setup flow, then try again.",
            "nl": "Het gekozen app-type in Home Assistant klopt niet met deze app. Kies in Home Assistant de DJConnect %@ setup-flow en probeer opnieuw.",
            "de": "Der in Home Assistant gewahlte App-Typ passt nicht zu dieser App. Wahle den DJConnect %@-Setup-Flow und versuche es erneut.",
            "fr": "Le type d'app choisi dans Home Assistant ne correspond pas a cette app. Choisis le flux de configuration DJConnect %@, puis reessaie.",
            "es": "El tipo de app elegido en Home Assistant no coincide con esta app. Elige el flujo de configuracion DJConnect %@ e intentalo de nuevo."
        ],
        "pairing.error.invalidClientType": [
            "en": "Wrong app type selected in Home Assistant. Choose the DJConnect %@ setup flow and use its new pair code.",
            "nl": "Verkeerd app-type gekozen in Home Assistant. Kies de DJConnect %@ setup-flow en gebruik de nieuwe koppelcode.",
            "de": "Falscher App-Typ in Home Assistant gewahlt. Wahle den DJConnect %@-Setup-Flow und verwende den neuen Kopplungscode.",
            "fr": "Mauvais type d'app choisi dans Home Assistant. Choisis le flux DJConnect %@ et utilise son nouveau code.",
            "es": "Tipo de app incorrecto en Home Assistant. Elige el flujo DJConnect %@ y usa su nuevo codigo."
        ],
        "pairing.error.invalidPairCode": [
            "en": "Pair code is incorrect. Check the code in Home Assistant.",
            "nl": "Koppelcode klopt niet. Controleer de code in Home Assistant.",
            "de": "Der Kopplungscode ist falsch. Prufe den Code in Home Assistant.",
            "fr": "Le code d'association est incorrect. Verifie le code dans Home Assistant.",
            "es": "El codigo de enlace no es correcto. Compruebalo en Home Assistant."
        ],
        "pairing.error.notConfigured": [
            "en": "DJConnect is not configured in Home Assistant yet. Open the DJConnect setup flow first.",
            "nl": "DJConnect is nog niet geconfigureerd in Home Assistant. Open eerst de DJConnect setup-flow.",
            "de": "DJConnect ist in Home Assistant noch nicht eingerichtet. Offne zuerst den DJConnect-Setup-Flow.",
            "fr": "DJConnect n'est pas encore configure dans Home Assistant. Ouvre d'abord le flux de configuration DJConnect.",
            "es": "DJConnect aun no esta configurado en Home Assistant. Abre primero el flujo de configuracion de DJConnect."
        ],
        "pairing.error.unauthorized": [
            "en": "Home Assistant rejected this app. Pair DJConnect again from Home Assistant.",
            "nl": "Home Assistant weigert deze app. Koppel DJConnect opnieuw vanuit Home Assistant.",
            "de": "Home Assistant hat diese App abgelehnt. Kopple DJConnect erneut aus Home Assistant.",
            "fr": "Home Assistant a refuse cette app. Associe DJConnect a nouveau depuis Home Assistant.",
            "es": "Home Assistant ha rechazado esta app. Vuelve a enlazar DJConnect desde Home Assistant."
        ],
        "pairing.error.staleAuth": [
            "en": "This pairing is no longer valid. Generate a new pair code in Home Assistant and try again.",
            "nl": "Deze koppeling is niet meer geldig. Genereer een nieuwe koppelcode in Home Assistant en probeer opnieuw.",
            "de": "Diese Kopplung ist nicht mehr gultig. Erzeuge in Home Assistant einen neuen Code und versuche es erneut.",
            "fr": "Cette association n'est plus valide. Genere un nouveau code dans Home Assistant et reessaie.",
            "es": "Este enlace ya no es valido. Genera un codigo nuevo en Home Assistant e intentalo de nuevo."
        ],
        "pairing.error.generic": [
            "en": "Pairing could not be completed. Check Home Assistant and try again.",
            "nl": "Koppelen is niet gelukt. Controleer Home Assistant en probeer opnieuw.",
            "de": "Die Kopplung konnte nicht abgeschlossen werden. Prufe Home Assistant und versuche es erneut.",
            "fr": "L'association n'a pas pu etre terminee. Verifie Home Assistant et reessaie.",
            "es": "No se pudo completar el enlace. Comprueba Home Assistant e intentalo de nuevo."
        ]
    ]
}
