//
//  ParseDateTime.swift
//  NekoTasks
//
//  CLAUDE NOTES:
//  Shared NLP date parser used by CreateTaskTool, CreateEventTool, and ShowTask.
//  Uses NSDataDetector to parse natural language dates (e.g. "tomorrow", "next Monday",
//  "March 15 2pm"). Falls back to ISO8601 for backwards compatibility with cached sessions.
//  Keep this file dependency-free (Foundation only).
//

import Foundation

/// Parses a date string using NLP (NSDataDetector) with ISO8601 fallback.
/// Accepts natural language like "tomorrow", "next Friday", "March 15 2pm",
/// as well as ISO8601 strings like "2026-03-15T14:00:00Z".
func parseNaturalDate(_ text: String) -> Date? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Try NSDataDetector for natural language
    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = detector.firstMatch(in: trimmed, options: [], range: range) {
            return match.date
        }
    }

    // Fallback to ISO8601
    return ISO8601DateFormatter().date(from: trimmed)
}
