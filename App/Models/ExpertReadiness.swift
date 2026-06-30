import Foundation

nonisolated enum AstrologyDataPoint: String, Codable, CaseIterable, Identifiable, Sendable {
    case userQuestion
    case userSunSign
    case userBirthDate
    case userBirthYear
    case userBirthMonth
    case userBirthDay
    case userBirthTime
    case userBirthPlace
    case userMoonSign
    case userRisingSign
    case userVenusSign
    case userMarsSign
    case houses
    case aspects
    case partnerChartData
    case siderealChart
    case siderealPlacements
    case vedicNakshatra
    case lagnaAscendant
    case moonRashi
    case dashaSequence
    case navamsa
    case fourPillars
    case baziDayMaster
    case elementBalance
    case tenGods
    case luckPillars
    case timeZoneBirthPlace
    case sect
    case wholeSignHouses
    case chartRuler
    case planetaryCondition
    case essentialDignity
    case lots
    case annualProfection
    case zodiacalReleasing
    case plutoPlacementAspects
    case lunarNodes
    case chiron
    case saturn
    case relationshipPatternNotes
    case reflectionPrompts
    case partnerBirthDate
    case partnerBirthTime
    case partnerBirthPlace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userQuestion: "User question"
        case .userSunSign: "Sun sign"
        case .userBirthDate: "Birth date"
        case .userBirthYear: "Birth year"
        case .userBirthMonth: "Birth month"
        case .userBirthDay: "Birth day"
        case .userBirthTime: "Birth time"
        case .userBirthPlace: "Birth place"
        case .userMoonSign: "Moon sign"
        case .userRisingSign: "Rising sign"
        case .userVenusSign: "Venus sign"
        case .userMarsSign: "Mars sign"
        case .houses: "Houses"
        case .aspects: "Aspects"
        case .partnerChartData: "Partner/person chart data"
        case .siderealChart: "Sidereal chart"
        case .siderealPlacements: "Sidereal placements"
        case .vedicNakshatra: "Vedic nakshatra"
        case .lagnaAscendant: "Lagna / Ascendant"
        case .moonRashi: "Moon sign / rashi"
        case .dashaSequence: "Dasha sequence"
        case .navamsa: "Navamsa"
        case .fourPillars: "Four Pillars"
        case .baziDayMaster: "BaZi Day Master"
        case .elementBalance: "Element balance"
        case .tenGods: "Ten Gods"
        case .luckPillars: "Luck Pillars"
        case .timeZoneBirthPlace: "Birth place / timezone"
        case .sect: "Sect"
        case .wholeSignHouses: "Whole Sign Houses"
        case .chartRuler: "Chart ruler"
        case .planetaryCondition: "Planetary condition"
        case .essentialDignity: "Essential dignity"
        case .lots: "Lots"
        case .annualProfection: "Annual profection"
        case .zodiacalReleasing: "Zodiacal Releasing"
        case .plutoPlacementAspects: "Pluto placement/aspects"
        case .lunarNodes: "Lunar Nodes"
        case .chiron: "Chiron"
        case .saturn: "Saturn"
        case .relationshipPatternNotes: "Relationship pattern notes"
        case .reflectionPrompts: "Reflection prompts"
        case .partnerBirthDate: "Partner/person birth date"
        case .partnerBirthTime: "Partner/person birth time"
        case .partnerBirthPlace: "Partner/person birth place"
        }
    }
}

nonisolated enum AstrologyDataRequirementLevel: String, Codable, Sendable {
    case requiredForBasicAnswer
    case requiredForRobustAnswer
    case useful

    var label: String {
        switch self {
        case .requiredForBasicAnswer: "Required for a basic answer"
        case .requiredForRobustAnswer: "Required for a robust answer"
        case .useful: "Would improve the reading"
        }
    }
}

nonisolated enum ExpertDataIntakeRoute: String, Codable, CaseIterable, Identifiable, Sendable {
    case birthDate
    case birthTime
    case birthPlace
    case unknownBirthTime
    case partnerBirthDate
    case partnerBirthTime
    case partnerBirthPlace
    case knownVedicNakshatra
    case knownSiderealMoonRashi
    case knownBaziDayMaster
    case knownFourPillars
    case knownHellenisticSect
    case knownProfectionYear
    case relationshipPatternNotes
    case reflectionPrompts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .birthDate: "Add birth date"
        case .birthTime: "Add birth time"
        case .birthPlace: "Add birth place"
        case .unknownBirthTime: "Mark birth time unknown"
        case .partnerBirthDate: "Add partner/person birth date"
        case .partnerBirthTime: "Add partner/person birth time"
        case .partnerBirthPlace: "Add partner/person birth place"
        case .knownVedicNakshatra: "Add known Vedic nakshatra"
        case .knownSiderealMoonRashi: "Add known sidereal Moon/rashi"
        case .knownBaziDayMaster: "Add known BaZi Day Master"
        case .knownFourPillars: "Add known Four Pillars"
        case .knownHellenisticSect: "Add known Hellenistic sect"
        case .knownProfectionYear: "Add known profection year"
        case .relationshipPatternNotes: "Add relationship pattern notes"
        case .reflectionPrompts: "Add reflection prompts"
        }
    }
}

nonisolated struct AstrologyDataRequirement: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let dataPoint: AstrologyDataPoint
    let level: AstrologyDataRequirementLevel
    let detail: String
    let intakeRoute: ExpertDataIntakeRoute?
    let isTraditionSpecific: Bool

    init(
        dataPoint: AstrologyDataPoint,
        level: AstrologyDataRequirementLevel,
        detail: String,
        intakeRoute: ExpertDataIntakeRoute? = nil,
        isTraditionSpecific: Bool = false
    ) {
        self.id = "\(dataPoint.rawValue).\(level.rawValue)"
        self.dataPoint = dataPoint
        self.level = level
        self.detail = detail
        self.intakeRoute = intakeRoute
        self.isTraditionSpecific = isTraditionSpecific
    }
}

nonisolated enum ExpertReadinessStatus: String, Codable, Sendable {
    case canAnswerNow
    case canAnswerBetterWithMoreInfo

    var title: String {
        switch self {
        case .canAnswerNow: "Ready to answer"
        case .canAnswerBetterWithMoreInfo: "Can answer better with more info"
        }
    }
}

nonisolated enum AstrologyDataSource: String, Codable, Sendable {
    case profile
    case people
    case userSupplied
    case calculated
    case notCalculated
    case missing
}

nonisolated struct AstrologyReadinessItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let dataPoint: AstrologyDataPoint
    let title: String
    let detail: String
    let source: AstrologyDataSource
    let value: String?

    init(
        dataPoint: AstrologyDataPoint,
        title: String? = nil,
        detail: String,
        source: AstrologyDataSource,
        value: String? = nil
    ) {
        self.id = dataPoint.rawValue
        self.dataPoint = dataPoint
        self.title = title ?? dataPoint.title
        self.detail = detail
        self.source = source
        self.value = value
    }
}

nonisolated struct ExpertReadinessChecklist: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let specialistId: String
    let knownItems: [AstrologyReadinessItem]
    let missingRequiredItems: [AstrologyReadinessItem]
    let missingOptionalItems: [AstrologyReadinessItem]
    let traditionRequirements: [AstrologyDataRequirement]
    let status: ExpertReadinessStatus
    let ctaLabel: String
    let ctaRoute: ExpertDataIntakeRoute?
    let privacyNote: String
    let readinessSummary: String
    let dataLimitations: [String]

    var canAnswerNow: Bool {
        status == .canAnswerNow
    }

    var knownDataPoints: [String] {
        knownItems.map { $0.title }
    }

    var missingDataPoints: [String] {
        (missingRequiredItems + missingOptionalItems).map { $0.title }
    }
}

nonisolated struct ExpertManualAstrologyData: Codable, Equatable, Sendable {
    static let defaultsKey = "simastry_expert_manual_astrology_data"

    var userDoesNotKnowBirthTime: Bool = false
    var partnerBirthDate: Date?
    var partnerBirthTime: Date?
    var partnerBirthPlace: String = ""
    var partnerDoesNotKnowBirthTime: Bool = false
    var knownVedicNakshatra: String = ""
    var knownSiderealMoonRashi: String = ""
    var knownBaziDayMaster: String = ""
    var knownFourPillars: String = ""
    var knownHellenisticSect: String = ""
    var knownProfectionYear: String = ""
    var relationshipPatternNotes: String = ""
    var reflectionPrompts: String = ""

    static func load(defaults: UserDefaults = .standard) -> ExpertManualAstrologyData {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(ExpertManualAstrologyData.self, from: data) else {
            return ExpertManualAstrologyData()
        }
        return decoded
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }

    var userSuppliedTraditionData: [String: String] {
        var values: [String: String] = [:]
        Self.add(&values, key: "knownVedicNakshatra", value: knownVedicNakshatra)
        Self.add(&values, key: "knownSiderealMoonRashi", value: knownSiderealMoonRashi)
        Self.add(&values, key: "knownBaziDayMaster", value: knownBaziDayMaster)
        Self.add(&values, key: "knownFourPillars", value: knownFourPillars)
        Self.add(&values, key: "knownHellenisticSect", value: knownHellenisticSect)
        Self.add(&values, key: "knownProfectionYear", value: knownProfectionYear)
        Self.add(&values, key: "relationshipPatternNotes", value: relationshipPatternNotes)
        Self.add(&values, key: "reflectionPrompts", value: reflectionPrompts)
        if userDoesNotKnowBirthTime {
            values["userBirthTimeStatus"] = "User says they do not know their birth time."
        }
        if partnerDoesNotKnowBirthTime {
            values["partnerBirthTimeStatus"] = "User says they do not know the partner/person birth time."
        }
        if partnerBirthDateAvailable {
            values["partnerBirthDate"] = "User supplied partner/person birth date availability."
        }
        if partnerBirthTimeAvailable {
            values["partnerBirthTime"] = "User supplied partner/person birth time availability."
        }
        if partnerBirthPlaceAvailable {
            values["partnerBirthPlace"] = "User supplied partner/person birth place availability."
        }
        return values
    }

    /// Manual tradition fields keyed by the backend intake whitelist
    /// (`public.expert_astrology_intake.user_supplied_tradition_data`). Only
    /// user-typed values are included — never app-calculated placements — and
    /// only non-empty entries are sent.
    var intakeTraditionData: [String: String] {
        var values: [String: String] = [:]
        Self.add(&values, key: "vedic.nakshatra", value: knownVedicNakshatra)
        Self.add(&values, key: "vedic.siderealMoonRashi", value: knownSiderealMoonRashi)
        Self.add(&values, key: "bazi.dayMaster", value: knownBaziDayMaster)
        Self.add(&values, key: "bazi.fourPillars", value: knownFourPillars)
        Self.add(&values, key: "hellenistic.sect", value: knownHellenisticSect)
        Self.add(&values, key: "hellenistic.profectionYear", value: knownProfectionYear)
        Self.add(&values, key: "evolutionary.relationshipPatternNotes", value: relationshipPatternNotes)
        Self.add(&values, key: "evolutionary.reflectionPrompts", value: reflectionPrompts)
        return values
    }

    /// Applies whitelisted intake tradition data (dotted keys) onto the manual
    /// fields, only filling fields that are currently empty so unsynced local
    /// edits are never clobbered on reload.
    mutating func applyIntakeTraditionData(_ data: [String: String]) {
        func fill(_ keyPath: WritableKeyPath<ExpertManualAstrologyData, String>, _ key: String) {
            guard self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if let value = data[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                self[keyPath: keyPath] = value
            }
        }
        fill(\.knownVedicNakshatra, "vedic.nakshatra")
        fill(\.knownSiderealMoonRashi, "vedic.siderealMoonRashi")
        fill(\.knownBaziDayMaster, "bazi.dayMaster")
        fill(\.knownFourPillars, "bazi.fourPillars")
        fill(\.knownHellenisticSect, "hellenistic.sect")
        fill(\.knownProfectionYear, "hellenistic.profectionYear")
        fill(\.relationshipPatternNotes, "evolutionary.relationshipPatternNotes")
        fill(\.reflectionPrompts, "evolutionary.reflectionPrompts")
    }

    var partnerBirthDateAvailable: Bool {
        partnerBirthDate != nil
    }

    var partnerBirthTimeAvailable: Bool {
        partnerBirthTime != nil
    }

    var partnerBirthPlaceAvailable: Bool {
        !partnerBirthPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func add(_ values: inout [String: String], key: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            values[key] = trimmed
        }
    }
}

extension ExpertManualAstrologyData {
    /// Tolerant decoder: any missing key falls back to its default. Adding a
    /// field must never reset a user's already-persisted intake on upgrade.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        userDoesNotKnowBirthTime = try container.decodeIfPresent(Bool.self, forKey: .userDoesNotKnowBirthTime) ?? userDoesNotKnowBirthTime
        partnerBirthDate = try container.decodeIfPresent(Date.self, forKey: .partnerBirthDate)
        partnerBirthTime = try container.decodeIfPresent(Date.self, forKey: .partnerBirthTime)
        partnerBirthPlace = try container.decodeIfPresent(String.self, forKey: .partnerBirthPlace) ?? partnerBirthPlace
        partnerDoesNotKnowBirthTime = try container.decodeIfPresent(Bool.self, forKey: .partnerDoesNotKnowBirthTime) ?? partnerDoesNotKnowBirthTime
        knownVedicNakshatra = try container.decodeIfPresent(String.self, forKey: .knownVedicNakshatra) ?? knownVedicNakshatra
        knownSiderealMoonRashi = try container.decodeIfPresent(String.self, forKey: .knownSiderealMoonRashi) ?? knownSiderealMoonRashi
        knownBaziDayMaster = try container.decodeIfPresent(String.self, forKey: .knownBaziDayMaster) ?? knownBaziDayMaster
        knownFourPillars = try container.decodeIfPresent(String.self, forKey: .knownFourPillars) ?? knownFourPillars
        knownHellenisticSect = try container.decodeIfPresent(String.self, forKey: .knownHellenisticSect) ?? knownHellenisticSect
        knownProfectionYear = try container.decodeIfPresent(String.self, forKey: .knownProfectionYear) ?? knownProfectionYear
        relationshipPatternNotes = try container.decodeIfPresent(String.self, forKey: .relationshipPatternNotes) ?? relationshipPatternNotes
        reflectionPrompts = try container.decodeIfPresent(String.self, forKey: .reflectionPrompts) ?? reflectionPrompts
    }
}

nonisolated enum ExpertReadinessBuilder {
    static func checklist(
        for specialist: AstrologySpecialist,
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData
    ) -> ExpertReadinessChecklist {
        switch specialist.id {
        case "leyla-western":
            leyla(question: question, context: context, manualData: manualData, specialistId: specialist.id)
        case "mateo-vedic":
            mateo(question: question, context: context, manualData: manualData, specialistId: specialist.id)
        case "naomi-chinese":
            naomi(question: question, context: context, manualData: manualData, specialistId: specialist.id)
        case "elias-ancient":
            soren(question: question, context: context, manualData: manualData, specialistId: specialist.id)
        case "nadia-evolutionary":
            nadia(question: question, context: context, manualData: manualData, specialistId: specialist.id)
        default:
            generic(question: question, context: context, specialistId: specialist.id)
        }
    }

    private static func leyla(
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        var optional: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        appendKnownIfAvailable(context.sunSign, point: .userSunSign, detail: "Tropical Sun sign is available.", known: &known)
        if context.birthDateAvailable {
            known.append(.init(dataPoint: .userBirthDate, detail: "Birth date is available.", source: .profile))
        }
        if context.sunSign == nil && !context.birthDateAvailable {
            required.append(.init(dataPoint: .userBirthDate, detail: "Leyla needs at least a Sun sign or birth date for a specific Western reading.", source: .missing))
        }
        appendSharedWesternOptional(context: context, manualData: manualData, optional: &optional, known: &known)
        let hasRequired = !questionIsMissing(question) && (context.sunSign != nil || context.birthDateAvailable)
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: optional,
            requirements: [
                .init(dataPoint: .userQuestion, level: .requiredForBasicAnswer, detail: "The live question anchors the interpretation."),
                .init(dataPoint: .userSunSign, level: .requiredForBasicAnswer, detail: "At least Sun sign or birth date keeps the answer personal.", intakeRoute: .birthDate),
                .init(dataPoint: .userBirthTime, level: .useful, detail: "Birth time helps with Rising, chart ruler, and houses.", intakeRoute: .birthTime),
                .init(dataPoint: .partnerChartData, level: .useful, detail: "Partner/person data improves compatibility work.", intakeRoute: .partnerBirthDate)
            ],
            status: hasRequired ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add Western chart details"
        )
    }

    private static func mateo(
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        var optional: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        appendAvailable(context.birthDateAvailable, point: .userBirthDate, detail: "Birth date is available.", route: .birthDate, known: &known, missing: &required)
        appendAvailable(context.birthTimeAvailable, point: .userBirthTime, detail: manualData.userDoesNotKnowBirthTime ? "Birth time is marked unknown by the user." : "Exact birth time is available.", route: .birthTime, known: &known, missing: &required)
        appendAvailable(context.birthPlaceAvailable, point: .userBirthPlace, detail: "Birth place is available.", route: .birthPlace, known: &known, missing: &required)
        appendManual(manualData.knownSiderealMoonRashi, point: .siderealPlacements, route: .knownSiderealMoonRashi, known: &known, missing: &required, missingDetail: "Mateo needs a calculated sidereal chart or user-supplied sidereal placements for a robust Jyotish answer.")
        appendManual(manualData.knownVedicNakshatra, point: .vedicNakshatra, route: .knownVedicNakshatra, known: &known, missing: &optional, missingDetail: "Nakshatra is not calculated or supplied.")
        optional.append(.init(dataPoint: .lagnaAscendant, detail: "Lagna is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .dashaSequence, detail: "Dasha sequence is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .navamsa, detail: "Navamsa is not calculated or supplied.", source: .notCalculated))
        appendPartnerOptional(context: context, manualData: manualData, optional: &optional, known: &known)
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: optional,
            requirements: [
                .init(dataPoint: .userBirthDate, level: .requiredForRobustAnswer, detail: "Jyotish needs date, time, and place for robust chart work.", intakeRoute: .birthDate, isTraditionSpecific: true),
                .init(dataPoint: .userBirthTime, level: .requiredForRobustAnswer, detail: "Exact birth time supports lagna, houses, and timing.", intakeRoute: .birthTime, isTraditionSpecific: true),
                .init(dataPoint: .userBirthPlace, level: .requiredForRobustAnswer, detail: "Birth place supports chart calculation boundaries.", intakeRoute: .birthPlace, isTraditionSpecific: true),
                .init(dataPoint: .siderealPlacements, level: .requiredForRobustAnswer, detail: "Sidereal placements must be calculated or supplied.", intakeRoute: .knownSiderealMoonRashi, isTraditionSpecific: true)
            ],
            status: required.isEmpty ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add Jyotish details"
        )
    }

    private static func naomi(
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        var optional: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        if context.birthDateAvailable {
            known.append(.init(dataPoint: .userBirthYear, detail: "Birth year is available through saved birth date.", source: .profile))
            known.append(.init(dataPoint: .userBirthMonth, detail: "Birth month is available through saved birth date.", source: .profile))
            known.append(.init(dataPoint: .userBirthDay, detail: "Birth day is available through saved birth date.", source: .profile))
        } else {
            required.append(.init(dataPoint: .userBirthYear, detail: "Naomi needs birth year for BaZi/Four Pillars context.", source: .missing))
            required.append(.init(dataPoint: .userBirthMonth, detail: "Naomi needs birth month for BaZi/Four Pillars context.", source: .missing))
            required.append(.init(dataPoint: .userBirthDay, detail: "Naomi needs birth day for BaZi/Four Pillars context.", source: .missing))
        }
        appendAvailable(context.birthPlaceAvailable, point: .timeZoneBirthPlace, detail: "Birth place/timezone context is available.", route: .birthPlace, known: &known, missing: &optional)
        appendAvailable(context.birthTimeAvailable, point: .userBirthTime, detail: manualData.userDoesNotKnowBirthTime ? "Birth hour is marked unknown by the user." : "Birth hour is available.", route: .birthTime, known: &known, missing: &optional)
        appendManual(manualData.knownFourPillars, point: .fourPillars, route: .knownFourPillars, known: &known, missing: &optional, missingDetail: "Four Pillars are not calculated or supplied.")
        appendManual(manualData.knownBaziDayMaster, point: .baziDayMaster, route: .knownBaziDayMaster, known: &known, missing: &optional, missingDetail: "Day Master is not calculated or supplied.")
        optional.append(.init(dataPoint: .elementBalance, detail: "Element balance is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .tenGods, detail: "Ten Gods are not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .luckPillars, detail: "Luck Pillars are not calculated or supplied.", source: .notCalculated))
        appendPartnerOptional(context: context, manualData: manualData, optional: &optional, known: &known)
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: optional,
            requirements: [
                .init(dataPoint: .userBirthYear, level: .requiredForRobustAnswer, detail: "BaZi starts with year, month, day, and hour where available.", intakeRoute: .birthDate, isTraditionSpecific: true),
                .init(dataPoint: .timeZoneBirthPlace, level: .useful, detail: "Place/timezone helps keep exact conversion honest.", intakeRoute: .birthPlace, isTraditionSpecific: true),
                .init(dataPoint: .fourPillars, level: .useful, detail: "Four Pillars must be calculated or supplied before Naomi interprets them.", intakeRoute: .knownFourPillars, isTraditionSpecific: true),
                .init(dataPoint: .baziDayMaster, level: .useful, detail: "Day Master must be supplied or calculated before Naomi uses it.", intakeRoute: .knownBaziDayMaster, isTraditionSpecific: true)
            ],
            status: required.isEmpty ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add BaZi details"
        )
    }

    private static func soren(
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        var optional: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        appendAvailable(context.birthDateAvailable, point: .userBirthDate, detail: "Birth date is available.", route: .birthDate, known: &known, missing: &required)
        appendAvailable(context.birthTimeAvailable, point: .userBirthTime, detail: manualData.userDoesNotKnowBirthTime ? "Birth time is marked unknown by the user." : "Exact birth time is available.", route: .birthTime, known: &known, missing: &required)
        appendAvailable(context.birthPlaceAvailable, point: .userBirthPlace, detail: "Birth place is available.", route: .birthPlace, known: &known, missing: &required)
        appendManual(manualData.knownHellenisticSect, point: .sect, route: .knownHellenisticSect, known: &known, missing: &optional, missingDetail: "Sect is not calculated or supplied.")
        appendManual(manualData.knownProfectionYear, point: .annualProfection, route: .knownProfectionYear, known: &known, missing: &optional, missingDetail: "Annual profection year is not calculated or supplied.")
        optional.append(.init(dataPoint: .wholeSignHouses, detail: "Whole Sign Houses are not calculated in this pass.", source: .notCalculated))
        optional.append(.init(dataPoint: .chartRuler, detail: "Chart ruler is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .planetaryCondition, detail: "Planetary condition is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .essentialDignity, detail: "Essential dignity is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .lots, detail: "Lots are not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .zodiacalReleasing, detail: "Zodiacal Releasing periods are not calculated or supplied.", source: .notCalculated))
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: optional,
            requirements: [
                .init(dataPoint: .userBirthDate, level: .requiredForRobustAnswer, detail: "Traditional chart judgment needs date, exact time, and place.", intakeRoute: .birthDate, isTraditionSpecific: true),
                .init(dataPoint: .userBirthTime, level: .requiredForRobustAnswer, detail: "Sect and houses need exact birth time.", intakeRoute: .birthTime, isTraditionSpecific: true),
                .init(dataPoint: .userBirthPlace, level: .requiredForRobustAnswer, detail: "Birth place keeps house and angle work honest.", intakeRoute: .birthPlace, isTraditionSpecific: true),
                .init(dataPoint: .sect, level: .useful, detail: "Sect must be calculated or supplied before Soren uses it.", intakeRoute: .knownHellenisticSect, isTraditionSpecific: true)
            ],
            status: required.isEmpty ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add Hellenistic details"
        )
    }

    private static func nadia(
        question: String?,
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        var optional: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        appendKnownIfAvailable(context.sunSign, point: .userSunSign, detail: "Sun sign is available.", known: &known)
        if context.birthDateAvailable {
            known.append(.init(dataPoint: .userBirthDate, detail: "Birth date is available.", source: .profile))
        }
        if context.sunSign == nil && !context.birthDateAvailable {
            required.append(.init(dataPoint: .userBirthDate, detail: "Nadia needs a birth date or at least a Sun sign for useful symbolic reflection.", source: .missing))
        }
        appendKnownOrMissing(context.moonSign, point: .userMoonSign, detail: "Moon sign is available.", known: &known, missing: &optional)
        appendKnownOrMissing(context.risingSign, point: .userRisingSign, detail: "Rising sign is available.", known: &known, missing: &optional)
        optional.append(.init(dataPoint: .plutoPlacementAspects, detail: "Pluto placement/aspects are not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .lunarNodes, detail: "Lunar Nodes are not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .chiron, detail: "Chiron is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .saturn, detail: "Saturn placement is not calculated or supplied.", source: .notCalculated))
        appendManual(manualData.relationshipPatternNotes, point: .relationshipPatternNotes, route: .relationshipPatternNotes, known: &known, missing: &optional, missingDetail: "Relationship pattern notes would help Nadia stay specific.")
        appendManual(manualData.reflectionPrompts, point: .reflectionPrompts, route: .reflectionPrompts, known: &known, missing: &optional, missingDetail: "User-provided reflections would improve the guidance.")
        let hasRequired = !questionIsMissing(question) && (context.sunSign != nil || context.birthDateAvailable)
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: optional,
            requirements: [
                .init(dataPoint: .userQuestion, level: .requiredForBasicAnswer, detail: "Nadia needs the lived question, not just chart symbolism."),
                .init(dataPoint: .userSunSign, level: .requiredForBasicAnswer, detail: "Birth date or Sun sign keeps the reflection personal.", intakeRoute: .birthDate),
                .init(dataPoint: .relationshipPatternNotes, level: .useful, detail: "Pattern notes reduce generic growth advice.", intakeRoute: .relationshipPatternNotes)
            ],
            status: hasRequired ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add growth context"
        )
    }

    private static func generic(
        question: String?,
        context: UserAstrologyContext,
        specialistId: String
    ) -> ExpertReadinessChecklist {
        var known: [AstrologyReadinessItem] = []
        var required: [AstrologyReadinessItem] = []
        appendQuestion(question, known: &known, missing: &required)
        if context.birthDateAvailable {
            known.append(.init(dataPoint: .userBirthDate, detail: "Birth date is available.", source: .profile))
        }
        return makeChecklist(
            specialistId: specialistId,
            known: known,
            required: required,
            optional: [],
            requirements: [],
            status: required.isEmpty ? .canAnswerNow : .canAnswerBetterWithMoreInfo,
            fallbackCTA: "Add missing details"
        )
    }

    private static func appendQuestion(_ question: String?, known: inout [AstrologyReadinessItem], missing: inout [AstrologyReadinessItem]) {
        if questionIsMissing(question) {
            missing.append(.init(dataPoint: .userQuestion, detail: "A clear question helps the expert stay specific.", source: .missing))
        } else {
            known.append(.init(dataPoint: .userQuestion, detail: "Question is ready for this consultation.", source: .userSupplied))
        }
    }

    private static func appendAvailable(
        _ available: Bool,
        point: AstrologyDataPoint,
        detail: String,
        route: ExpertDataIntakeRoute,
        known: inout [AstrologyReadinessItem],
        missing: inout [AstrologyReadinessItem]
    ) {
        if available {
            known.append(.init(dataPoint: point, detail: detail, source: .profile))
        } else {
            missing.append(.init(dataPoint: point, detail: "\(point.title) is missing.", source: .missing))
        }
    }

    private static func appendKnownIfAvailable(
        _ value: String?,
        point: AstrologyDataPoint,
        detail: String,
        known: inout [AstrologyReadinessItem]
    ) {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            known.append(.init(dataPoint: point, detail: detail, source: .profile, value: value))
        }
    }

    private static func appendKnownOrMissing(
        _ value: String?,
        point: AstrologyDataPoint,
        detail: String,
        known: inout [AstrologyReadinessItem],
        missing: inout [AstrologyReadinessItem]
    ) {
        if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            known.append(.init(dataPoint: point, detail: detail, source: .profile, value: value))
        } else {
            missing.append(.init(dataPoint: point, detail: "\(point.title) is missing or not calculated.", source: .missing))
        }
    }

    private static func appendManual(
        _ value: String,
        point: AstrologyDataPoint,
        route: ExpertDataIntakeRoute,
        known: inout [AstrologyReadinessItem],
        missing: inout [AstrologyReadinessItem],
        missingDetail: String
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            missing.append(.init(dataPoint: point, detail: missingDetail, source: .notCalculated))
        } else {
            known.append(.init(dataPoint: point, detail: "\(point.title) is user-supplied, not app-calculated.", source: .userSupplied, value: trimmed))
        }
    }

    private static func appendSharedWesternOptional(
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        optional: inout [AstrologyReadinessItem],
        known: inout [AstrologyReadinessItem]
    ) {
        appendAvailable(context.birthTimeAvailable, point: .userBirthTime, detail: manualData.userDoesNotKnowBirthTime ? "Birth time is marked unknown by the user." : "Birth time is available.", route: .birthTime, known: &known, missing: &optional)
        appendAvailable(context.birthPlaceAvailable, point: .userBirthPlace, detail: "Birth place is available.", route: .birthPlace, known: &known, missing: &optional)
        appendKnownOrMissing(context.moonSign, point: .userMoonSign, detail: "Moon sign is available.", known: &known, missing: &optional)
        appendKnownOrMissing(context.risingSign, point: .userRisingSign, detail: "Rising sign is available.", known: &known, missing: &optional)
        optional.append(.init(dataPoint: .userVenusSign, detail: "Venus sign is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .userMarsSign, detail: "Mars sign is not calculated or supplied.", source: .notCalculated))
        optional.append(.init(dataPoint: .houses, detail: "Houses are not calculated in this pass.", source: .notCalculated))
        optional.append(.init(dataPoint: .aspects, detail: "Aspects are not calculated in this pass.", source: .notCalculated))
        appendPartnerOptional(context: context, manualData: manualData, optional: &optional, known: &known)
    }

    private static func appendPartnerOptional(
        context: UserAstrologyContext,
        manualData: ExpertManualAstrologyData,
        optional: inout [AstrologyReadinessItem],
        known: inout [AstrologyReadinessItem]
    ) {
        if context.partnerBirthDateAvailable || context.partnerSunSign != nil || manualData.partnerBirthDateAvailable {
            known.append(.init(dataPoint: .partnerBirthDate, detail: "Partner/person birth context is available or user-supplied.", source: context.partnerBirthDateAvailable ? .people : .userSupplied))
        } else {
            optional.append(.init(dataPoint: .partnerBirthDate, detail: "Partner/person birth date would improve compatibility work.", source: .missing))
        }
        if context.partnerBirthTimeAvailable || manualData.partnerBirthTimeAvailable {
            known.append(.init(dataPoint: .partnerBirthTime, detail: "Partner/person birth time is available or user-supplied.", source: context.partnerBirthTimeAvailable ? .people : .userSupplied))
        } else {
            optional.append(.init(dataPoint: .partnerBirthTime, detail: "Partner/person birth time would improve compatibility work.", source: .missing))
        }
        if context.partnerBirthPlaceAvailable || manualData.partnerBirthPlaceAvailable {
            known.append(.init(dataPoint: .partnerBirthPlace, detail: "Partner/person birth place is available or user-supplied.", source: context.partnerBirthPlaceAvailable ? .people : .userSupplied))
        } else {
            optional.append(.init(dataPoint: .partnerBirthPlace, detail: "Partner/person birth place would improve compatibility work.", source: .missing))
        }
    }

    private static func makeChecklist(
        specialistId: String,
        known: [AstrologyReadinessItem],
        required: [AstrologyReadinessItem],
        optional: [AstrologyReadinessItem],
        requirements: [AstrologyDataRequirement],
        status: ExpertReadinessStatus,
        fallbackCTA: String
    ) -> ExpertReadinessChecklist {
        let firstRoute = (required + optional)
            .compactMap { route(for: $0.dataPoint) }
            .first
        let limitations = (required + optional)
            .filter { $0.source == .missing || $0.source == .notCalculated }
            .map { "\($0.title): \($0.detail)" }
        let summary = status == .canAnswerNow
            ? "Can answer now with \(known.count) known item\(known.count == 1 ? "" : "s"); \(optional.count) item\(optional.count == 1 ? "" : "s") could improve precision."
            : "Can keep the answer general, but \(required.count) required item\(required.count == 1 ? "" : "s") are missing for a stronger specialist read."
        return ExpertReadinessChecklist(
            id: specialistId,
            specialistId: specialistId,
            knownItems: known,
            missingRequiredItems: required,
            missingOptionalItems: optional,
            traditionRequirements: requirements,
            status: status,
            ctaLabel: firstRoute?.label ?? fallbackCTA,
            ctaRoute: firstRoute,
            privacyNote: "Only availability and clearly labeled user-supplied fields are sent to the AI. Missing or uncalculated data stays marked as unavailable.",
            readinessSummary: summary,
            dataLimitations: limitations
        )
    }

    private static func route(for point: AstrologyDataPoint) -> ExpertDataIntakeRoute? {
        switch point {
        case .userBirthDate, .userBirthYear, .userBirthMonth, .userBirthDay: .birthDate
        case .userBirthTime: .birthTime
        case .userBirthPlace, .timeZoneBirthPlace: .birthPlace
        case .partnerBirthDate, .partnerChartData: .partnerBirthDate
        case .partnerBirthTime: .partnerBirthTime
        case .partnerBirthPlace: .partnerBirthPlace
        case .vedicNakshatra: .knownVedicNakshatra
        case .siderealPlacements, .moonRashi: .knownSiderealMoonRashi
        case .fourPillars: .knownFourPillars
        case .baziDayMaster: .knownBaziDayMaster
        case .sect: .knownHellenisticSect
        case .annualProfection: .knownProfectionYear
        case .relationshipPatternNotes: .relationshipPatternNotes
        case .reflectionPrompts: .reflectionPrompts
        default: nil
        }
    }

    private static func questionIsMissing(_ question: String?) -> Bool {
        question?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}

extension AstrologySpecialist {
    var expertBio: String {
        switch id {
        case "leyla-western":
            "Leyla reads modern tropical astrology with a relationship-aware lens: identity, attraction, emotional needs, compatibility, and symbolic timing."
        case "mateo-vedic":
            "Mateo works through Jyotish, using karma, dharma, grahas, rashis, nakshatras, and timing only where the required data is actually available."
        case "naomi-chinese":
            "Naomi focuses on BaZi and Five Elements: practical strategy, compatibility, career rhythm, family patterns, and energetic balance."
        case "elias-ancient":
            "Soren uses Hellenistic and traditional techniques for clear classical judgment, timing boundaries, planetary condition, and life chapters."
        case "nadia-evolutionary":
            "Nadia reads the chart as a reflective growth map, translating emotional patterns into practical self-awareness without diagnosing."
        default:
            longDescription
        }
    }

    var bestForChips: [String] {
        switch id {
        case "leyla-western": ["Love", "Identity", "Compatibility", "Life direction"]
        case "mateo-vedic": ["Karma", "Dharma", "Timing", "Spiritual patterns"]
        case "naomi-chinese": ["Five Elements", "Strategy", "Compatibility", "Career timing"]
        case "elias-ancient": ["Classical timing", "Fate", "Life chapters", "Traditional judgment"]
        case "nadia-evolutionary": ["Growth", "Patterns", "Shadow work", "Self-worth"]
        default: focusAreas
        }
    }

    var sampleQuestions: [String] {
        switch id {
        case "leyla-western":
            ["What relationship pattern am I repeating?", "What does my chart say about attraction?", "How should I approach this timing?"]
        case "mateo-vedic":
            ["What dharma lesson is active here?", "How should I frame this karmic relationship?", "What can Jyotish say without dasha data?"]
        case "naomi-chinese":
            ["What practical strategy fits my energy?", "What BaZi data would improve this compatibility read?", "How should I think about timing without Four Pillars?"]
        case "elias-ancient":
            ["What would a traditional astrologer check first?", "What can be judged without sect?", "How should I think about this life chapter?"]
        case "nadia-evolutionary":
            ["What growth pattern is this inviting?", "How can I respond without repeating the old story?", "What reflection would help me move differently?"]
        default:
            ["What should I understand first?", "What data would make this more precise?"]
        }
    }

    var safetyNote: String {
        "Astrology here is symbolic and reflective, not deterministic. This expert will not diagnose, predict harm, or invent chart data that Simastry has not calculated or you have not supplied."
    }
}

nonisolated enum ExpertProgressStepProvider {
    static func steps(
        for specialist: AstrologySpecialist,
        checklist: ExpertReadinessChecklist
    ) -> [String] {
        let missingBirthTime = checklist.missingDataPoints.contains(AstrologyDataPoint.userBirthTime.title)
        let missingBirthPlace = checklist.missingDataPoints.contains(AstrologyDataPoint.userBirthPlace.title)
            || checklist.missingDataPoints.contains(AstrologyDataPoint.timeZoneBirthPlace.title)

        switch specialist.id {
        case "leyla-western":
            return [
                missingBirthTime ? "Checking the Western context available without birth time..." : "Checking your tropical Sun, Moon, and Rising context...",
                missingBirthPlace ? "Keeping houses and chart angles general because birth place is missing..." : "Looking for relationship and timing themes...",
                "Keeping the reading symbolic, not deterministic..."
            ]
        case "mateo-vedic":
            return [
                missingBirthTime || missingBirthPlace ? "Birth time or place is not available, so Jyotish timing stays general..." : "Checking the birth context needed for a Jyotish lens...",
                "Preparing a Jyotish frame without inventing dashas...",
                "Framing the answer through karma, dharma, and timing boundaries..."
            ]
        case "naomi-chinese":
            return [
                checklist.knownDataPoints.contains(AstrologyDataPoint.fourPillars.title) ? "Checking your user-supplied Four Pillars context..." : "Checking what BaZi/Four Pillars data is available...",
                "Looking at Five Element balance only where data allows...",
                "Keeping the guidance practical and non-Western..."
            ]
        case "elias-ancient":
            return [
                missingBirthTime ? "Birth time is not available, so sect and houses stay general..." : "Checking whether sect and house data are available...",
                "Using traditional planets and classical timing boundaries...",
                "Avoiding modern placements as Soren's primary method..."
            ]
        case "nadia-evolutionary":
            return [
                "Looking for growth patterns, not fixed labels...",
                "Checking emotional themes without diagnosing...",
                "Turning the chart into a practical reflection..."
            ]
        default:
            return [
                "Checking the available context...",
                "Respecting missing or uncalculated data...",
                "Preparing a grounded response..."
            ]
        }
    }

    static func everyoneSteps() -> [(String, String)] {
        [
            ("leyla-western", "Asking Leyla for the Western lens..."),
            ("mateo-vedic", "Asking Mateo for the Jyotish lens..."),
            ("naomi-chinese", "Asking Naomi for the BaZi/Five Elements lens..."),
            ("elias-ancient", "Asking Soren for the ancient lens..."),
            ("nadia-evolutionary", "Asking Nadia for the evolutionary lens...")
        ]
    }
}
