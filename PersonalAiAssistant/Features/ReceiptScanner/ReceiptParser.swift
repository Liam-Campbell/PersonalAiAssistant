import Foundation
import MLXLLM
import MLXLMCommon

struct ParsedReceipt: Codable, Equatable {
    var storeName: String
    var purchaseDate: String
    var subtotal: Double?
    var tax: Double?
    var total: Double
    var currency: String
    var transactionType: String
    var cardLastFour: String?
    var items: [ParsedItem]

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case purchaseDate = "purchase_date"
        case subtotal, tax, total, currency
        case transactionType = "transaction_type"
        case cardLastFour = "card_last_four"
        case items
    }
}

struct ParsedItem: Codable, Equatable {
    var name: String
    var quantity: Int
    var unitPrice: Double
    var lineTotal: Double

    enum CodingKeys: String, CodingKey {
        case name, quantity
        case unitPrice = "unit_price"
        case lineTotal = "line_total"
    }
}

enum ReceiptParserError: Error {
    case modelNotAvailable
    case jsonExtractionFailed
    case jsonDecodingFailed(String)
}

struct ReceiptParser {
    private let promptTemplate = """
    You are a receipt parser. Extract structured data from this receipt text.
    Return ONLY valid JSON with this exact structure, no other text:
    {
      "store_name": "...",
      "purchase_date": "YYYY-MM-DD",
      "subtotal": 0.00,
      "tax": 0.00,
      "total": 0.00,
      "currency": "GBP",
      "transaction_type": "contactless|chip_and_pin|cash|online|other",
      "card_last_four": "1234",
      "items": [
        {"name": "...", "quantity": 1, "unit_price": 0.00, "line_total": 0.00}
      ]
    }

    Receipt text:
    """

    func parseSingleAttempt(ocrText: String, modelContainer: MLXLMCommon.ModelContainer) async throws -> (parsed: ParsedReceipt, rawOutput: String) {
        let prompt = promptTemplate + ocrText
        let rawOutput = try await runModel(prompt: prompt, modelContainer: modelContainer)
        let parsed = try decodeReceipt(from: rawOutput)
        return (parsed, rawOutput)
    }

    private func runModel(prompt: String, modelContainer: MLXLMCommon.ModelContainer) async throws -> String {
        let session = ChatSession(modelContainer)
        var fullResponse = ""
        let stream = session.streamResponse(to: prompt)
        for try await chunk in stream {
            fullResponse += chunk
        }
        return fullResponse
    }

    private func decodeReceipt(from rawOutput: String) throws -> ParsedReceipt {
        let jsonString = extractJSON(from: rawOutput)
        guard let data = jsonString.data(using: .utf8) else {
            throw ReceiptParserError.jsonExtractionFailed
        }
        do {
            return try JSONDecoder().decode(ParsedReceipt.self, from: data)
        } catch {
            throw ReceiptParserError.jsonDecodingFailed(error.localizedDescription)
        }
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}
