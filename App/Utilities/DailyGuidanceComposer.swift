import Foundation

/// Converts the selected specialist's derivable note into one practical-first
/// record shared by every daily surface.
nonisolated enum DailyGuidanceComposer {
    /// Ephemeris-actor isolated: composes from `DailyExpertNoteComposer`,
    /// which reads the ephemeris; all raw ephemeris access shares that one
    /// serialization domain (see EphemerisActor.swift).
    @EphemerisActor
    static func guidance(
        for specialistId: String,
        sourceName: String,
        on date: Date = Date(),
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?
    ) -> DailyGuidance {
        let note = DailyExpertNoteComposer.note(
            for: specialistId,
            on: date,
            sun: sun,
            moon: moon,
            rising: rising
        )

        return DailyGuidance(
            dateKey: DailyGuidance.dateKey(for: date),
            sourceName: sourceName,
            sourceId: note.specialistId,
            notice: practicalNotice(for: note.specialistId),
            action: note.move,
            astrologicalRationale: note.headline,
            eveningCheckIn: eveningCheckIn(for: note.specialistId)
        )
    }

    @EphemerisActor
    static func notificationBody(
        for specialistId: String,
        sourceName: String,
        on date: Date,
        sun: ZodiacSign?,
        moon: ZodiacSign?,
        rising: ZodiacSign?
    ) -> String {
        let guidance = guidance(
            for: specialistId,
            sourceName: sourceName,
            on: date,
            sun: sun,
            moon: moon,
            rising: rising
        )
        return "\(guidance.notice) \(guidance.action)"
    }

    private static func practicalNotice(for specialistId: String) -> String {
        switch specialistId {
        case "mateo-vedic":
            "Notice which responsibility feels important before it becomes urgent."
        case "naomi-chinese":
            "Notice where a smaller, clearer choice would reduce friction."
        case "elias-ancient":
            "Notice which conversation benefits from patience more than speed."
        case "nadia-evolutionary":
            "Notice the reflex that appears just before your considered response."
        default:
            "Notice where tone matters more than finding perfect words today."
        }
    }

    private static func eveningCheckIn(for specialistId: String) -> String {
        switch specialistId {
        case "nadia-evolutionary":
            "Tonight: what did you protect today, and did it need protecting?"
        default:
            "Tonight: what changed after you tried the suggested action?"
        }
    }
}
