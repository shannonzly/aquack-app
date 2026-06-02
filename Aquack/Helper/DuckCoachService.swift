//
//  DuckCoachService.swift
//  Aquack
//

import Foundation
import SwiftData

@MainActor
final class DuckCoachService {
    static let shared = DuckCoachService()

    private init() {}

    func openingMessage(rec: Change, modelContext: ModelContext) -> String {
        let context = CoachContextBuilder.build(rec: rec, context: modelContext)
        return ContextualCoachService.openingMessage(context: context)
    }

    func openingMessageWithAI(rec: Change, modelContext: ModelContext) async -> String? {
        let context = CoachContextBuilder.build(rec: rec, context: modelContext)
        if FoundationModelsCoachService.isAvailable,
           let generated = await FoundationModelsCoachService.openingMessage(context: context) {
            return generated
        }
        return nil
    }

    func send(
        userMessage: String,
        rec: Change,
        modelContext: ModelContext
    ) async -> String {
        let context = CoachContextBuilder.build(rec: rec, context: modelContext)
        if FoundationModelsCoachService.isAvailable,
           let generated = await FoundationModelsCoachService.reply(to: userMessage, context: context) {
            return generated
        }
        return ContextualCoachService.reply(to: userMessage, context: context)
    }

    func resetConversation() {
        FoundationModelsCoachService.resetSession()
    }
}
