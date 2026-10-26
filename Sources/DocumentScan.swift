import SwiftUI
import PhotosUI
import Vision
import UIKit
import AVFoundation

/// Il testo di un documento fotografato, letto sul telefono (Vision, senza internet). I pezzi sulla stessa
/// riga si rimettono insieme (DocumentText.rows): sul libretto «D.1» e «FIAT» sono due pezzi affiancati.
enum DocumentOCR {
    static func read(_ ui: UIImage, languages: [String], correction: Bool) async -> String? {
        let orientation = CGImagePropertyOrientation(ui.imageOrientation)
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = ui.cgImage else { cont.resume(returning: nil); return }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = correction
                // Solo le lingue che questo iPhone sa leggere (l'olandese non c'è su tutti)
                let supported = (try? request.supportedRecognitionLanguages()) ?? []
                let wanted = languages.filter { supported.contains($0) }
                request.recognitionLanguages = wanted.isEmpty ? ["it-IT", "en-US"] : wanted
                do {
                    try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
                    let pieces: [DocumentText.Piece] = (request.results ?? []).compactMap { o in
                        guard let s = o.topCandidates(1).first?.string else { return nil }
                        let b = o.boundingBox
                        return DocumentText.Piece(text: s, x: Double(b.minX), midY: Double(b.midY), height: Double(b.height))
                    }
                    cont.resume(returning: pieces.isEmpty ? nil : DocumentText.rows(pieces))
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    static func read(_ data: Data, languages: [String], correction: Bool) async -> String? {
        let ui: UIImage? = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
        guard let ui else { return nil }
        return await read(ui, languages: languages, correction: correction)
    }
}

/// «Usa la fotocamera» e «Scegli una foto» per un documento: chiede il permesso, legge il testo e lo passa a onText.
/// Con la fotocamera negata mostra «Apri Impostazioni»; tornando con il permesso la fotocamera si apre da sola.
struct DocumentCapture: View {
    var languages: [String]
    var correction: Bool
    var onText: (String) -> Void

    @State private var photo: PhotosPickerItem?
    @State private var takingPhoto = false
    @State private var reading = false
    @State private var noText = false
    @State private var cameraDenied = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    WideButton(title: "Use the camera", systemImage: "camera") { Task { await openCamera() } }
                        .accessibilityIdentifier("document.camera")
                }
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(L("Choose a photo"), systemImage: "photo")
                        .font(.app(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Theme.blue)
                }
                .accessibilityIdentifier("document.photo")
            }
            if reading { ProgressView(L("Reading…")) }
            if noText {
                Label("No text found in this photo. Try again with more light, the document flat and filling the frame.", systemImage: "questionmark.circle")
                    .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if cameraDenied { CameraPermissionCard() }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPicker { image in
                takingPhoto = false
                guard let image else { return }
                reading = true
                Task {
                    let found = await DocumentOCR.read(image, languages: languages, correction: correction)
                    finish(found)
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
                var found: String?
                if let data = try? await item.loadTransferable(type: Data.self) {
                    found = await DocumentOCR.read(data, languages: languages, correction: correction)
                }
                finish(found)
                photo = nil          // la stessa foto si può scegliere di nuovo
            }
        }
    }

    private func finish(_ text: String?) {
        reading = false
        noText = text == nil
        if let text { onText(text) }
    }

    /// Prima il permesso della fotocamera: se è negato si spiega, invece di uno schermo nero
    @MainActor private func openCamera() async {
        noText = false
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { cameraDenied = true; return }
        default:
            cameraDenied = true
            return
        }
        cameraDenied = false
        takingPhoto = true
    }
}

/// iOS chiede il permesso una volta sola: dopo un «Non consentire» si può solo accenderlo nelle Impostazioni
struct CameraPermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Allow the camera", systemImage: "camera.fill")
                .font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.amberInk)
            Text("iOS asks only once. Tap «Open Settings», turn on Camera and come back: the camera opens by itself. You can also choose a photo.")
                .font(.app(size: 14)).foregroundStyle(Theme.amberInk)
            WideButton(title: "Open Settings", systemImage: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .accessibilityIdentifier("document.openSettings")
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
