import SwiftUI
import Network

final class Pairing: ObservableObject {
    @Published var devices: [NWBrowser.Result] = []
    @Published var peerCode: String?

    let myCode = String(Int.random(in: 1000...9999))
    private let type = "_pairdemo._tcp"
    private let myName = "iPhone-" + UUID().uuidString.prefix(6)
    private var listener: NWListener?
    private var browser: NWBrowser?

    func start() {
        let l = try! NWListener(using: .tcp)
        l.service = NWListener.Service(name: myName, type: type)
        l.newConnectionHandler = { [weak self] conn in self?.exchange(conn) }
        l.start(queue: .main)
        listener = l

        let b = NWBrowser(for: .bonjour(type: type, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.devices = results.filter { r in
                if case .service(let name, _, _, _) = r.endpoint {
                    return name != self.myName
                }
                return true
            }
        }
        b.start(queue: .main)
        browser = b
    }

    func connect(to result: NWBrowser.Result) {
        exchange(NWConnection(to: result.endpoint, using: .tcp))
    }

    private func exchange(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.send(content: Data((myCode + "\n").utf8), completion: .contentProcessed { _ in })
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64) { [weak self] data, _, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            let code = text.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { self?.peerCode = code }
        }
    }
}

struct ContentView: View {
    @StateObject private var pairing = Pairing()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ваш код: \(pairing.myCode)")
                    .font(.largeTitle.bold())

                if let peer = pairing.peerCode {
                    Text("Код собеседника: \(peer)")
                    Text(peer == pairing.myCode ? "Коды совпали ✅" : "Коды не совпадают ❌")
                }

                List(pairing.devices, id: \.endpoint) { device in
                    Button(deviceName(device)) {
                        pairing.connect(to: device)
                    }
                }
            }
            .padding()
            .navigationTitle("Связать")
        }
        .onAppear { pairing.start() }
    }

    private func deviceName(_ r: NWBrowser.Result) -> String {
        if case .service(let name, _, _, _) = r.endpoint { return name }
        return "Устройство"
    }
}
