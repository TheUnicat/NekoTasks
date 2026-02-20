//
//  AssistantView.swift
//  NekoTasks
//
//  Created by TheUnicat on 2/8/26.
//
//  CLAUDE NOTES:
//  AI chat interface. Outer AssistantView wraps an availability check (macOS 26+ required for FoundationModels).
//  Inner AssistantContent: checks SystemLanguageModel.default.availability, shows chat or unavailable message.
//  Chat: message list (ScrollViewReader for auto-scroll), empty state, TypingBubble (animated dots), text input.
//  sendMessage() calls pipeline.send(message:modelContext:), which manages currentToolContext internally.
//  Tools insert items directly into SwiftData during session.respond(). AIPipeline saves the context after.
//  Task block uses @MainActor to ensure model context operations run on main thread.
//  Clear button resets messages and calls pipeline.resetSession() (new LanguageModelSession, no persistence).
//  MessageBubble: user=blue right-aligned, assistant=gray left-aligned. TypingBubble: 3 bouncing dots.
//  TextField uses .plain style with gray background to avoid macOS blue focus ring.
//

import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Assistant View (availability wrapper)

struct AssistantView: View {
    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            AssistantContent()
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Requires iOS 26 or macOS 26")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Assistant")
            }
        }
    }
}

// MARK: - Assistant Content

@available(iOS 26, macOS 26, *)
private struct AssistantContent: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pipeline = AIPipeline()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false

    private let model = SystemLanguageModel.default

    var body: some View {
        NavigationStack {
            Group {
                switch model.availability {
                case .available:
                    chatView
                default:
                    unavailableView
                }
            }
            .navigationTitle("Assistant")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        clearChat()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    // MARK: - Chat View

    @ViewBuilder
    private var chatView: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("NekoTasks Assistant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Ask me to create tasks or events")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                            if isLoading {
                                TypingBubble()
                                    .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        withAnimation {
                            if loading {
                                proxy.scrollTo("loading", anchor: .bottom)
                            } else if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Ask anything...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .onSubmit { sendMessage() }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding()
        }
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Apple Intelligence Unavailable")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Enable Apple Intelligence in Settings to use the assistant.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isLoading = true

        Task { @MainActor in
            do {
                let response = try await pipeline.send(message: text, modelContext: modelContext)
                messages.append(ChatMessage(role: .assistant, content: response))
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, something went wrong: \(error.localizedDescription)"))
            }
            isLoading = false
        }
    }

    private func clearChat() {
        messages.removeAll()
        pipeline.resetSession()
    }
}

// MARK: - Typing Bubble

private struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .offset(y: animating ? -3 : 3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )

            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(message.role == .user ? Color.blue : Color.gray.opacity(0.15))
                )
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Preview

#Preview {
    AssistantView()
        .modelContainer(for: [TaskItem.self, TaskLabel.self], inMemory: true)
}
