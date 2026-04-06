import Foundation
import Observation
import MLXLLM
import MLXLMCommon

@Observable final class ChatModel {

    struct Message: Identifiable {
        let id = UUID()
        let isUser: Bool
        var text: String
    }

    private(set) var messages: [Message] = []
    private(set) var isGenerating = false
    private(set) var isLoadingModel = true
    private(set) var loadError: String?

    private var chatSession: ChatSession?

    func loadModel() async {
        isLoadingModel = true
        loadError = nil
        defer { isLoadingModel = false }

        do {
            patchConfigIfNeeded()
            let container = try await loadModelContainer(
                directory: ModelDownloadService.modelDirectory
            )
            chatSession = ChatSession(container)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func patchConfigIfNeeded() {
        let configURL = ModelDownloadService.modelDirectory.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var textConfig = json["text_config"] as? [String: Any] else { return }

        let requiredFields: [String: Int] = [
            "num_attention_heads": 8,
            "num_key_value_heads": 4,
            "head_dim": 256
        ]

        var patched = false
        for (key, value) in requiredFields {
            let existingValue = (textConfig[key] as? NSNumber)?.intValue
            if existingValue != value {
                textConfig[key] = value
                patched = true
            }
        }

        guard patched else { return }
        json["text_config"] = textConfig
        if let updatedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? updatedData.write(to: configURL)
        }
    }

    func dismissLoadError() {
        loadError = nil
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, chatSession != nil else { return }

        messages.append(Message(isUser: true, text: trimmed))
        messages.append(Message(isUser: false, text: ""))
        isGenerating = true

        do {
            let stream = chatSession!.streamResponse(to: trimmed)
            for try await chunk in stream {
                messages[messages.count - 1].text += chunk
            }
        } catch {
            if messages[messages.count - 1].text.isEmpty {
                messages[messages.count - 1].text = "Error: \(error.localizedDescription)"
            }
        }

        isGenerating = false
    }
}
