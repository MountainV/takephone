Config = {}

-- Zusätzliche Ausgaben in Server-Konsole und F8 (zum Fehlersuchen, später auf false)
Config.Debug = true

-- Standardtaste (Spieler können sie unter Einstellungen > Tastenbelegung > FiveM ändern)
Config.OpenKey = 'F5'

-- Laufen, während das Menü offen ist (Bedienung dann mit Pfeiltasten + Enter, ohne Maus)
-- false = Menü mit Mauszeiger, dafür steht man still
Config.WalkWhileMenu = true

-- Maximale Entfernung zum nächsten Spieler (Zeigen / Geben)
Config.MaxDistance = 3.0

-- Wie lange (Sekunden) ein Dokument sichtbar bleibt
-- 0 = bleibt offen, bis man ENTF (oder Backspace) drückt
Config.ShowDuration = 0

-- Dürfen Dokumente (mit Item) an andere Spieler übergeben werden?
Config.AllowGive = true

-- Animation beim Zeigen / Geben abspielen
Config.UseAnimation = true

-- Banner oben im Menü
--   image = Bild im Ordner html/img/ (z.B. 'img/banner.png') oder ein Link (https://...)
--           Empfohlene Größe: 432 x 96 Pixel (oder 864 x 192 für scharfe Darstellung)
--   text  = Text auf dem Banner ('' = kein Text, z.B. wenn das Bild schon Text hat)
--   color = Hintergrundfarbe, wenn kein Bild gesetzt ist
Config.Banner = {
    image = nil,
    text = 'Persönlich',
    color = '#2a5aa8'
}

-- Angaben auf den Karten
Config.Country = 'LOS SANTOS'
Config.CountryCode = 'LS'
Config.Authority = 'STADT LOS SANTOS'
Config.DefaultBirthplace = 'LOS SANTOS'
Config.DefaultNationality = 'LOS SANTOS'

-- Dokumente:
--   template = Aussehen der Karte ('id', 'driver', 'weapon')
--   item = nil  -> immer verfügbar (z.B. Perso ohne Item)
--   item = 'x'  -> nur sichtbar, wenn der Spieler das Item besitzt
-- Hinweis QBCore: Standard-Itemname für den Waffenschein ist 'weaponlicense'
Config.Documents = {
    {
        id = 'id',
        label = 'Personalausweis',
        template = 'id',
        item = nil,          -- z.B. 'id_card', wenn der Perso auch ein Item sein soll
        prefix = 'L',
        validYears = 10
    },
    {
        id = 'driver',
        label = 'Führerschein',
        template = 'driver',
        item = 'driver_license',
        prefix = 'B',
        validYears = 15,
        classes = 'AM, A1, B, L'
    },
    {
        id = 'weapon',
        label = 'Waffenbesitzkarte',
        template = 'weapon',
        item = 'weapon_license',
        prefix = 'W',
        validYears = 5,
        classes = 'KURZWAFFEN'
    }
}
