import Foundation
import SwiftUI

struct ServiceStatus: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let symbol: String
    var detail = "Не проверено"
    var latency: Int? = nil
    var ok = false
    var loading = false
}


@MainActor
final class DiagnosticModel: ObservableObject {
    @Published var services: [ServiceStatus] = [
        ServiceStatus(name: "YouTube", url: URL(string: "https://www.youtube.com")!, symbol: "play.rectangle"),
        ServiceStatus(name: "Telegram", url: URL(string: "https://telegram.org")!, symbol: "paperplane"),
        ServiceStatus(name: "Discord", url: URL(string: "https://discord.com")!, symbol: "bubble.left.and.bubble.right"),
        ServiceStatus(name: "ChatGPT", url: URL(string: "https://chatgpt.com")!, symbol: "sparkles"),
        ServiceStatus(name: "Wikipedia", url: URL(string: "https://www.wikipedia.org")!, symbol: "book"),
        ServiceStatus(name: "GitHub", url: URL(string: "https://github.com")!, symbol: "chevron.left.forwardslash.chevron.right")
    ]
    @Published var isRunning = false
    @Published var online = false
    @Published var analysis = "Запустите проверку. Приложение измерит HTTPS-ответы и время отклика. Эти тесты не позволяют достоверно определить причину недоступности."
    @Published var history: [String] = UserDefaults.standard.stringArray(forKey: "netadapt.history") ?? []

    func checkAll() async {
        guard !isRunning else { return }
        isRunning = true
        for index in services.indices { await runCheck(index: index) }
        isRunning = false
        online = services.contains(where: { $0.ok })
        summarize()
        addHistory("Общая проверка: \(services.filter { $0.ok }.count)/\(services.count) доступно")
    }

    func check(_ service: ServiceStatus) async {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        await runCheck(index: index)
        online = services.contains(where: { $0.ok })
        summarize()
        addHistory("\(service.name): \(services[index].detail)")
    }

    func checkCustom(_ input: String) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.hasPrefix("http") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate), url.host != nil else {
            analysis = "Введите корректный адрес, например https://example.com."
            return
        }
        let start = Date()
        do {
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.httpMethod = "HEAD"
            let (_, response) = try await URLSession.shared.data(for: request)
            let milliseconds = Int(Date().timeIntervalSince(start) * 1000)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            analysis = "\(url.host ?? "Адрес"): HTTP \(code), около \(milliseconds) мс. HTTP-код сам по себе не указывает на блокировку."
            addHistory("\(url.host ?? candidate): HTTP \(code), \(milliseconds) мс")
        } catch {
            analysis = "Не удалось получить HTTPS-ответ от \(url.host ?? candidate). Возможны проблемы сети, DNS, сервера или TLS. Тест не определяет причину однозначно."
            addHistory("\(url.host ?? candidate): ошибка соединения")
        }
    }

    private func runCheck(index: Int) async {
        services[index].loading = true
        services[index].detail = "Проверка HTTPS…"
        let url = services[index].url
        let start = Date()
        do {
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.httpMethod = "HEAD"
            let (_, response) = try await URLSession.shared.data(for: request)
            let milliseconds = Int(Date().timeIntervalSince(start) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            services[index].ok = (200..<500).contains(statusCode)
            services[index].latency = milliseconds
            services[index].detail = "HTTP \(statusCode) · HTTPS ответ получен"
        } catch {
            services[index].ok = false
            services[index].latency = nil
            services[index].detail = "HTTPS-ответ не получен"
        }
        services[index].loading = false
    }

    private func summarize() {
        let passed = services.filter { $0.ok }.count
        let failed = services.count - passed
        if failed == 0 {
            analysis = "Все \(services.count) сервисов ответили по HTTPS. Это результат проверки в текущей сети."
        } else if passed == 0 {
            analysis = "Не получено HTTPS-ответов от проверенных сервисов. Проверьте общее подключение и повторите позже. Причина не установлена."
        } else {
            let unavailable = services.filter { !$0.ok }.map { $0.name }.joined(separator: ", ")
            analysis = "Ответили \(passed) из \(services.count). Не ответили: \(unavailable). Причиной может быть сеть, DNS, сервер, TLS или фильтрация."
        }
    }

    private func addHistory(_ value: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm"
        history.insert("\(formatter.string(from: Date())) — \(value)", at: 0)
        history = Array(history.prefix(100))
        UserDefaults.standard.set(history, forKey: "netadapt.history")
    }
}
