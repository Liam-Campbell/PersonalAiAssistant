import Foundation
import Observation
import MLXLLM
import MLXLMCommon

@Observable final class ModelLoader {
    private(set) var isLoading = true
    private(set) var loadError: String?
    private(set) var modelContainer: ModelContainer?

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            patchConfigIfNeeded()
            let container = try await loadModelContainer(
                directory: ModelDownloadService.modelDirectory
            )
            modelContainer = container
            await AppLogger.shared.log(.info, source: "ModelLoader", message: "Model loaded successfully")
        } catch {
            loadError = error.localizedDescription
            await AppLogger.shared.log(.error, source: "ModelLoader", message: "Failed to load model", detail: error.localizedDescription)
        }
    }

    func dismissLoadError() {
        loadError = nil
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
}
