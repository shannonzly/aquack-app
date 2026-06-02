//
//  FoundationModelsCoachService.swift
//  Aquack
//

import Foundation

enum FoundationModelsCoachService {

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleIntelligenceCoach.isModelAvailable
        }
        #endif
        return false
    }

    static var availabilityLabel: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleIntelligenceCoach.availabilityLabel
        }
        #endif
        return nil
    }

    static func resetSession() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            AppleIntelligenceCoach.shared.resetSession()
        }
        #endif
    }

    static func openingMessage(context: CoachContext) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await AppleIntelligenceCoach.shared.openingMessage(context: context)
        }
        #endif
        return nil
    }

    static func reply(
        to userMessage: String,
        context: CoachContext
    ) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await AppleIntelligenceCoach.shared.reply(to: userMessage, context: context)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@MainActor
private final class AppleIntelligenceCoach {
    static let shared = AppleIntelligenceCoach()

    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?

    static var isModelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static var availabilityLabel: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Powered by Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings for smarter replies"
        case .unavailable(.deviceNotEligible):
            return nil
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is getting ready…"
        case .unavailable:
            return nil
        }
    }

    func resetSession() {
        session = nil
    }

    func openingMessage(context: CoachContext) async -> String? {
        guard Self.isModelAvailable else { return nil }
        do {
            let session = makeSession()
            let response = try await session.respond(
                to: CoachPromptBuilder.openingPrompt(context: context)
            )
            return sanitize(response.content)
        } catch {
            resetSession()
            return nil
        }
    }

    func reply(to userMessage: String, context: CoachContext) async -> String? {
        guard Self.isModelAvailable else { return nil }
        do {
            let session = session ?? makeSession()
            self.session = session
            let response = try await session.respond(
                to: CoachPromptBuilder.userPrompt(message: userMessage, context: context)
            )
            return sanitize(response.content)
        } catch {
            resetSession()
            return nil
        }
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: CoachPromptBuilder.systemInstructions)
    }

    private func sanitize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
}
#endif
