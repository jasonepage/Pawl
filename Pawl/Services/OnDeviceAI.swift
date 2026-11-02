//
//  OnDeviceAI.swift
//  Pawl
//
//  2.4: small on-device language tasks with Apple's Foundation Models (iOS 26, Apple
//  Intelligence phones). Everything runs on the phone. Nothing is sent anywhere, which keeps
//  the "no Pawl server, no data collected" promise. On phones without the model the caller
//  gets nil and uses the text as typed.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceAI {
    /// True when the on-device model can run right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Turns whatever the person typed on the payoff screen into a short noun phrase that reads
    /// well after "You wanted ... back." For example "tiktok at night" becomes "my evenings" and
    /// "stop wasting money on slots" becomes "my money". Returns nil when the model is not
    /// available or the answer is not usable, so the caller keeps the raw text.
    static func tidyGoal(_ raw: String) async -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        #if canImport(FoundationModels)
        guard #available(iOS 26, *), isAvailable else { return nil }
        let instructions = """
        You tidy a short phrase so it fits the sentence "You wanted ___ back."
        Reply with only the phrase, 1 to 5 plain lowercase words, starting with "my" or "our".
        Rules:
        - Never add a person, place, thing or reason the person did not type. "my time" stays "my time". Do not turn it into "my time with family" or anything else.
        - Only remove filler like "I want", "get", "back", "to have", and add "my" when it is missing.
        - If the phrase already fits, return it unchanged.
        - If you are not sure, return it unchanged.
        - No punctuation. No explanation.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let reply = try await session.respond(to: text).content
            let cleaned = reply
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            let words = cleaned.split(separator: " ").map(String.init)
            guard (1...6).contains(words.count), cleaned.count <= 40 else { return nil }
            // Belt and braces: the model may only drop words or add "my"/"our". Any other new
            // word means it invented something, so keep what the person typed instead.
            let allowedNew: Set<String> = ["my", "our"]
            let typed = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            for w in words where !typed.contains(w) && !allowedNew.contains(w) { return nil }
            return cleaned
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
