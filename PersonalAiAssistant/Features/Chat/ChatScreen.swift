import SwiftUI

struct ChatScreen: View {
    @State private var model = ChatModel()
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { loadingOverlay }
            .task { await model.loadModel() }
            .alert(
                "Failed to Load Model",
                isPresented: Binding(
                    get: { model.loadError != nil },
                    set: { if !$0 { model.dismissLoadError() } }
                )
            ) {
                Button("OK") { model.dismissLoadError() }
            } message: {
                Text(model.loadError ?? "")
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if model.isGenerating {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: model.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: model.isGenerating) { _, generating in
                if generating { scrollToBottom(proxy: proxy, anchor: "typing") }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isGenerating)
        }
        .padding()
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if model.isLoadingModel {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading model…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task { await model.send(text) }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, anchor: String? = nil) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let anchor {
                proxy.scrollTo(anchor, anchor: .bottom)
            } else if let last = model.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatModel.Message

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }

            Text(message.text)
                .padding(12)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !message.isUser { Spacer(minLength: 48) }
        }
    }
}

private struct TypingIndicator: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(String(repeating: ".", count: dotCount + 1))
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(width: 40, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 3
            }
    }
}
