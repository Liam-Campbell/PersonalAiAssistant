import Foundation
import Observation
import MLXLLM
import MLXLMTokenizers

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
            let context = try await MLXLLM.loadModel(
                from: ModelDownloadService.modelDirectory,
                using: TokenizersLoader()
            )
            chatSession = ChatSession(context)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func send(_ text: String) async {
        guard let session = chatSession else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(Message(isUser: true, text: trimmed))
        isGenerating = true

        do {
            let response = try await session.respond(to: trimmed)
            messages.append(Message(isUser: false, text: response))
        } catch {
            messages.append(Message(isUser: false, text: "Error: \(error.localizedDescription)"))
        }

        isGenerating = false
    }
}
