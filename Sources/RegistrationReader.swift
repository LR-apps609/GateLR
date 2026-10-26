import Foundation

/// «Fotografa il libretto»: dal testo della carta di circolazione europea armonizzata (libretto italiano,
/// Zulassungsbescheinigung Teil I, certificat d'immatriculation, permiso de circulación, kentekenbewijs…)
/// ricava targa (A), prima immatricolazione (B), marca (D.1), modello (D.3), alimentazione (P.3) e classe
/// ambientale (V.9). Niente fotocamera qui: si prova con i test, anche con il testo sporco di una foto.
enum RegistrationReader {
    /// Da dove viene la classe Euro: dal documento (V.9 o «EURO n» scritto), dall'anno, o non trovata
    enum EuroSource: String, Equatable { case document, year, none }

    struct Result: Equatable {
        var plate: String?
        var make: String?
        var model: String?
        var year: Int?
        var month: Int?
        var day: Int?
        var fuel: Fuel?
        var fuelText: String?
        var emissionText: String?
        var euro: Int?
        var euroSource: EuroSource = .none
        var understood: Bool { plate != nil || make != nil || model != nil || fuel != nil || year != nil || euroSource == .document }
    }

    enum Code: String { case a = "A", b = "B", d1 = "D.1", d3 = "D.3", p3 = "P.3", v9 = "V.9" }

    /// I codici dei campi, anche come li legge una foto: «D.1», «D1», «0.1», «D.l», «P3», «V9», «Y.9», «(A)».
    /// A e B, lettere da sole, valgono solo all'inizio di un pezzo di riga (inizio riga, dopo due spazi o una parentesi).
    static let codePattern = #"(?:(?:^|\s{2,}|\()([AB])(?:\s*[.:)])?(?=\s|$)|(?<![A-Z0-9])((?:D\s?[.,]\s?|[0O]\s?[.,]\s?)[1IL3]|D\s?[13]|P\s?[.,]?\s?3|[VY]\s?[.,]?\s?9)(?![A-Z0-9]))"#

    /// Le etichette stampate accanto ai codici, nelle varie lingue: si tolgono dal valore
    static let labels: [String] = [
        "DATA DI PRIMA IMMATRICOLAZIONE", "DATA PRIMA IMMATRICOLAZIONE", "PRIMA IMMATRICOLAZIONE", "DATUM DER ERSTZULASSUNG", "ERSTZULASSUNG",
        "DATE DE PREMIERE IMMATRICULATION", "DATE DE 1ERE IMMATRICULATION", "FECHA DE PRIMERA MATRICULACION", "FECHA PRIMERA MATRICULACION",
        "DATUM EERSTE TOELATING", "DATUM EERSTE INSCHRIJVING",
        "NUMERO D'IMMATRICULATION", "AMTLICHES KENNZEICHEN", "KENNZEICHEN", "IMMATRICULATION", "MATRICULA", "KENTEKEN", "TARGA",
        "DENOMINAZIONE COMMERCIALE", "DENOMINATION COMMERCIALE", "DENOMINACION COMERCIAL", "HANDELSBEZEICHNUNG", "HANDELSBENAMING",
        "DENOMINAZIONE", "FABBRICA E TIPO", "FABBRICA", "MARCA", "MARKE", "MERK", "MARQUE", "MODELLO", "MODELO", "MODELE",
        "TIPO DI ALIMENTAZIONE", "ALIMENTAZIONE", "KRAFTSTOFFART ODER ENERGIEQUELLE", "KRAFTSTOFFART", "KRAFTSTOFF", "ENERGIEQUELLE",
        "SOURCE D'ENERGIE", "ENERGIE", "CARBURANTE", "COMBUSTIBLE", "CARBURANT", "BRANDSTOF",
        "CLASSE AMBIENTALE", "CLASSE ENVIRONNEMENTALE", "SCHADSTOFFKLASSE", "NIVEL DE EMISIONES", "NIVEL EMISIONES", "MILIEUKLASSE", "EMISSIECLASSIFICATIE",
    ].sorted { $0.count > $1.count }

    static func parse(_ raw: String, makes: [CarCatalog.Make] = CarCatalog.makes,
                      thisYear: Int = Calendar.current.component(.year, from: Date())) -> Result {
        let lines = DocumentText.fold(raw).components(separatedBy: .newlines)
            .map { DocumentText.trim($0) }.filter { !$0.isEmpty }
        let found = fields(lines, thisYear: thisYear)
        var r = Result()

        // A: la targa; senza il campo, una targa italiana ovunque nel testo
        r.plate = found[.a].flatMap { plate(in: $0) } ?? lines.lazy.compactMap { italianPlate(in: $0) }.first

        // B: la prima immatricolazione; senza il campo, una data sulla riga dell'etichetta
        let dateText = found[.b] ?? labelValue(lines, ["IMMATRICOLAZIONE", "ERSTZULASSUNG", "IMMATRICULATION", "MATRICULACION", "TOELATING"])
        if let d = dateText.flatMap({ DocumentText.dates(in: $0, thisYear: thisYear).first }) {
            r.year = d.year; r.month = d.month; r.day = d.day
        }

        // D.1 e D.3: marca e modello, con i nomi del catalogo quando li riconosce
        let makeText = found[.d1] ?? labelValue(lines, ["FABBRICA E TIPO", "FABBRICA", "MARCA", "MARKE", "MERK", "MARQUE"])
        if let m = makeText { r.make = make(from: m, makes: makes) }
        if let m = found[.d3] {
            r.model = model(from: m, make: r.make, makes: makes)
        } else if let m = makeText, let mk = r.make, DocumentText.compact(m).count > DocumentText.compact(mk).count + 1 {
            r.model = model(from: m, make: r.make, makes: makes)        // «FIAT PANDA» nella stessa riga della marca
        }

        // P.3: l'alimentazione; senza il campo, le parole lunghe nel resto del testo
        let fuelText = found[.p3] ?? labelValue(lines, ["ALIMENTAZIONE", "KRAFTSTOFF", "CARBURANT", "COMBUSTIBLE", "BRANDSTOF"])
        if let f = fuelText, let kind = fuel(from: f, strict: false) {
            r.fuel = kind; r.fuelText = f
        } else if let kind = fuel(from: lines.joined(separator: " "), strict: true) {
            r.fuel = kind
        }

        // V.9: la classe ambientale; poi «EURO n» scritto altrove (campo 14 tedesco, annotazioni); poi l'anno
        if let v = found[.v9], let e = euro(fromEmission: v) {
            r.euro = e; r.emissionText = v; r.euroSource = .document
        } else if let m = lines.lazy.compactMap({ DocumentText.first(#"EUR[O0]\s*[-:]?\s*([1-7])(?![0-9])[A-Z0-9\-]*"#, in: $0) }).first,
                  let e = m.group(1).flatMap({ Int($0) }) {
            r.euro = e; r.emissionText = m.group(0); r.euroSource = .document
        } else if let y = r.year {
            r.euro = CarCatalog.euro(forYear: y); r.euroSource = .year
            r.emissionText = found[.v9]
        }
        return r
    }

    // MARK: Campi

    static func code(of m: DocumentText.Match) -> Code? {
        if let ab = m.group(1) { return ab == "A" ? .a : .b }
        guard let c = m.group(2) else { return nil }
        if c.contains("P") { return .p3 }
        if c.contains("V") || c.contains("Y") { return .v9 }
        return c.hasSuffix("3") ? .d3 : .d1
    }

    /// Il primo valore accettabile di ogni campo: il testo dopo il codice fino al codice seguente,
    /// o la riga dopo se il codice è da solo
    static func fields(_ lines: [String], thisYear: Int) -> [Code: String] {
        var out: [Code: String] = [:]
        for (i, line) in lines.enumerated() {
            let found = DocumentText.matches(codePattern, in: line)
            let length = (line as NSString).length
            for (k, m) in found.enumerated() {
                guard let c = code(of: m), out[c] == nil else { continue }
                let end = k + 1 < found.count ? found[k + 1].range.location : length
                var value = clean(DocumentText.substring(line, from: m.end, to: end))
                if value.isEmpty, i + 1 < lines.count, DocumentText.matches(codePattern, in: lines[i + 1]).isEmpty {
                    value = clean(lines[i + 1])
                }
                if accept(value, for: c, thisYear: thisYear) { out[c] = value }
            }
        }
        return out
    }

    static func accept(_ value: String, for code: Code, thisYear: Int) -> Bool {
        switch code {
        case .a: return plate(in: value) != nil
        case .b: return !DocumentText.dates(in: value, thisYear: thisYear).isEmpty
        default: return DocumentText.contains("[A-Z0-9]", in: value)
        }
    }

    /// Senza etichette, punteggiatura ai bordi e testo di altri campi (dopo due spazi o un codice come «P.5», «C.1.1»)
    static func clean(_ raw: String) -> String {
        var v = DocumentText.trim(raw, ".:;)|-_*/")
        var changed = true
        while changed {
            changed = false
            for l in labels where v.hasPrefix(l) {
                let rest = String(v.dropFirst(l.count))
                if let c = rest.unicodeScalars.first, CharacterSet.letters.contains(c) { continue }
                v = DocumentText.trim(rest, ".:;)|-_*/(")
                changed = true
                break
            }
        }
        if let cut = DocumentText.first(#"\s{2,}|(?<![A-Z0-9])[A-Z](?:\s?[.,]\s?[0-9]{1,2}){1,2}(?![A-Z0-9])"#, in: v) {
            v = DocumentText.substring(v, from: 0, to: cut.range.location)
        }
        return DocumentText.trim(v, ".:;)|-_*/(")
    }

    /// Il valore dopo un'etichetta (sulla stessa riga o sulla riga dopo), per i libretti senza codici
    static func labelValue(_ lines: [String], _ keys: [String]) -> String? {
        for (i, line) in lines.enumerated() {
            for k in keys {
                guard let m = DocumentText.first("(?<![A-Z])" + NSRegularExpression.escapedPattern(for: k) + "(?![A-Z])", in: line) else { continue }
                var v = clean(DocumentText.substring(line, from: m.end, to: (line as NSString).length))
                if v.isEmpty, i + 1 < lines.count { v = clean(lines[i + 1]) }
                if !v.isEmpty { return v }
            }
        }
        return nil
    }

    // MARK: Targa

    /// «AB 123 CD», «AB123CD» (anche con O, I, S, B al posto delle cifre in mezzo) → «AB123CD»
    static func italianPlate(in s: String) -> String? {
        for m in DocumentText.matches(#"(?<![A-Z0-9])([A-Z]{2})\s?([0-9OISBZ]{3})\s?([A-Z]{2})(?![A-Z0-9])"#, in: s) {
            guard let a = m.group(1), let mid = m.group(2), let b = m.group(3),
                  mid.contains(where: { $0.isNumber }) else { continue }
            let digits = String(mid.map { c -> Character in
                switch c { case "O": "0"; case "I": "1"; case "S": "5"; case "B": "8"; case "Z": "2"; default: c }
            })
            return a + digits + b
        }
        return nil
    }

    /// La targa del campo A: italiana se lo è, altrimenti come stampata («M AB 1234», «AB-123-CD», «12-ABC-3», «1234 BCD»)
    static func plate(in value: String) -> String? {
        if let it = italianPlate(in: value) { return it }
        guard let m = DocumentText.first(#"^[A-Z0-9]{1,4}(?:[ \-][A-Z0-9]{1,4}){0,3}"#, in: value), let p = m.group(0) else { return nil }
        let chars = p.filter { $0 != " " && $0 != "-" }
        guard chars.count >= 4, chars.count <= 10, chars.contains(where: { $0.isNumber }), chars.contains(where: { $0.isLetter }) else { return nil }
        return p
    }

    // MARK: Marca e modello

    static let makeAliases: [String: String] = [
        "VW": "Volkswagen", "VOLKSWAGENVW": "Volkswagen", "MERCEDES": "Mercedes-Benz", "DAIMLER": "Mercedes-Benz",
        "DAIMLERCHRYSLER": "Mercedes-Benz", "DAIMLERBENZ": "Mercedes-Benz", "ALFA": "Alfa Romeo", "LANDROVER": "Land Rover",
        "BMWMINI": "Mini", "DSAUTOMOBILES": "DS", "SKODAAUTO": "Skoda", "FCA": "Fiat", "FIATAUTO": "Fiat",
    ]

    static func make(from value: String, makes: [CarCatalog.Make]) -> String {
        let c = DocumentText.compact(value)
        let names = makes.map(\.make)
        if let n = names.first(where: { DocumentText.compact($0) == c }) { return n }
        if let a = makeAliases[c] { return names.first { DocumentText.compact($0) == DocumentText.compact(a) } ?? a }
        if let n = names.filter({ c.hasPrefix(DocumentText.compact($0)) }).max(by: { DocumentText.compact($0).count < DocumentText.compact($1).count }) { return n }
        if let a = makeAliases.keys.filter({ c.hasPrefix($0) }).max(by: { $0.count < $1.count }).flatMap({ makeAliases[$0] }) { return a }
        return DocumentText.titled(value)
    }

    /// Il modello del catalogo più lungo con cui comincia il testo («YARIS CROSS HYBRID» → «Yaris Cross»), anche dopo la marca
    static func model(from value: String, make: String?, makes: [CarCatalog.Make]) -> String {
        var c = DocumentText.compact(value)
        if let mk = make.map(DocumentText.compact), !mk.isEmpty, c.hasPrefix(mk), c.count > mk.count { c = String(c.dropFirst(mk.count)) }
        let models = makes.first { $0.make == make }?.models ?? []
        func longest(_ list: [String]) -> String? { list.max { DocumentText.compact($0).count < DocumentText.compact($1).count } }
        if let m = longest(models.filter { !DocumentText.compact($0).isEmpty && c.hasPrefix(DocumentText.compact($0)) }) { return m }
        if let m = longest(models.filter { DocumentText.compact($0).count >= 3 && c.contains(DocumentText.compact($0)) }) { return m }
        var words = value.split(separator: " ").map(String.init)
        if let mk = make.map(DocumentText.compact), let first = words.first, DocumentText.compact(first) == mk, words.count > 1 { words.removeFirst() }
        return DocumentText.titled(words.joined(separator: " "))
    }

    // MARK: Alimentazione

    /// P.3 in italiano, tedesco, francese, spagnolo, olandese, inglese, e i codici francesi (ES, GO, EL, EH…).
    /// «strict»: per il resto del testo, solo parole lunghe e inconfondibili.
    static func fuel(from text: String, strict: Bool) -> Fuel? {
        let t = DocumentText.fold(text)
        let words = Set(t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        func has(_ parts: [String]) -> Bool { parts.contains { t.contains($0) } }
        func word(_ list: [String]) -> Bool { list.contains { words.contains($0) } }

        let electric = has(["ELETTRIC", "ELETTR", "ELEKTR", "ELECTRIQUE", "ELECTRICITE", "ELECTRICO", "ELECTRIC", "ELEKTRICITEIT"]) || (!strict && word(["EL", "BEV"]))
        let petrol = has(["BENZIN", "ESSENCE", "GASOLINA", "PETROL", "SANS PLOMB"]) || (!strict && word(["BENZ", "ES", "SUPER"]))
        let diesel = has(["GASOLIO", "DIESEL", "GAZOLE", "GASOLEO", "GASOIL"]) || (!strict && word(["GO"]))
        let gas = has(["GPL", "LPG", "METANO", "AUTOGAS", "ERDGAS", "AARDGAS", "GAS NATURAL", "GAZ NATUREL"]) || word(["GLP", "CNG", "GNC", "GNV"]) || (!strict && word(["GP", "GN", "EG"]))
        let hybrid = has(["IBRID", "HYBR", "HIBRID"]) || word(["PHEV", "HEV", "MHEV"]) || (!strict && word(["EH", "EE", "GH", "GL"]))

        if hybrid || (electric && (petrol || diesel)) { return .hybrid }
        if gas { return .lpg }
        if electric { return .electric }
        if diesel { return .diesel }
        if petrol { return .petrol }
        return nil
    }

    // MARK: Classe Euro

    /// Le direttive e i regolamenti scritti in V.9 e la classe Euro che vogliono dire (auto).
    /// a = classe con la lettera A o senza lettera, b = con la lettera B (es. 98/69 A = Euro 3, 98/69 B = Euro 4).
    static let directives: [(key: String, a: Int, b: Int)] = [
        ("91/441", 1, 1), ("93/59", 1, 1),
        ("94/12", 2, 2), ("96/69", 2, 2),
        ("98/69", 3, 4), ("98/77", 3, 4), ("1999/102", 3, 4), ("2001/1", 3, 4), ("2001/100", 3, 4),
        ("2002/80", 3, 4), ("2003/76", 3, 4), ("2006/96", 3, 4),
        ("715/2007", 5, 5), ("692/2008", 5, 5), ("566/2011", 5, 5),
        ("459/2012", 6, 6), ("630/2012", 6, 6), ("136/2014", 6, 6), ("2015/45", 6, 6), ("2016/427", 6, 6), ("2016/646", 6, 6),
        ("2017/1151", 6, 6), ("2017/1154", 6, 6), ("2017/1347", 6, 6), ("2018/1832", 6, 6), ("2020/49", 6, 6), ("2023/443", 6, 6),
        ("2024/1257", 7, 7),
    ]

    /// «EURO 6D-TEMP» → 6, «EURO VI» → 6, «70/220*2001/100A» → 3, «715/2007*692/2008EURO 5» → 5
    static func euro(fromEmission raw: String) -> Int? {
        var t = DocumentText.fold(raw)
        if let m = DocumentText.first(#"EUR[O0]\s*[-:]?\s*(?:([0-7])(?![0-9])|(VI|IV|V|III|II|I)(?![A-Z]))"#, in: t) {
            if let d = m.group(1).flatMap({ Int($0) }) { return d }
            if let roman = m.group(2) { return ["I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6][roman] }
        }
        // L'asterisco perso dalla foto («70/2202001/100B»): si rimette dopo la direttiva base
        t = t.replacingOccurrences(of: #"(70\s?/\s?220|715\s?/\s?2007)(?=[0-9])"#, with: "$1*", options: .regularExpression)
        var best: Int?
        for d in directives {
            let key = d.key.replacingOccurrences(of: "/", with: #"\s?/\s?"#)
            for m in DocumentText.matches("(?<![0-9])" + key + #"(?![0-9])\s?([A-Z]{1,2})?"#, in: t) {
                let suffix = m.group(1) ?? ""
                let e = suffix == "B" ? d.b : d.a
                best = max(best ?? 0, e)
            }
        }
        return best
    }
}

/// Un modello tipico delle flotte di noleggio in Italia (Resources/Rules/cars.json, «rental»)
struct RentalPreset: Codable, Hashable, Identifiable {
    var make: String
    var model: String
    var fuels: [Fuel]
    var euro: Int
    var id: String { make + " " + model }
}

extension CarCatalog {
    private struct RentalFile: Codable { var rental: [RentalPreset]? }

    static let rentals: [RentalPreset] = {
        guard let url = Bundle.main.url(forResource: "cars", withExtension: "json", subdirectory: "Rules"),
              let data = try? Data(contentsOf: url) else { return [] }
        return rentals(from: data)
    }()

    static func rentals(from data: Data) -> [RentalPreset] {
        (try? JSONDecoder().decode(RentalFile.self, from: data))?.rental ?? []
    }

    /// Per i test: le marche lette da un file
    static func catalogMakes(from data: Data) -> [Make] {
        struct File: Codable { var makes: [Make] }
        return (try? JSONDecoder().decode(File.self, from: data))?.makes ?? []
    }
}
