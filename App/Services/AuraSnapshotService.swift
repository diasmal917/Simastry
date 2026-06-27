import Foundation
import UIKit

nonisolated final class AuraSnapshotService {
    static let privacyNotice = "This is reflective guidance for entertainment and self-check-in, not identity, health, or life certainty analysis."

    func makeSnapshot(
        from image: UIImage,
        mood: AuraSnapshotMood,
        userSunSign: ZodiacSign?,
        userMoonSign: ZodiacSign?,
        userRisingSign: ZodiacSign?,
        date: Date = Date()
    ) -> AuraSnapshot? {
        guard let descriptor = descriptor(from: image, mood: mood, date: date) else {
            return nil
        }
        return AuraSnapshot(
            descriptor: descriptor,
            result: result(
                for: descriptor,
                userSunSign: userSunSign,
                userMoonSign: userMoonSign,
                userRisingSign: userRisingSign
            )
        )
    }

    func descriptor(from image: UIImage, mood: AuraSnapshotMood, date: Date = Date()) -> AuraSnapshotDescriptor? {
        guard let sample = Self.pixelSample(from: image) else { return nil }
        let color = Self.colorName(red: sample.averageRed, green: sample.averageGreen, blue: sample.averageBlue)
        let warmth = Self.warmth(red: sample.averageRed, blue: sample.averageBlue)
        let brightness = Self.brightness(sample.averageLuminance)
        let contrast = Self.contrast(sample.luminanceStandardDeviation)
        return AuraSnapshotDescriptor(
            auraColor: color,
            imageWarmth: warmth,
            brightness: brightness,
            contrast: contrast,
            selectedMood: mood,
            createdAt: date
        )
    }

    func result(
        for descriptor: AuraSnapshotDescriptor,
        userSunSign: ZodiacSign?,
        userMoonSign: ZodiacSign?,
        userRisingSign: ZodiacSign?
    ) -> AuraSnapshotResult {
        let chartAnchor = chartAnchor(sun: userSunSign, moon: userMoonSign, rising: userRisingSign)
        let moodLine = moodGuidance(descriptor.selectedMood)
        let colorLine = "\(descriptor.auraColor) \(descriptor.imageWarmth.rawValue) light"

        return AuraSnapshotResult(
            todayVibe: "\(descriptor.selectedMood.title) \(descriptor.auraColor.capitalized). \(chartAnchor) Today's palette reads as \(colorLine), with \(descriptor.brightness.rawValue) brightness and \(descriptor.contrast.rawValue) contrast.",
            bestMove: moodLine.bestMove,
            wearEatFocus: wearEatFocus(for: descriptor),
            textingHint: moodLine.textingHint,
            predictionTuningNote: "Tune today's predictions toward \(descriptor.selectedMood.promptValue) pacing, \(descriptor.imageWarmth.rawValue) color, and \(descriptor.brightness.rawValue) visibility."
        )
    }

    static func sensitiveRedirect(for text: String) -> String? {
        let lowered = text.lowercased()
        let blockedTerms = [
            "face", "facial", "recognition", "biometric", "identity", "identify",
            "attractive", "attractiveness", "pretty", "ugly",
            "age", "older", "younger", "ethnicity", "race",
            "gender", "fertility", "pregnant", "health", "sick", "diagnose",
            "depressed", "depression", "anxiety", "mental state"
        ]
        guard blockedTerms.contains(where: lowered.contains) else { return nil }
        return "Aura Snapshot only uses color, light, contrast, and the mood you choose. Try it as a palette check-in, not identity, health, attractiveness, age, or trait analysis."
    }

    private struct PixelSample {
        let averageRed: Double
        let averageGreen: Double
        let averageBlue: Double
        let averageLuminance: Double
        let luminanceStandardDeviation: Double
    }

    private static func pixelSample(from image: UIImage) -> PixelSample? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 32
        let height = 32
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var redTotal = 0.0
        var greenTotal = 0.0
        var blueTotal = 0.0
        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[offset]) / 255.0
            let green = Double(pixels[offset + 1]) / 255.0
            let blue = Double(pixels[offset + 2]) / 255.0
            let alpha = Double(pixels[offset + 3]) / 255.0
            guard alpha > 0.05 else { continue }
            redTotal += red
            greenTotal += green
            blueTotal += blue
            luminances.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)
        }

        guard !luminances.isEmpty else { return nil }
        let count = Double(luminances.count)
        let averageLuminance = luminances.reduce(0, +) / count
        let variance = luminances
            .map { pow($0 - averageLuminance, 2) }
            .reduce(0, +) / count

        return PixelSample(
            averageRed: redTotal / count,
            averageGreen: greenTotal / count,
            averageBlue: blueTotal / count,
            averageLuminance: averageLuminance,
            luminanceStandardDeviation: sqrt(variance)
        )
    }

    private static func warmth(red: Double, blue: Double) -> AuraImageWarmth {
        let delta = red - blue
        if delta > 0.08 { return .warm }
        if delta < -0.08 { return .cool }
        return .neutral
    }

    private static func brightness(_ luminance: Double) -> AuraBrightness {
        if luminance < 0.34 { return .dim }
        if luminance > 0.68 { return .luminous }
        return .balanced
    }

    private static func contrast(_ standardDeviation: Double) -> AuraContrast {
        if standardDeviation < 0.12 { return .soft }
        if standardDeviation > 0.26 { return .crisp }
        return .balanced
    }

    private static func colorName(red: Double, green: Double, blue: Double) -> String {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let chroma = maxValue - minValue
        guard chroma > 0.08 else { return "silver" }

        let hue: Double
        if maxValue == red {
            hue = 60 * ((green - blue) / chroma).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = 60 * (((blue - red) / chroma) + 2)
        } else {
            hue = 60 * (((red - green) / chroma) + 4)
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue

        switch normalizedHue {
        case 0..<18, 335...360:
            return "rose"
        case 18..<48:
            return "gold"
        case 48..<78:
            return "amber"
        case 78..<168:
            return "green"
        case 168..<205:
            return "teal"
        case 205..<255:
            return "blue"
        case 255..<305:
            return "violet"
        default:
            return "magenta"
        }
    }

    private func chartAnchor(sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) -> String {
        if let moon {
            return "Your \(moon.displayName) Moon gets the first vote."
        }
        if let rising {
            return "Your \(rising.displayName) Rising sets the room tone."
        }
        if let sun {
            return "Your \(sun.displayName) Sun anchors the read."
        }
        return "Your chart can sharpen this once your signs are added."
    }

    private func moodGuidance(_ mood: AuraSnapshotMood) -> (bestMove: String, textingHint: String) {
        switch mood {
        case .tender:
            return ("Choose the softer true thing and leave room for a reply.", "If you're texting them, lead warm and skip the test.")
        case .bold:
            return ("Make the move that would still feel clean tomorrow.", "If you're texting them, be clear enough that they do not have to decode you.")
        case .restless:
            return ("Do one grounding action before making the bigger choice.", "If you're texting them, wait one beat and send the shorter version.")
        case .focused:
            return ("Pick the next step with the least emotional noise.", "If you're texting them, ask one direct question.")
        case .romantic:
            return ("Let the warmth show without turning it into a performance.", "If you're texting them, make it sweet and specific.")
        case .overthinking:
            return ("Name the real question, then stop reopening it.", "If you're texting them, send one sentence or do not send yet.")
        }
    }

    private func wearEatFocus(for descriptor: AuraSnapshotDescriptor) -> String {
        switch (descriptor.selectedMood, descriptor.brightness) {
        case (.bold, _):
            return "Wear one strong accent, take a brisk reset, and focus on the move you keep postponing."
        case (.romantic, _):
            return "Wear something soft, give yourself a slow reset, and focus on honest affection."
        case (.restless, .dim), (.overthinking, _):
            return "Wear a calming base, reset with one grounding pause, and focus on one finished loop."
        case (.focused, _):
            return "Wear clean lines, keep the reset simple, and focus on the task with the clearest finish line."
        case (.tender, _):
            return "Wear a gentle color, take a warm reset, and focus on making the day easier to inhabit."
        case (_, .luminous):
            return "Wear the lightest color that still feels like you, reset somewhere bright, and focus on visibility."
        default:
            return "Wear \(descriptor.auraColor), keep the day low-drama, and focus on the choice that reduces noise."
        }
    }
}

nonisolated final class AuraSnapshotStore {
    static let defaultsKey = "simastry_aura_snapshot_today"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func load() -> AuraSnapshot? {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let snapshot = try? decoder.decode(AuraSnapshot.self, from: data) else {
            return nil
        }
        guard calendar.isDate(snapshot.descriptor.createdAt, inSameDayAs: now()) else {
            clear()
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: AuraSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
