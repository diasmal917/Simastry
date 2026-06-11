import Foundation

// MARK: - The Simastry Method course
// Seven lessons in astrology-of-communication literacy, taught by the
// user's own panel guides one day at a time. Progress is device-local;
// the lesson lands in the panel thread so learning is a conversation.

nonisolated struct MethodLesson: Identifiable, Equatable, Sendable {
    /// 1-based — "Lesson 3 of 7".
    let number: Int
    let title: String
    let lesson: String
    let exercise: String
    let checkQuestion: String

    var id: Int { number }

    /// The message a guide posts into the panel for this lesson.
    var panelMessage: String {
        "Lesson \(number) of \(MethodCourseTemplates.lessons.count) — \(title). \(lesson) Try this: \(exercise) \(checkQuestion)"
    }
}

nonisolated enum MethodCourseTemplates {
    static let lessons: [MethodLesson] = [
        MethodLesson(
            number: 1,
            title: "The four elements",
            lesson: "Every sign belongs to an element, and the element is the communication engine: fire acts, earth builds, air thinks, water feels. Most misread messages are just two elements speaking different dialects.",
            exercise: "sort the three people you text most into elements.",
            checkQuestion: "Which element is missing from your inner circle?"
        ),
        MethodLesson(
            number: 2,
            title: "The three modalities",
            lesson: "Cardinal signs start things, fixed signs hold them steady, mutable signs adapt them. Same element, different job — it's why two fire signs can still run at different speeds.",
            exercise: "think of your group chat and name who starts plans, who defends them, and who bends them.",
            checkQuestion: "Which modality are you when plans change?"
        ),
        MethodLesson(
            number: 3,
            title: "Sun, Moon, Rising",
            lesson: "Your Sun is the core drive, your Moon is the private weather, your Rising is the doorway people meet first. Most first impressions are a Rising talking to a Rising.",
            exercise: "tomorrow at work or school, notice which version of you shows up in the first five minutes.",
            checkQuestion: "Which of your three signs do people meet first?"
        ),
        MethodLesson(
            number: 4,
            title: "Reading a text by element",
            lesson: "The same message reads four ways: fire hears a challenge, earth hears a commitment, air hears an idea, water hears a tone. Reading tone-first is the single biggest upgrade.",
            exercise: "reread the last text that confused you through the sender's element.",
            checkQuestion: "What changes when you read it tone-first?"
        ),
        MethodLesson(
            number: 5,
            title: "Conflict runs on the Moon",
            lesson: "How someone fights comes from the Moon more than the Sun — a gentle Sun with a fire Moon still needs to vent before it can repair. Map the Moons and the fight makes sense.",
            exercise: "map your last disagreement against both people's Moons, if you know them.",
            checkQuestion: "Did the fight match the Moons or the Suns?"
        ),
        MethodLesson(
            number: 6,
            title: "Timing is half the message",
            lesson: "Fixed energy decides slowly, cardinal decides fast, mutable decides in context — so a pause is usually processing, not a verdict. The right message at the wrong hour still misses.",
            exercise: "next charged reply, draft it, then wait two hours and reread before sending.",
            checkQuestion: "What changed in the second draft?"
        ),
        MethodLesson(
            number: 7,
            title: "Putting the Method together",
            lesson: "The full move: placement, then pattern, then message — read who they are, notice how that shows up, and shape one sentence to fit. That's the whole Simastry Method, and now it's yours.",
            exercise: "write one real message today using all three steps.",
            checkQuestion: "Which lens did the heavy lifting?"
        )
    ]
}

/// Device-local course progress.
nonisolated struct MethodCourseState: Codable, Equatable, Sendable {
    var postedLessons: [Int] = []
    var lastPostDay: String?

    var isComplete: Bool {
        postedLessons.count >= MethodCourseTemplates.lessons.count
    }

    /// The next lesson to post, or nil once all seven are out.
    var currentLesson: MethodLesson? {
        MethodCourseTemplates.lessons.first { !postedLessons.contains($0.number) }
    }
}
