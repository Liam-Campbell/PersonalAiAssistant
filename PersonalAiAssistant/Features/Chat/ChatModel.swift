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
        defer { isLoadingModel = false }

        do {
            let container = try await loadModelContainer(
                directory: ModelDownloadService.modelDirectory
            )
            chatSession = ChatSession(container)
        } catch {
            loadError = error.localizedDescription
        }
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
