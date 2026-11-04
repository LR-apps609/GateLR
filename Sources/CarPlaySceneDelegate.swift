import CarPlay
import Combine

// CarPlay: un solo schermo con la risposta e i parcheggi fuori zona.
// Funziona solo dopo che Apple concede l'autorizzazione CarPlay «Driving Task» all'app.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var watch: AnyCancellable?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Task { @MainActor in
            await Store.shared.whenLoaded()      // prima le città vere, poi lo schermo
            interfaceController.setRootTemplate(self.template(), animated: false, completion: nil)
            // La ZTL davanti cambia mentre guidi: lo schermo si aggiorna da solo (al più ogni 3 secondi)
            self.watch = Guardian.shared.$threat.map { _ in () }
                .merge(with: Guardian.shared.$active.map { _ in () })
                .throttle(for: .seconds(3), scheduler: RunLoop.main, latest: true)
                .sink { [weak self] in
                    guard let self, let controller = self.interfaceController else { return }
                    MainActor.assumeIsolated { controller.setRootTemplate(self.template(), animated: false, completion: nil) }
                }
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        watch = nil
    }

    @MainActor
    private func template() -> CPTemplate {
        let store = Store.shared
        let answer = store.answer(hotelInside: false)
        let zone = store.zone
        var items: [CPInformationItem] = []
        // Con il guardiano attivo, in auto conta la prossima ZTL davanti
        if Guardian.shared.active {
            // 1.19.3: le parole di ThreatEvaluator (aree pedonali, fonte non ufficiale); fuori dalle città che conosciamo
            // «Non conosciamo le ZTL di questo posto», non «Nessuna ZTL attiva davanti»
            if let t = Guardian.shared.threat {
                items.append(CPInformationItem(title: (t.title ?? t.candidate.name) + " · " + DriveSession.distanceText(t.meters), detail: t.spoken))
            } else {
                items.append(CPInformationItem(title: L(Guardian.shared.resting == .clear ? "No active ZTL ahead" : "We don't know the ZTLs of this place"),
                                               detail: Guardian.shared.destination?.name ?? ""))
            }
        }
        items += [
            CPInformationItem(title: answer.verdict.title, detail: detail(answer.verdict)),
            CPInformationItem(title: zone.localizedName, detail: answer.gatesOn ? L("ZTL active") : L("ZTL not active")),
            CPInformationItem(title: L("Source"), detail: "\(zone.source.localizedAuthority) · " + String(format: L("Read %@"), zone.source.checkedOn.formatted(date: .abbreviated, time: .omitted))
                              + " · " + RuleEngine().verifiedShort(zone.source)),
        ]
        let refresh = CPTextButton(title: L("Refresh"), textStyle: .normal) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.interfaceController?.setRootTemplate(self.template(), animated: false, completion: nil)
            }
        }
        return CPInformationTemplate(title: "GateLR", layout: .leading, items: items, actions: [refresh])
    }

    private func detail(_ v: Verdict) -> String {
        switch v {
        case .yes(let r), .no(let r), .unsure(let r): r
        case .conditional(_, let c): c
        }
    }
}
