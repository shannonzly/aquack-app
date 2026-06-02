//
//  CoachView.swift
//  Aquack Bot - ask questions, updates, etc. Work with Apple Intelligience, WIP
//  Aquack
//

import SwiftData
import SwiftUI

struct CoachChatMessage: Identifiable {
    enum Role { case user, coach }
    let id = UUID()
    let role: Role
    let text: String
}

struct CoachView: View {
    @EnvironmentObject var rec: Change
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKey.duckCoachEnabled) private var duckCoachEnabled = true

    @State private var messages: [CoachChatMessage] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var intelligenceLabel: String?
    @FocusState private var draftFocused: Bool

    private let quickPrompts = [
        "How am I doing today?",
        "When should I drink next?",
        "Why is my goal set this way?"
    ]

    var body: some View {
        HydrationPageShell(interactive: true, bubbleIntensity: 0.9) {
            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                            if sending {
                                thinkingIndicator
                                    .id("thinking")
                            }
                        }
                        .padding(.horizontal, HomeLayout.horizontalPadding)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draftFocused = false
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: sending) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                composer
            }
        }
        .onAppear {
            intelligenceLabel = FoundationModelsCoachService.availabilityLabel
            guard messages.isEmpty else { return }
            let fallback = DuckCoachService.shared.openingMessage(rec: rec, modelContext: modelContext)
            messages = [CoachChatMessage(role: .coach, text: fallback)]
            Task {
                if let aiOpening = await DuckCoachService.shared.openingMessageWithAI(
                    rec: rec,
                    modelContext: modelContext
                ) {
                    messages = [CoachChatMessage(role: .coach, text: aiOpening)]
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            PageHeroHeader(
                title: "Ask Aquack",
                subtitle: intelligenceLabel ?? "Personalized tips from your drink history",
                useCharacter: true
            )
        }
        .padding(.horizontal, HomeLayout.horizontalPadding)
        .padding(.top, HomeLayout.heroTopInset)
        .padding(.bottom, 4)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        GlassChipButton(title: prompt) {
                            draft = prompt
                            sendMessage()
                        }
                    }
                }
                .padding(.horizontal, HomeLayout.horizontalPadding)
            }

            HStack(spacing: 8) {
                TextField("Ask Aquack…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($draftFocused)
                    .textFieldStyle(.plain)
                    .font(HydrationTypography.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(HydrationTheme.fieldFill, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 0.5))

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: sendEnabled
                                ? [HydrationTheme.accent, HydrationTheme.waterDeep]
                                : [HydrationTheme.accentSoft, HydrationTheme.accentSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!sendEnabled)
            }
            .padding(12)
            .glassSurface(cornerRadius: 22)
            .padding(.horizontal, HomeLayout.horizontalPadding)
        }
        .padding(.top, 8)
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Aquack is thinking…")
                .font(HydrationTypography.footnote)
                .foregroundStyle(HydrationTheme.label)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassSurface(cornerRadius: 16)
    }

    private var sendEnabled: Bool {
        duckCoachEnabled
        && !sending
        && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func bubble(_ message: CoachChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .coach {
                AquackCharacterImage(size: 28)
                Text(message.text)
                    .font(HydrationTypography.body)
                    .foregroundStyle(HydrationTheme.title)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassSurface(cornerRadius: 16)
                Spacer(minLength: 20)
            } else {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(HydrationTypography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if sending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sending, duckCoachEnabled else { return }
        draftFocused = false
        draft = ""
        messages.append(CoachChatMessage(role: .user, text: trimmed))
        sending = true

        Task {
            let reply = await DuckCoachService.shared.send(
                userMessage: trimmed,
                rec: rec,
                modelContext: modelContext
            )
            await MainActor.run {
                messages.append(CoachChatMessage(role: .coach, text: reply))
                sending = false
            }
        }
    }
}
