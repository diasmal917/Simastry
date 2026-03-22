import Foundation

nonisolated struct AstrologyTemplates {
    static let sunSign: [String: String] = [
        "aries": "Bold and pioneering, you lead with fire and passion",
        "taurus": "Grounded and sensual, you build beauty in everything",
        "gemini": "Curious and quick-witted, you see every side of every story",
        "cancer": "Nurturing and intuitive, you feel the world deeply",
        "leo": "Radiant and generous, you light up every room",
        "virgo": "Precise and devoted, you find perfection in the details",
        "libra": "Harmonious and fair, you seek balance in all things",
        "scorpio": "Intense and transformative, you see beneath every surface",
        "sagittarius": "Adventurous and philosophical, you chase truth everywhere",
        "capricorn": "Ambitious and disciplined, you build empires from nothing",
        "aquarius": "Visionary and independent, you dream of a better world",
        "pisces": "Empathic and creative, you dissolve boundaries with compassion"
    ]

    static let moonSign: [String: String] = [
        "aries": "Your emotions burn bright and fast — you feel everything intensely",
        "taurus": "You crave emotional security and find peace in simple pleasures",
        "gemini": "Your inner world is a constant dialogue of ideas and feelings",
        "cancer": "You carry the emotional memory of everyone you've ever loved",
        "leo": "Your heart needs to be seen, celebrated, and adored",
        "virgo": "You process emotions through analysis and acts of service",
        "libra": "You need harmony in your relationships to feel at peace",
        "scorpio": "Your emotional depths are oceanic — you love and hurt profoundly",
        "sagittarius": "Your spirit needs freedom to feel truly alive",
        "capricorn": "You guard your heart carefully but love with quiet devotion",
        "aquarius": "Your emotions are unconventional — you love humanity deeply",
        "pisces": "You absorb the emotions of everyone around you like a sponge"
    ]

    static let risingSign: [String: String] = [
        "aries": "You come across as confident, direct, and ready for anything",
        "taurus": "People see you as calm, reliable, and effortlessly elegant",
        "gemini": "You appear witty, social, and endlessly interesting",
        "cancer": "You project warmth, care, and an inviting softness",
        "leo": "You enter a room like you own it — magnetic and warm",
        "virgo": "You seem composed, thoughtful, and quietly intelligent",
        "libra": "People are drawn to your grace, charm, and aesthetic sense",
        "scorpio": "You have an aura of mystery and quiet intensity",
        "sagittarius": "You seem adventurous, optimistic, and larger than life",
        "capricorn": "You project authority, ambition, and quiet strength",
        "aquarius": "You come across as unique, progressive, and slightly enigmatic",
        "pisces": "You seem dreamy, gentle, and otherworldly"
    ]

    static let elementPairing: [String: String] = [
        "fire_fire": "Two flames together — passionate, explosive, never boring",
        "fire_earth": "Fire warms the earth, earth grounds the flame — a dance of ambition and patience",
        "fire_air": "Air fans the flame — together you spark ideas that light up the world",
        "fire_water": "Steam and mist — intense chemistry that transforms you both",
        "earth_earth": "Two mountains side by side — steady, loyal, unshakable",
        "earth_air": "The breeze over solid ground — you challenge each other to grow",
        "earth_water": "Rain nourishing soil — a deeply fertile, nurturing bond",
        "air_air": "Two winds intertwined — endless conversation, endless curiosity",
        "air_water": "Mist rising from the sea — dreamy, intuitive, beautifully complex",
        "water_water": "Two oceans merging — emotional depth beyond measure"
    ]

    static func elementPairingText(element1: String, element2: String) -> String {
        let sorted = [element1, element2].sorted()
        let key = "\(sorted[0])_\(sorted[1])"
        return elementPairing[key] ?? "A cosmic connection written in the stars"
    }

    static let closing = "The stars have spoken — your cosmic DNA is written."
}
