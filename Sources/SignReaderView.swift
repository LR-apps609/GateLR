import SwiftUI
import PhotosUI
import Vision
import VisionKit
import UIKit
import AVFoundation

/// «Leggi il cartello»: inquadri il pannello degli orari (o scegli una foto) e GateLR lo spiega
/// nella tua lingua e dice se adesso, secondo il cartello, la ZTL è attiva.
struct SignReaderView: View {
    @State private var text = ""
    @State private var scanning = false
    @State private var photo: PhotosPickerItem?
    @State private var reading = false
    @State private var takingPhoto = false
    @State private var cameraMessage: String?
    /// Fotocamera negata: si mostra il riquadro con «Apri Impostazioni»; tornando con il permesso si apre da sola
    @State private var cameraDenied = false
    @Environment(\.scenePhase) private var scenePhase

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
                    if scannerAvailable || CameraPicker.isAvailable {
                        WideButton(title: "Use the camera", systemImage: "camera.viewfinder") { Task { await openCamera() } }
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
                if cameraDenied { cameraPermission }
                if let cameraMessage {
                    Label(cameraMessage, systemImage: "camera.badge.ellipsis")
                        .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                }
                if !text.trimmingCharacters(in: .whitespaces).isEmpty { explanation }
                Text("GateLR reads the panel for you, but it can misread a photo: if in doubt, the sign wins.")
                    .font(.app(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("Read the sign")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $scanning) {
            LiveTextScanner(done: { found in if !found.isEmpty { text = found }; scanning = false },
                            failed: {
                                // Il testo dal vivo non parte: si chiude e si apre la fotocamera classica
                                scanning = false
                                if CameraPicker.isAvailable {
                                    Task { try? await Task.sleep(for: .milliseconds(600)); takingPhoto = true }
                                } else {
                                    cameraMessage = L("The camera isn't available right now. Choose a photo of the panel instead.")
                                }
                            })
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in
                takingPhoto = false
                guard let image else { return }
                reading = true
                Task {
                    if let found = await Self.recognize(image) { text = found }
                    reading = false
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, cameraDenied, AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                cameraDenied = false
                Task { await openCamera() }
            }
        }
        .onChange(of: photo) {
            guard let item = photo else { return }
            reading = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let found = await Self.recognize(data) { text = found }
                reading = false
                photo = nil          // la stessa foto si può scegliere di nuovo
            }
        }
    }

    /// iOS chiede il permesso una volta sola: dopo un «Non consentire» si può solo accenderlo nelle Impostazioni
    private var cameraPermission: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Allow the camera", systemImage: "camera.fill")
                .font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.amberInk)
            Text("iOS asks only once. Tap «Open Settings», turn on Camera and come back: the camera opens by itself. You can also choose a photo.")
                .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
            WideButton(title: "Open Settings", systemImage: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .accessibilityIdentifier("sign.openSettings")
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    /// Prima il permesso della fotocamera: se è negato si spiega, invece di uno schermo nero
    @MainActor private func openCamera() async {
        cameraMessage = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            // La richiesta di iOS, dentro l'app
            guard await AVCaptureDevice.requestAccess(for: .video) else { cameraDenied = true; return }
        default:
            cameraDenied = true
            return
        }
        cameraDenied = false
        if scannerAvailable { scanning = true } else if CameraPicker.isAvailable { takingPhoto = true }
    }

    /// Il testo di una foto, con il riconoscimento di Apple (sul telefono, senza internet)
    static func recognize(_ data: Data) async -> String? {
        // Anche la decodifica della foto (12 megapixel) fuori dal thread principale
        let ui: UIImage? = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
        guard let ui else { return nil }
        return await recognize(ui)
    }

    static func recognize(_ ui: UIImage) async -> String? {
        let orientation = CGImagePropertyOrientation(ui.imageOrientation)
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = ui.cgImage else { cont.resume(returning: nil); return }
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

/// La fotocamera con il testo dal vivo: si tocca «Usa questo testo» quando il pannello è inquadrato.
/// La scansione parte una volta sola, quando la schermata è davvero visibile (viewDidAppear), e si ferma
/// quando si chiude. Prima ripartiva a ogni aggiornamento di SwiftUI (anche dopo «Annulla») e, chiamata
/// prima che la vista fosse nella finestra, lasciava lo schermo nero e l'app bloccata.
struct LiveTextScanner: UIViewControllerRepresentable {
    var done: (String) -> Void
    /// La fotocamera non è partita (permesso negato, in uso da un'altra app…): si passa alla foto
    var failed: () -> Void

    func makeUIViewController(context: Context) -> ScannerNavigation {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text(languages: ["it", "en"])],
                                                qualityLevel: .accurate, recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        scanner.navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("Use this text"), style: .done,
                                                                    target: context.coordinator, action: #selector(Coordinator.finish))
        scanner.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { _ in context.coordinator.cancel() })
        let nav = ScannerNavigation(rootViewController: scanner)
        nav.onStartFailed = { context.coordinator.startFailed() }
        return nav
    }

    /// Niente qui: la scansione la gestisce ScannerNavigation (mai riavviarla a ogni aggiornamento)
    func updateUIViewController(_ controller: ScannerNavigation, context: Context) {
        context.coordinator.done = done
        context.coordinator.failed = failed
    }

    static func dismantleUIViewController(_ controller: ScannerNavigation, coordinator: Coordinator) {
        coordinator.scanner?.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(done: done, failed: failed) }

    /// Avvia la scansione quando la schermata è visibile, una volta sola; la ferma quando si chiude
    final class ScannerNavigation: UINavigationController {
        var onStartFailed: (() -> Void)?
        private var started = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !started, let scanner = viewControllers.first as? DataScannerViewController else { return }
            started = true
            do { try scanner.startScanning() } catch { onStartFailed?() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            (viewControllers.first as? DataScannerViewController)?.stopScanning()
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var done: (String) -> Void
        var failed: () -> Void
        weak var scanner: DataScannerViewController?
        private var items: [RecognizedItem] = []
        private var finished = false
        init(done: @escaping (String) -> Void, failed: @escaping () -> Void) { self.done = done; self.failed = failed }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { items = allItems }
        /// La fotocamera si è fermata da sola (es. un'altra app l'ha presa): si passa alla foto
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            startFailed()
        }

        @objc func finish() {
            guard !finished else { return }
            finished = true
            let text = items.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript }
                return nil
            }.joined(separator: "\n")
            scanner?.stopScanning()
            done(text)
        }
        func cancel() {
            guard !finished else { return }
            finished = true
            scanner?.stopScanning(); done("")
        }
        func startFailed() {
            guard !finished else { return }
            finished = true
            scanner?.stopScanning(); failed()
        }
    }
}

/// La fotocamera classica: si scatta la foto del pannello e il testo si legge dopo, in sottofondo.
/// Serve quando il testo dal vivo non c'è (iPhone più vecchi) o non parte.
struct CameraPicker: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { context.coordinator.done = done }
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
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
