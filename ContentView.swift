import SwiftUI

struct ContentView: View {
    @StateObject private var model = DiagnosticModel()
    @State private var customAddress = ""

    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.065, blue: 0.09).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    statusCard
                    HStack {
                        Text("Сервисы").font(.title2.bold())
                        Spacer()
                        Button("Проверить все") { Task { await model.checkAll() } }
                            .buttonStyle(.bordered).tint(.mint)
                    }
                    VStack(spacing: 10) {
                        ForEach(model.services) { service in
                            ServiceRow(service: service) { Task { await model.check(service) } }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Проверить адрес").font(.title2.bold())
                        HStack {
                            TextField("https://example.com", text: $customAddress)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            Button {
                                Task { await model.checkCustom(customAddress) }
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2).foregroundStyle(.mint)
                            }
                        }
                    }
                    analysisCard
                    historyCard
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .font(.system(size: 32, weight: .bold)).foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text("NetAdapt").font(.largeTitle.bold())
                Text("NETWORK DIAGNOSTICS")
                    .font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(model.isRunning ? .orange : (model.online ? .mint : .red)).frame(width: 10, height: 10)
                Text(model.isRunning ? "Выполняется диагностика" : (model.online ? "Есть ответы от сервисов" : "Сеть не проверена"))
                    .font(.headline)
                Spacer()
            }
            Text(model.isRunning ? "Проверяем HTTPS-доступность…" : "Запустите проверку, чтобы увидеть состояние выбранных сервисов.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { Task { await model.checkAll() } } label: {
                Label("Запустить диагностику", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.mint).disabled(model.isRunning)
        }
        .padding(18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Анализ", systemImage: "brain.head.profile").font(.title2.bold())
            Text(model.analysis).foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Последние проверки").font(.title2.bold())
            if model.history.isEmpty {
                Text("История появится после первой диагностики.").foregroundStyle(.secondary)
            }
            ForEach(model.history.prefix(8), id: \.self) { entry in
                Text(entry).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}


struct ServiceRow: View {
    let service: ServiceStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: service.symbol).frame(width: 34).foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name).font(.headline)
                Text(service.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if service.loading {
                ProgressView()
            } else if let latency = service.latency {
                Text("\(latency) ms").font(.caption.monospaced()).foregroundStyle(service.ok ? .mint : .orange)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
            Button(action: action) { Image(systemName: "arrow.clockwise").foregroundStyle(.mint) }
                .disabled(service.loading)
        }
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }
}
