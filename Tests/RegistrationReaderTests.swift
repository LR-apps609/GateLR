import XCTest

/// «Fotografa il libretto»: testi come li legge una foto (con errori: O al posto di 0, codici senza punto,
/// colonne unite, valori sulla riga dopo) di libretti italiani, tedeschi, francesi, spagnoli e olandesi
final class RegistrationReaderTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let cars: Data = (try? Data(contentsOf: root.appendingPathComponent("Resources/Rules/cars.json"))) ?? Data()
    private let makes = CarCatalog.catalogMakes(from: RegistrationReaderTests.cars)

    private func read(_ text: String) -> RegistrationReader.Result {
        RegistrationReader.parse(text, makes: makes, thisYear: 2026)
    }

    func testCatalogIsReadable() {
        XCTAssertGreaterThan(makes.count, 20)
    }

    func testItalianLibrettoHybridPanda() {
        let r = read(#"""
        REPUBBLICA ITALIANA
        CARTA DI CIRCOLAZIONE
        A   GX 482 KM   B   14/05/2021
        C.2.1 ROSSI   C.2.2 MARIO
        D.1 FIAT
        D.2 312PXA1A 03C
        D.3 PANDA
        E   ZFA31200003F12345
        J   M1   P.1 999
        P.3 IBRIDO BENZINA/ELETTRICO
        V.9 715/2007*2018/1832AP EURO 6D
        """#)
        XCTAssertEqual(r.plate, "GX482KM")
        XCTAssertEqual(r.make, "Fiat")
        XCTAssertEqual(r.model, "Panda")
        XCTAssertEqual(r.year, 2021)
        XCTAssertEqual(r.month, 5)
        XCTAssertEqual(r.day, 14)
        XCTAssertEqual(r.fuel, .hybrid)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testItalianLibrettoNoisyCodes() {
        let r = read(#"""
        Carta di circolazione
        (A) EF 2O7 ZL
        (B) 03.11.2012
        0.1 VOLKSWAGEN
        D3 GOLF
        P3 GASOLIO
        V9 715/2007*692/2008B
        """#)
        XCTAssertEqual(r.plate, "EF207ZL")
        XCTAssertEqual(r.make, "Volkswagen")
        XCTAssertEqual(r.model, "Golf")
        XCTAssertEqual(r.year, 2012)
        XCTAssertEqual(r.month, 11)
        XCTAssertEqual(r.day, 3)
        XCTAssertEqual(r.fuel, .diesel)
        XCTAssertEqual(r.euro, 5)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testItalianLibrettoWithoutV9UsesYear() {
        let r = read(#"""
        A AB 123 CD
        B 22/02/2023
        D.1 TOYOTA
        D.3 YARIS CROSS
        P.3 IBRIDO BENZ/ELETTR
        """#)
        XCTAssertEqual(r.plate, "AB123CD")
        XCTAssertEqual(r.make, "Toyota")
        XCTAssertEqual(r.model, "Yaris Cross")
        XCTAssertEqual(r.year, 2023)
        XCTAssertEqual(r.fuel, .hybrid)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .year)
        XCTAssertTrue(r.understood)
    }

    func testItalianLibrettoValuesOnNextLine() {
        let r = read(#"""
        D.1
        FIAT
        D.3
        PUNTO
        P.3
        BENZ/GPL
        V.9
        70/220*2003/76B
        A
        DK 455 RT
        B
        07/09/2005
        """#)
        XCTAssertEqual(r.plate, "DK455RT")
        XCTAssertEqual(r.make, "Fiat")
        XCTAssertEqual(r.model, "Punto")
        XCTAssertEqual(r.year, 2005)
        XCTAssertEqual(r.month, 9)
        XCTAssertEqual(r.day, 7)
        XCTAssertEqual(r.fuel, .lpg)
        XCTAssertEqual(r.euro, 4)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testItalianLibrettoMethaneSameRow() {
        let r = read(#"""
        REPUBBLICA ITALIANA  MINISTERO DELLE INFRASTRUTTURE
        A  FA 731 GH        B  30/06/2016
        D.1  FIAT    D.3  PANDA NATURAL POWER
        P.3  B/METANO
        V.9  715/2007*136/2014W
        """#)
        XCTAssertEqual(r.plate, "FA731GH")
        XCTAssertEqual(r.make, "Fiat")
        XCTAssertEqual(r.model, "Panda")
        XCTAssertEqual(r.year, 2016)
        XCTAssertEqual(r.fuel, .lpg)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testGermanZulassungsbescheinigung() {
        let r = read(#"""
        Zulassungsbescheinigung Teil I
        A  M-AB 1234        B  12.06.2019
        D.1  VOLKSWAGEN
        D.2  AU  ACDLWAX0
        D.3  GOLF
        P.3  Benzin
        V.9  715/2007*2017/1347AG
        14  EURO 6 D TEMP
        """#)
        XCTAssertEqual(r.plate, "M-AB 1234")
        XCTAssertEqual(r.make, "Volkswagen")
        XCTAssertEqual(r.model, "Golf")
        XCTAssertEqual(r.year, 2019)
        XCTAssertEqual(r.month, 6)
        XCTAssertEqual(r.day, 12)
        XCTAssertEqual(r.fuel, .petrol)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testGermanElectricNoisy() {
        let r = read(#"""
        ZULASSUNGSBESCHEINIGUNG TEIL I
        A HH-EV 123E
        B 01.03.2022
        D.l TESLA
        D.3 MODEL 3
        P.3 ELEKTR0
        """#)
        XCTAssertEqual(r.plate, "HH-EV 123E")
        XCTAssertEqual(r.make, "Tesla")
        XCTAssertEqual(r.model, "Model 3")
        XCTAssertEqual(r.year, 2022)
        XCTAssertEqual(r.fuel, .electric)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .year)
        XCTAssertTrue(r.understood)
    }

    func testGermanHybridNationalClassOnly() {
        let r = read(#"""
        A  S-KL 4711   B  09.09.2020
        D.1  BMW
        D.3  X1
        P.3  Hybr.Benzin/E
        14  EURO 6D
        """#)
        XCTAssertEqual(r.plate, "S-KL 4711")
        XCTAssertEqual(r.make, "BMW")
        XCTAssertEqual(r.model, "X1")
        XCTAssertEqual(r.year, 2020)
        XCTAssertEqual(r.fuel, .hybrid)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testFrenchCertificatEssence() {
        let r = read(#"""
        CERTIFICAT D'IMMATRICULATION
        A  FG-123-HJ    B  18/10/2019
        D.1  RENAULT
        D.3  CLIO
        P.3  ES
        V.9  715/2007*2018/1832AP
        """#)
        XCTAssertEqual(r.plate, "FG-123-HJ")
        XCTAssertEqual(r.make, "Renault")
        XCTAssertEqual(r.model, "Clio")
        XCTAssertEqual(r.year, 2019)
        XCTAssertEqual(r.fuel, .petrol)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testFrenchCertificatGazole() {
        let r = read(#"""
        RÉPUBLIQUE FRANÇAISE  CERTIFICAT D'IMMATRICULATION
        A  BX-456-CD   B  02/04/2008
        D.1  CITROEN
        D.3  C3
        P.3  GO
        V.9  70/220*2003/76B
        """#)
        XCTAssertEqual(r.plate, "BX-456-CD")
        XCTAssertEqual(r.make, "Citroën")
        XCTAssertEqual(r.model, "C3")
        XCTAssertEqual(r.year, 2008)
        XCTAssertEqual(r.fuel, .diesel)
        XCTAssertEqual(r.euro, 4)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testFrenchHybridEH() {
        let r = read(#"""
        A  GH-777-AA   B  11/01/2021
        D.1  TOYOTA
        D.3  YARIS
        P.3  EH
        V.9  EURO6D
        """#)
        XCTAssertEqual(r.plate, "GH-777-AA")
        XCTAssertEqual(r.make, "Toyota")
        XCTAssertEqual(r.model, "Yaris")
        XCTAssertEqual(r.year, 2021)
        XCTAssertEqual(r.fuel, .hybrid)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testSpanishPermisoGasolina() {
        let r = read(#"""
        PERMISO DE CIRCULACIÓN
        A  1234 KLM   B  05/07/2018
        D.1  SEAT
        D.3  IBIZA
        P.3  GASOLINA
        V.9  EURO 6
        """#)
        XCTAssertEqual(r.plate, "1234 KLM")
        XCTAssertEqual(r.make, "Seat")
        XCTAssertEqual(r.model, "Ibiza")
        XCTAssertEqual(r.year, 2018)
        XCTAssertEqual(r.fuel, .petrol)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testSpanishPermisoLabelsAndAccents() {
        let r = read(#"""
        D.1 MARCA: PEUGEOT
        D.3 DENOMINACIÓN COMERCIAL: 308
        A MATRÍCULA: 8812 HBD
        B FECHA PRIMERA MATRICULACIÓN: 21/10/2014
        P.3 COMBUSTIBLE: GASÓLEO
        V.9 NIVEL DE EMISIONES: 715/2007*692/2008J
        """#)
        XCTAssertEqual(r.plate, "8812 HBD")
        XCTAssertEqual(r.make, "Peugeot")
        XCTAssertEqual(r.model, "308")
        XCTAssertEqual(r.year, 2014)
        XCTAssertEqual(r.fuel, .diesel)
        XCTAssertEqual(r.euro, 5)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testDutchKentekenbewijs() {
        let r = read(#"""
        KENTEKENBEWIJS
        A  12-ABC-3   B  15-03-2017
        D.1  OPEL
        D.3  CORSA
        P.3  Benzine
        V.9  EURO 6 W
        """#)
        XCTAssertEqual(r.plate, "12-ABC-3")
        XCTAssertEqual(r.make, "Opel")
        XCTAssertEqual(r.model, "Corsa")
        XCTAssertEqual(r.year, 2017)
        XCTAssertEqual(r.month, 3)
        XCTAssertEqual(r.day, 15)
        XCTAssertEqual(r.fuel, .petrol)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testDutchHybridKia() {
        let r = read(#"""
        A  ZR-123-K   B  20-08-2020
        D.1  KIA
        D.3  NIRO
        P.3  Benzine/Elektriciteit
        V.9  715/2007*2017/1347AP
        """#)
        XCTAssertEqual(r.plate, "ZR-123-K")
        XCTAssertEqual(r.make, "Kia")
        XCTAssertEqual(r.model, "Niro")
        XCTAssertEqual(r.year, 2020)
        XCTAssertEqual(r.fuel, .hybrid)
        XCTAssertEqual(r.euro, 6)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    func testOldEuro3Directive() {
        let r = read(#"""
        A  BR 552 TT   B  15/03/2003
        D.1  FIAT  D.3  PUNTO
        P.3  BENZINA
        V.9  70/220*2001/100A
        """#)
        XCTAssertEqual(r.plate, "BR552TT")
        XCTAssertEqual(r.make, "Fiat")
        XCTAssertEqual(r.model, "Punto")
        XCTAssertEqual(r.year, 2003)
        XCTAssertEqual(r.fuel, .petrol)
        XCTAssertEqual(r.euro, 3)
        XCTAssertEqual(r.euroSource, .document)
        XCTAssertTrue(r.understood)
    }

    /// V.9: la classe scritta («EURO 6D-TEMP», «EURO VI») o le direttive (tabella RegistrationReader.directives)
    func testEuroFromEmissionField() {
        let cases: [(String, Int?)] = [
            ("EURO 6D-TEMP", 6),
            ("EURO6D", 6),
            ("EUR0 5", 5),
            ("EURO VI", 6),
            ("EURO IV", 4),
            ("Euro 3", 3),
            ("70/220*2001/100A", 3),
            ("70/220*2001/100B", 4),
            ("70/220*98/69B", 4),
            ("70/220*98/69A", 3),
            ("70/220*96/69", 2),
            ("70/220*94/12", 2),
            ("70/220*91/441", 1),
            ("70/220*93/59", 1),
            ("70/220*1999/102B", 4),
            ("70/220 * 1999/102 A", 3),
            ("70/220*2003/76B", 4),
            ("70/220*2006/96B", 4),
            ("715/2007*692/2008EURO 5", 5),
            ("715/2007*692/2008EURO6", 6),
            ("715/2007*566/2011", 5),
            ("715/2007*459/2012", 6),
            ("715/2007*136/2014", 6),
            ("715/2007*2016/646", 6),
            ("715/2007*2018/1832AP", 6),
            ("715/2007*2017/1151", 6),
            ("715/2007", 5),
            ("70/2202001/100B", 4),
            ("2023/443", 6),
            ("XYZ", nil)
        ]
        for (text, euro) in cases { XCTAssertEqual(RegistrationReader.euro(fromEmission: text), euro, text) }
    }

    /// P.3 nelle varie lingue e i codici francesi
    func testFuelWords() {
        let cases: [(String, Fuel?)] = [
            ("BENZINA", .petrol),
            ("GASOLIO", .diesel),
            ("GPL", .lpg),
            ("METANO", .lpg),
            ("B/METANO", .lpg),
            ("BENZ/GPL", .lpg),
            ("ELETTRICO", .electric),
            ("ELETTR", .electric),
            ("IBRIDO", .hybrid),
            ("BENZ/ELETTR", .hybrid),
            ("Benzin", .petrol),
            ("Diesel", .diesel),
            ("Elektro", .electric),
            ("Hybr.Benzin/E", .hybrid),
            ("Erdgas", .lpg),
            ("essence", .petrol),
            ("gazole", .diesel),
            ("électrique", .electric),
            ("ES", .petrol),
            ("GO", .diesel),
            ("EL", .electric),
            ("EH", .hybrid),
            ("gasolina", .petrol),
            ("gasóleo", .diesel),
            ("GLP", .lpg),
            ("eléctrico", .electric),
            ("benzine", .petrol),
            ("Elektriciteit", .electric),
            ("LPG", .lpg),
            ("Benzine/Elektriciteit", .hybrid),
            ("PHEV", .hybrid),
            ("XYZ", nil)
        ]
        for (text, fuel) in cases { XCTAssertEqual(RegistrationReader.fuel(from: text, strict: false), fuel, text) }
        // Nel resto del testo contano solo le parole lunghe: «MERCEDES-BENZ» non è benzina
        XCTAssertNil(RegistrationReader.fuel(from: "D.1 MERCEDES-BENZ", strict: true))
    }

    func testPlates() {
        XCTAssertEqual(RegistrationReader.italianPlate(in: "TARGA AB 123 CD"), "AB123CD")
        XCTAssertEqual(RegistrationReader.italianPlate(in: "EF 2O7 ZL"), "EF207ZL")
        XCTAssertNil(RegistrationReader.italianPlate(in: "ABSOBCD"))
        XCTAssertEqual(RegistrationReader.plate(in: "FG-123-HJ"), "FG-123-HJ")
        XCTAssertEqual(RegistrationReader.plate(in: "M AB 1234"), "M AB 1234")
        XCTAssertNil(RegistrationReader.plate(in: "FIAT"))
    }

    func testUnreadableText() {
        XCTAssertFalse(read("hello world").understood)
        XCTAssertFalse(read("").understood)
    }

    /// I pezzi letti da Vision sulla stessa altezza tornano sulla stessa riga, da sinistra a destra
    func testRowsJoinPiecesOnTheSameLine() {
        let pieces = [
            DocumentText.Piece(text: "FIAT", x: 0.3, midY: 0.80, height: 0.02),
            DocumentText.Piece(text: "D.1", x: 0.1, midY: 0.801, height: 0.02),
            DocumentText.Piece(text: "PANDA", x: 0.3, midY: 0.749, height: 0.02),
            DocumentText.Piece(text: "D.3", x: 0.1, midY: 0.75, height: 0.02),
        ]
        XCTAssertEqual(DocumentText.rows(pieces), "D.1   FIAT\nD.3   PANDA")
        let r = RegistrationReader.parse(DocumentText.rows(pieces), makes: makes, thisYear: 2026)
        XCTAssertEqual(r.make, "Fiat")
        XCTAssertEqual(r.model, "Panda")
    }

    /// «Auto a noleggio»: i modelli tipici esistono nel catalogo, con almeno un carburante e Euro 6
    func testRentalPresets() {
        let presets = CarCatalog.rentals(from: RegistrationReaderTests.cars)
        XCTAssertGreaterThanOrEqual(presets.count, 20)
        for p in presets {
            XCTAssertTrue(makes.contains { $0.make == p.make && $0.models.contains(p.model) }, p.id)
            XCTAssertFalse(p.fuels.isEmpty, p.id)
            XCTAssertEqual(p.euro, 6, p.id)
        }
        for needed in ["Fiat Panda", "Fiat 500", "Lancia Ypsilon", "Volkswagen Polo", "Volkswagen Golf", "Volkswagen T-Roc", "Peugeot 208",
                       "Peugeot 2008", "Renault Clio", "Renault Captur", "Toyota Yaris", "Toyota Yaris Cross", "Jeep Renegade", "Jeep Compass",
                       "Citroën C3", "Opel Corsa", "Dacia Sandero"] {
            XCTAssertTrue(presets.contains { $0.id == needed }, needed)
        }
    }

    /// La targa automatica non è attiva: nessuna richiesta in rete
    func testPlateLookupIsDisabled() async {
        let lookup = DisabledPlateLookup()
        XCTAssertFalse(lookup.isAvailable)
        do {
            _ = try await lookup.lookup(plate: "AB123CD")
            XCTFail("the stub must not answer")
        } catch {
            XCTAssertEqual(error as? PlateLookupError, .notEnabled)
        }
    }
}
