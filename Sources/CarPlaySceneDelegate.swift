import CarPlay

// CarPlay: un solo schermo con la risposta e i parcheggi fuori zona.
// Funziona solo dopo che Apple concede l'autorizzazione CarPlay «Driving Task» all'app.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        Task { @MainActor in
            interfaceController.setRootTemplate(self.template(), animated: false, completion: nil)
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
    }

    @MainActor
    private func template() -> CPTemplate {
        let store = Store.shared
        let answer = store.answer()
        let zone = store.zone
        let items = [
            CPInformationItem(title: answer.verdict.title, detail: detail(answer.verdict)),
            CPInformationItem(title: zone.localizedName, detail: answer.gatesOn ? L("ZTL active") : L("ZTL not active")),
            CPInformationItem(title: L("Source"), detail: "\(zone.source.localizedAuthority) · " + String(format: L("Read %@"), zone.source.checkedOn.formatted(date: .abbreviated, time: .omitted))),
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
