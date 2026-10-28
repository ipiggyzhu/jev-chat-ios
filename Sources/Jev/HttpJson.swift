import Foundation

struct ApiException: Error, LocalizedError {
    var route: String
    var status: Int?
    var snippet: String

    var errorDescription: String? {
        if let status {
            return "\(route) HTTP \(status)：\(snippet.prefix(120))"
        }
        return "\(route) 请求失败：\(snippet.prefix(120))"
    }
}

/// Shared POST-JSON helper, ported from the original HttpJson:
/// up to 3 attempts, backoff on 429/529, other 4xx are not retried,
/// and status is read before the body so it can never be lost.
enum HttpJson {
    static func post(url: String, key: String, body: [String: Any], route: String) async throws -> [String: Any] {
        guard let endpoint = URL(string: url) else {
            throw ApiException(route: route, status: nil, snippet: "地址无效：\(url)")
        }
        var lastError: Error?
        for attempt in 0..<3 {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 40
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            if url.contains("openrouter.ai") {
                request.setValue("https://jev-assistant.local", forHTTPHeaderField: "HTTP-Referer")
                request.setValue("Jev Assistant", forHTTPHeaderField: "X-Title")
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let text = String(data: data, encoding: .utf8) ?? ""
                if code == 429 || code == 529 {
                    lastError = ApiException(route: route, status: code, snippet: "服务繁忙，已重试")
                    if attempt < 2 { try await Task.sleep(nanoseconds: UInt64(500 * (1 << (attempt + 1))) * 1_000_000) }
                    continue
                }
                if !(200...299).contains(code) {
                    throw ApiException(route: route, status: code, snippet: text.isEmpty ? "（响应体为空）" : text)
                }
                if text.isEmpty {
                    throw ApiException(route: route, status: code, snippet: "响应体为空")
                }
                guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw ApiException(route: route, status: code, snippet: "响应不是 JSON 对象")
                }
                return obj
            } catch let e as ApiException {
                if let s = e.status, (400...499).contains(s) { throw e }
                lastError = e
                if attempt < 2 { try await Task.sleep(nanoseconds: UInt64(500 * (1 << (attempt + 1))) * 1_000_000) }
            } catch {
                lastError = ApiException(route: route, status: nil, snippet: describe(error))
                if attempt < 2 { try await Task.sleep(nanoseconds: UInt64(500 * (1 << (attempt + 1))) * 1_000_000) }
            }
        }
        throw lastError ?? ApiException(route: route, status: nil, snippet: "请求失败")
    }

    private static func describe(_ error: Error) -> String {
        let m = error.localizedDescription
        if m.contains("timed out") || m.contains("超时") { return "网络超时，请检查连接" }
        if m.contains("not be resolved") || m.contains("hostname") { return "域名解析失败，地址填错或无网络" }
        if m.contains("Could not connect") || m.contains("无法连接") { return "无法连接该地址" }
        if m.contains("secure connection") || m.contains("SSL") { return "HTTPS 证书校验失败" }
        return m
    }
}
