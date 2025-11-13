import Foundation

struct ParsedBill: Sendable {
    let amount: Double
    let category: Category
    let note: String
}

protocol BillParser: Sendable {
    func parse(text: String) async throws -> ParsedBill
    func parseAudio(url: URL) async throws -> ParsedBill
}

struct RuleBasedBillParser: BillParser {
    func parse(text: String) async throws -> ParsedBill {
        let lower = text.lowercased()
        var category: Category = Category.other
        if lower.contains("餐") || lower.contains("饭") { category = .food }
        else if lower.contains("交通") || lower.contains("地铁") || lower.contains("公交") { category = .transport }
        else if lower.contains("娱") || lower.contains("电影") { category = .entertainment }
        else if lower.contains("购物") || lower.contains("买") { category = .shopping }
        else if lower.contains("日用") { category = .daily }
        else if lower.contains("医") { category = .medical }
        else if lower.contains("教") { category = .education }
        let regex = try? NSRegularExpression(pattern: "[0-9]+(\\.[0-9]{1,2})?", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var amount: Double = 0
        if let match = regex?.firstMatch(in: text, options: [], range: range), let r = Range(match.range, in: text) { amount = Double(text[r]) ?? 0 }
        return ParsedBill(amount: amount, category: category, note: text)
    }

    func parseAudio(url: URL) async throws -> ParsedBill {
        throw NSError(domain: "RuleParser", code: 100, userInfo: [NSLocalizedDescriptionKey: "未配置云端解析，无法直接识别语音"])
    }
}

struct QwenBillParser: BillParser {
    struct Config: Sendable {
        let endpoint: URL
        let apiKey: String
        let model: String
    }
    private let config: Config?
    init(config: Config? = QwenConfig.load()) { self.config = config }

    func parse(text: String) async throws -> ParsedBill {
        guard let cfg = config else { return try await RuleBasedBillParser().parse(text: text) }
        let chatEndpoint = cfg.endpoint.path.hasSuffix("/v1") ? cfg.endpoint.appendingPathComponent("chat/completions") : cfg.endpoint
        var req = URLRequest(url: chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        let prompt = "请从下面的中文消费描述中抽取金额(数字)、类别(中文类别)、备注(原文简要)。仅以JSON输出，不要包含多余文字。JSON字段为: amount(number), category(string), note(string)。输入：\(text)"
        let body: [String: Any] = [
            "model": cfg.model,
            "messages": [
                [
                    "role": "user",
                    "content": [["type": "text", "text": prompt]]
                ]
            ],
            "modalities": ["text"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("Qwen: request endpoint=\(chatEndpoint.absoluteString) model=\(cfg.model)")
        print("Qwen: request body bytes=\(req.httpBody?.count ?? 0)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse { print("Qwen: status=\(http.statusCode)") }
        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("Qwen: response=\(raw)")
        if let parsed = try? decodeFromChoices(data: data) { return parsed }
        if let parsed = try? decodeFromText(data: data) { return parsed }
        throw NSError(domain: "Qwen", code: 2)
    }

    func parseAudio(url: URL) async throws -> ParsedBill {
        guard let cfg = config else { throw NSError(domain: "Qwen", code: 101, userInfo: [NSLocalizedDescriptionKey: "未配置云端解析"])}
        let data = try Data(contentsOf: url)
        let b64 = data.base64EncodedString()
        let chatEndpoint = cfg.endpoint.path.hasSuffix("/v1") ? cfg.endpoint.appendingPathComponent("chat/completions") : cfg.endpoint
        var req = URLRequest(url: chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        let dataURI = "data:audio/m4a;base64,\(b64)"
        let body: [String: Any] = [
            "model": cfg.model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_audio", "input_audio": ["format": "m4a", "data": dataURI]],
                        ["type": "text", "text": "请从以上语音内容中抽取金额(数字)、类别(中文类别)、备注(原文简要)。仅以JSON输出，不要包含多余文字。JSON字段为: amount(number), category(string), note(string)。"]
                    ]
                ]
            ],
            "modalities": ["text"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("Qwen: audio request endpoint=\(chatEndpoint.absoluteString) model=\(cfg.model) bytes=\(data.count)")
        let (respData, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse { print("Qwen: status=\(http.statusCode)") }
        let raw = String(data: respData, encoding: .utf8) ?? "<non-utf8>"
        print("Qwen: response=\(raw)")
        if let parsed = try? decodeFromChoices(data: respData) { return parsed }
        if let parsed = try? decodeFromText(data: respData) { return parsed }
        throw NSError(domain: "Qwen", code: 102)
    }

    private func decodeFromChoices(data: Data) throws -> ParsedBill {
        struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
        struct Resp: Decodable { let choices: [Choice] }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = resp.choices.first?.message.content else { throw NSError(domain: "Qwen", code: 3) }
        return try decodeJSONText(text)
    }
    private func decodeFromText(data: Data) throws -> ParsedBill {
        struct Resp: Decodable { let output_text: String? }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = resp.output_text else { throw NSError(domain: "Qwen", code: 4) }
        return try decodeJSONText(text)
    }
    private func decodeJSONText(_ text: String) throws -> ParsedBill {
        let json = extractJSON(text)
        struct J: Decodable { let amount: Double; let category: String; let note: String? }
        guard let data = json.data(using: .utf8) else { throw NSError(domain: "Qwen", code: 5) }
        let j = try JSONDecoder().decode(J.self, from: data)
        let out = ParsedBill(amount: j.amount, category: mapCategory(j.category), note: j.note ?? text)
        print("Qwen: parsed amount=\(out.amount) category=\(out.category.rawValue) note=\(out.note)")
        return out
    }
    private func extractJSON(_ s: String) -> String {
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") { return String(s[start...end]) }
        return s
    }
    private func mapCategory(_ s: String) -> Category {
        let lower = s.lowercased()
        if lower.contains("餐") || lower.contains("饭") { return .food }
        if lower.contains("交通") || lower.contains("地铁") || lower.contains("公交") { return .transport }
        if lower.contains("娱") || lower.contains("电影") { return .entertainment }
        if lower.contains("购物") || lower.contains("买") { return .shopping }
        if lower.contains("日用") { return .daily }
        if lower.contains("医") { return .medical }
        if lower.contains("教") { return .education }
        return .other
    }
}
