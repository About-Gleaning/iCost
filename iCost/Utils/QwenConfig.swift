import Foundation

enum QwenConfig {
    static func load() -> QwenBillParser.Config? {
        let dict = Bundle.main.infoDictionary ?? [:]
        let endpointString = (dict["QWEN_ENDPOINT"] as? String) ?? ProcessInfo.processInfo.environment["QWEN_ENDPOINT"]
        let apiKey = (dict["QWEN_API_KEY"] as? String)
            ?? ProcessInfo.processInfo.environment["QWEN_API_KEY"]
            ?? ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"]
        let model = (dict["QWEN_MODEL"] as? String) ?? "qwen3-omni-flash"
        guard let es = endpointString, let url = URL(string: es), let key = apiKey, !key.isEmpty else { return nil }
        return QwenBillParser.Config(endpoint: url, apiKey: key, model: model)
    }
}
