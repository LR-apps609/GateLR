import Foundation

// DATI DI ESEMPIO, non verificati: servono a far girare l'app finché non arrivano le schede vere.
// Ogni città di esempio ha status = .sample e l'app lo dice in chiaro. Usati dai test e se manca Resources/Cities.

enum SampleData {
    static let florence = City(
        id: "firenze-esempio",
        name: "Florence",
        center: Coordinate(lat: 43.7731, lon: 11.2560),
        zones: [sectorA],
        status: .sample,
        license: nil)

    static let sectorA = Zone(
        id: "firenze-a",
        name: "Historic Centre · Sector A",
        summary: "On weekdays you can't drive in during the day without a permit. If your hotel is inside the zone, the hotel can register your plate.",
        perimeter: [
            Coordinate(lat: 43.7790, lon: 11.2405), Coordinate(lat: 43.7800, lon: 11.2580),
            Coordinate(lat: 43.7745, lon: 11.2680), Coordinate(lat: 43.7680, lon: 11.2650),
            Coordinate(lat: 43.7672, lon: 11.2470), Coordinate(lat: 43.7725, lon: 11.2398),
        ],
        gates: [
            Gate(id: "g1", name: "Porta al Prato", location: Coordinate(lat: 43.7786, lon: 11.2412)),
            Gate(id: "g2", name: "Via della Scala", location: Coordinate(lat: 43.7752, lon: 11.2440)),
            Gate(id: "g3", name: "[Gate 3]", location: Coordinate(lat: 43.7798, lon: 11.2560)),
            Gate(id: "g4", name: "[Gate 4]", location: Coordinate(lat: 43.7742, lon: 11.2672)),
            Gate(id: "g5", name: "[Gate 5]", location: Coordinate(lat: 43.7680, lon: 11.2560)),
        ],
        windows: [
            TimeWindow(weekdays: [2, 3, 4, 5, 6], start: 7 * 60 + 30, end: 20 * 60),
            TimeWindow(weekdays: [7], start: 7 * 60 + 30, end: 16 * 60),
        ],
        freeOnHolidays: true,
        exemptFuels: [],
        hotelCanRegister: true,
        source: Source(
            authority: "City of Florence (sample)",
            pageURL: URL(string: "https://www.comune.fi.it")!,
            ordinance: "Ordinance no. [number]",
            ordinanceURL: nil,
            quote: "[Frase originale dell'ordinanza, in italiano.]",
            quoteTranslation: "[The same sentence in English.]",
            checkedOn: Date(),
            reviewedByHuman: false,
            pending: [],
            links: []))

    static let rental = Vehicle(name: "Rental car", model: "Fiat 500", fuel: .petrol, euro: 6, plate: "", isRental: true)
}
