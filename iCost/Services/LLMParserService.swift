import Foundation

struct ParsedBill: Sendable {
    let amount: Double
    let category: Category
    let note: String
    let isIncome: Bool
    let consumedAt: Date
}

protocol BillParser: Sendable {
    func parse(text: String) async throws -> [ParsedBill]
    func parseAudio(url: URL) async throws -> [ParsedBill]
}

struct RuleBasedBillParser: BillParser {
    func parse(text: String) async throws -> [ParsedBill] {
        let lower = text.lowercased()
        var category: Category = Category.other
        if lower.contains("餐") || lower.contains("饭") { category = .food }
        else if lower.contains("交通") || lower.contains("地铁") || lower.contains("公交") { category = .transport }
        else if lower.contains("娱") || lower.contains("电影") { category = .entertainment }
        else if lower.contains("购物") || lower.contains("买") { category = .shopping }
        else if lower.contains("日用") { category = .daily }
        else if lower.contains("医") { category = .medical }
        else if lower.contains("教") { category = .education }
        let incomeKeywords = ["收入","收款","转入","工资","退款","退回","报销"]
        let expenseKeywords = ["消费","支付","花费","支出","购买","买"]
        let isIncome = incomeKeywords.contains(where: { lower.contains($0) }) && !expenseKeywords.contains(where: { lower.contains($0) })
        let regex = try? NSRegularExpression(pattern: "[0-9]+(\\.[0-9]{1,2})?", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var results: [ParsedBill] = []
        if let matches = regex?.matches(in: text, options: [], range: range), !matches.isEmpty {
            for m in matches {
                if let r = Range(m.range, in: text) {
                    let amount = Double(text[r]) ?? 0
                    results.append(ParsedBill(amount: amount, category: category, note: text, isIncome: isIncome, consumedAt: Date()))
                }
            }
        } else {
            results.append(ParsedBill(amount: 0, category: category, note: text, isIncome: isIncome, consumedAt: Date()))
        }
        return results
    }

    func parseAudio(url: URL) async throws -> [ParsedBill] {
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

    func parse(text: String) async throws -> [ParsedBill] {
        guard let cfg = config else { return try await RuleBasedBillParser().parse(text: text) }
        let chatEndpoint = cfg.endpoint.path.hasSuffix("/v1") ? cfg.endpoint.appendingPathComponent("chat/completions") : cfg.endpoint
        var req = URLRequest(url: chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = fmt.string(from: Date())
        let prompt = "请从下面的中文消费/收入描述中抽取多笔记录，每笔包含: 金额(amount: number)、类别(category: 中文字符串)、备注(note: 简要字符串)、收入标记(income: boolean，true为收入，false为支出)、消费时间(consumed_at: string，使用ISO 8601格式，如2025-11-14T20:30:00+08:00)。若用户未说明消费时间，请将consumed_at设为当前系统时间， 当前系统时间\(nowISO)。仅以JSON数组输出，不要包含多余文字。输入：\(text)"
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
        if let parsed = try? decodeArrayFromChoices(data: data) { return parsed }
        if let parsed = try? decodeArrayFromText(data: data) { return parsed }
        throw NSError(domain: "Qwen", code: 2)
    }

    func parseAudio(url: URL) async throws -> [ParsedBill] {
        guard let cfg = config else { throw NSError(domain: "Qwen", code: 101, userInfo: [NSLocalizedDescriptionKey: "未配置云端解析"])}
        let data = try Data(contentsOf: url)
        let b64 = data.base64EncodedString()
        let chatEndpoint = cfg.endpoint.path.hasSuffix("/v1") ? cfg.endpoint.appendingPathComponent("chat/completions") : cfg.endpoint
        var req = URLRequest(url: chatEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")
        let dataURI = "data:audio/m4a;base64,\(b64)"
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = fmt.string(from: Date())
        let body: [String: Any] = [
            "model": cfg.model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "input_audio", "input_audio": ["format": "m4a", "data": dataURI]],
                        ["type": "text", "text": "请从以上语音内容中抽取多笔消费/收入记录，每笔包含: 金额(amount: number)、类别(category: 中文字符串)、备注(note: 简要字符串)、收入标记(income: boolean，true为收入，false为支出)、消费时间(consumed_at: string，使用ISO 8601格式，如2025-11-14T20:30:00+08:00)。若用户未说明消费时间，请将consumed_at设为当前系统时间 \(nowISO)。仅以JSON数组输出，不要包含多余文字。"]
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
        if let parsed = try? decodeArrayFromChoices(data: respData) { return parsed }
        if let parsed = try? decodeArrayFromText(data: respData) { return parsed }
        throw NSError(domain: "Qwen", code: 102)
    }

    private func decodeArrayFromChoices(data: Data) throws -> [ParsedBill] {
        struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
        struct Resp: Decodable { let choices: [Choice] }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = resp.choices.first?.message.content else { throw NSError(domain: "Qwen", code: 3) }
        return try decodeJSONArrayOrObject(text)
    }
    private func decodeArrayFromText(data: Data) throws -> [ParsedBill] {
        struct Resp: Decodable { let output_text: String? }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = resp.output_text else { throw NSError(domain: "Qwen", code: 4) }
        return try decodeJSONArrayOrObject(text)
    }
    private func decodeJSONArrayOrObject(_ text: String) throws -> [ParsedBill] {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.contains("[") && s.contains("]") {
            let json = extractJSONArray(s)
            struct J: Decodable { let amount: Double; let category: String; let note: String?; let income: Bool?; let consumed_at: String? }
            guard let data = json.data(using: .utf8) else { throw NSError(domain: "Qwen", code: 5) }
            let arr = try JSONDecoder().decode([J].self, from: data)
            let outs = arr.map { ParsedBill(amount: $0.amount, category: mapCategory($0.category), note: $0.note ?? text, isIncome: $0.income ?? false, consumedAt: parseISODate($0.consumed_at) ?? Date()) }
            return outs
        } else {
            let json = extractJSON(text)
            struct J: Decodable { let amount: Double; let category: String; let note: String?; let income: Bool?; let consumed_at: String? }
            guard let data = json.data(using: .utf8) else { throw NSError(domain: "Qwen", code: 6) }
            let j = try JSONDecoder().decode(J.self, from: data)
            let out = ParsedBill(amount: j.amount, category: mapCategory(j.category), note: j.note ?? text, isIncome: j.income ?? false, consumedAt: parseISODate(j.consumed_at) ?? Date())
            return [out]
        }
    }
    private func extractJSON(_ s: String) -> String {
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") { return String(s[start...end]) }
        return s
    }
    private func extractJSONArray(_ s: String) -> String {
        if let start = s.firstIndex(of: "["), let end = s.lastIndex(of: "]") { return String(s[start...end]) }
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

    private func parseISODate(_ s: String?) -> Date? {
        guard let s = s else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}
