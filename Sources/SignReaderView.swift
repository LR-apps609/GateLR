import SwiftUI
import PhotosUI
import Vision
import VisionKit
import UIKit

/// «Leggi il cartello»: inquadri il pannello degli orari (o scegli una foto) e GateLR lo spiega
/// nella tua lingua e dice se adesso, secondo il cartello, la ZTL è attiva.
struct SignReaderView: View {
    @State private var text = ""
    @State private var scanning = false
    @State private var photo: PhotosPickerItem?
    @State private var reading = false

    private var result: SignReader.Result { SignReader.parse(text) }
    private var scannerAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HoursPanel().frame(width: 180).frame(maxWidth: .infinity)
                    Text("Point the camera at the white panel under the ZTL sign, or pick a photo of it.")
                        .font(.app(size: 15)).foregroundStyle(Theme.muted)
                }
                HStack(spacing: 10) {
                    if scannerAvailable {
                        WideButton(title: "Use the camera", systemImage: "camera.viewfinder") { scanning = true }
                    }
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(L("Choose a photo"), systemImage: "photo")
                            .font(.app(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(Theme.blue)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel("Text on the sign")
                    TextField(L("e.g. 7.30-20.00 feriali"), text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(12)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("sign.text")
                    if reading { ProgressView(L("Reading…")) }
                }
                .padding(14).card()
                if !text.trimmingCharacters(in: .whitespaces).isEmpty { explanation }
                Text("GateLR reads the panel for you, but it can misread a photo: if in doubt, the sign wins.")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("Read the sign")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $scanning) {
            LiveTextScanner { found in if !found.isEmpty { text = found }; scanning = false }
                .ignoresSafeArea()
        }
        .onChange(of: photo) {
            guard let photo else { return }
            reading = true
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self), let found = await Self.recognize(data) { text = found }
                reading = false
            }
        }
    }

    @ViewBuilder
    private var explanation: some View {
        let r = result
        if r.understood {
            let now = SignReader.isActive(r, at: Date())
            VStack(alignment: .leading, spacing: 10) {
                Label(now ? L("Active now, according to the sign: don't drive in") : L("Not active now, according to the sign: you may drive in"),
                      systemImage: now ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .font(.app(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(now ? Theme.red : Theme.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                SectionLabel("What it means")
                ForEach(Array(r.rules.enumerated()), id: \.offset) { _, rule in
                    HStack {
                        Text(Self.daysText(rule.days)).font(.app(size: 15))
                        Spacer()
                        Text(rule.start == 0 && rule.end >= 1440 ? L("all day") : "\(Self.time(rule.start)) – \(Self.time(rule.end))")
                            .font(.app(size: 15, weight: .semibold)).monospacedDigit()
                    }
                }
                if r.holidaysExcluded { Text("Public holidays: not active.").font(.app(size: 14)).foregroundStyle(Theme.muted) }
                if r.holidaysIncluded { Text("Also on public holidays.").font(.app(size: 14)).foregroundStyle(Theme.muted) }
            }
            .padding(14).card()
        } else {
            Label("I can't find days and hours in this text. Try again closer to the panel, or type them.", systemImage: "questionmark.circle")
                .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    static func time(_ m: Int) -> String {
        let d = Calendar.current.date(bySettingHour: m / 60 % 24, minute: m % 60, second: 0, of: Date()) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }

    static func daysText(_ days: Set<Int>) -> String {
        if days.count == 7 { return L("Every day") }
        let names = Calendar.current.weekdaySymbols
        let order = [2, 3, 4, 5, 6, 7, 1].filter { days.contains($0) }
        return order.map { names[$0 - 1].capitalized }.joined(separator: ", ")
    }

    /// Il testo di una foto, con il riconoscimento di Apple (sul telefono, senza internet)
    static func recognize(_ data: Data) async -> String? {
        guard let ui = UIImage(data: data), let image = ui.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(ui.imageOrientation)
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["it-IT", "en-US"]
                do {
                    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
                    let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                    cont.resume(returning: lines.isEmpty ? nil : lines.joined(separator: "\n"))
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}

/// La fotocamera con il testo dal vivo: si tocca «Usa questo testo» quando il pannello è inquadrato
struct LiveTextScanner: UIViewControllerRepresentable {
    var done: (String) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text(languages: ["it", "en"])],
                                                qualityLevel: .accurate, recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        scanner.navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("Use this text"), style: .done,
                                                                    target: context.coordinator, action: #selector(Coordinator.finish))
        scanner.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { _ in context.coordinator.cancel() })
        return UINavigationController(rootViewController: scanner)
    }

    /// La fotocamera parte quando la schermata è davvero visibile
    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        if let scanner = context.coordinator.scanner, !scanner.isScanning {
            DispatchQueue.main.async { try? scanner.startScanning() }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var done: (String) -> Void
        weak var scanner: DataScannerViewController?
        private var items: [RecognizedItem] = []
        init(done: @escaping (String) -> Void) { self.done = done }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }

        @objc func finish() {
            let text = items.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript }
                return nil
            }.joined(separator: "\n")
            scanner?.stopScanning()
            done(text)
        }
        func cancel() { scanner?.stopScanning(); done("") }
    }
}

extension CGImagePropertyOrientation {
    /// L'orientamento della foto, perché Vision legga il testo dritto
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
