import SwiftUI
import UIKit
import QuartzCore

// 1.19.5: le misure delle prestazioni (UITests/MisureTests.swift, .github/workflows/misure.yml). Tutto qui è spento
// nell'app vera: si accende solo con «-uitest» più gli argomenti qui sotto, che passa solo il test delle misure.
// Niente esce dal telefono: i numeri li legge il test dal simulatore (nessuna telemetria).
enum Misure {
    private static var args: [String] { ProcessInfo.processInfo.arguments }
    private static var uitest: Bool { args.contains("-uitest") }

    /// «-uiLive»: nel test delle misure, i parcheggi da Overpass e i percorsi di Apple come nell'app vera
    /// (nel giro delle foto restano spenti: solo i dati dentro l'app)
    static var live: Bool { uitest && args.contains("-uiLive") }
    /// «-uiNoParkingCache»: la copia dei parcheggi sul disco non si legge (ogni ricerca va davvero in rete)
    static var noParkingCache: Bool { uitest && args.contains("-uiNoParkingCache") }
    /// «-uiFps»: il contatore dei fotogrammi (FrameMeter), letto dal test
    static var fps: Bool { uitest && args.contains("-uiFps") }

    /// «-uiGuardianDrive 60 12»: dopo -uiGuardian, il guardiano riceve una posizione al secondo per 60 secondi,
    /// 12 m/s nella stessa direzione (un giro in auto accorciato, per il consumo del processore)
    static var guardianDrive: (seconds: Int, speed: Double)? {
        guard uitest, let i = args.firstIndex(of: "-uiGuardianDrive"), args.count > i + 2,
              let s = Int(args[i + 1]), let v = Double(args[i + 2]) else { return nil }
        return (s, v)
    }

    /// Il giro simulato del guardiano: una posizione al secondo, come il GPS in auto (distanceFilter 15 m a ~50 km/h)
    @MainActor
    static func startGuardianDrive(from p: Coordinate, course: Double) {
        guard let drive = guardianDrive else { return }
        Task { @MainActor in
            for i in 1...max(1, drive.seconds) {
                try? await Task.sleep(for: .seconds(1))
                guard Guardian.shared.active else { return }
                let here = PathMath.offset(p, meters: 60 + Double(i) * drive.speed, bearing: course)
                Guardian.shared.update(here, course: course, speed: drive.speed)
            }
        }
    }
}

/// Il contatore dei fotogrammi per il test delle misure: conta i giri del display link e gli «scatti» (un fotogramma
/// arrivato più di 1,5 volte dopo il previsto: il thread principale era occupato). Scrive il risultato nell'etichetta
/// di accessibilità «misure.fps» al più due volte al secondo, senza ridisegnare SwiftUI.
struct FrameMeter: UIViewRepresentable {
    func makeUIView(context: Context) -> FrameMeterView { FrameMeterView() }
    func updateUIView(_ view: FrameMeterView, context: Context) {}
}

final class FrameMeterView: UILabel {
    private var link: CADisplayLink?
    private var frames = 0
    private var hitches = 0
    private var missed = 0
    private var last: CFTimeInterval = 0
    private var started: CFTimeInterval = 0
    private var written: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityIdentifier = "misure.fps"
        font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        textColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        link?.invalidate()
        guard window != nil else { link = nil; return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        if started == 0 { started = now; last = now; written = now; return }
        let expected = max(1.0 / 120, l.targetTimestamp - l.timestamp)
        let gap = now - last
        last = now
        frames += 1
        if gap > expected * 1.5 {
            hitches += 1
            missed += max(0, Int((gap / expected).rounded()) - 1)
        }
        if now - written > 0.5 {
            written = now
            let s = String(format: "frames=%d hitches=%d missed=%d seconds=%.2f", frames, hitches, missed, now - started)
            accessibilityLabel = s
            text = s
        }
    }
}
