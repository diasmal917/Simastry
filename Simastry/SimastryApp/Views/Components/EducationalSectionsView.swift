import SwiftUI

struct EducationalSectionsView: View {
    @State private var expandedCards: Set<String> = []
    @State private var lifePathBirthday: Date = Calendar.current.date(from: DateComponents(year: 1996, month: 3, day: 15)) ?? Date()
    @State private var lifePathResult: Int?
    @State private var chineseZodiacResult: ChineseZodiacAnimal?
    @State private var hasCalculatedLifePath: Bool = false
    @State private var hasCalculatedChinese: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            astrology101Section
            numerology101Section
            chineseZodiacSection
        }
    }

    // MARK: - Astrology 101

    private var astrology101Section: some View {
        VStack(alignment: .leading, spacing: 16) {
            educationalSectionHeader("Astrology 101")

            expandableCard(
                id: "what_is_astrology",
                title: "What is Astrology?",
                brief: "The study of how celestial positions influence personality and life events",
                body: "Astrology divides the sky into 12 zodiac signs, each with distinct personality traits based on the position of the sun at your birth. Your birth chart (natal chart) maps where all major celestial bodies were at the exact moment you were born. The three most important placements are your Sun sign (core identity), Moon sign (emotional inner world), and Rising sign (how others perceive you). Astrology has been practiced for thousands of years across cultures \u{2014} from Babylonian star maps to Vedic traditions to modern Western astrology.",
                iconName: "globe.americas.fill"
            )

            expandableCard(
                id: "big_three",
                title: "Sun, Moon & Rising \u{2014} The Big Three",
                brief: "The three placements that define your cosmic DNA",
                body: "Your Sun sign is your ego, core personality, who you are at your center \u{2014} the sign most people know. Your Moon sign is your emotional landscape \u{2014} what you need to feel safe, how you process feelings, who you are at 2am when no one is watching. Your Rising sign (also called Ascendant) is your social mask \u{2014} first impressions, how you come across to strangers, who you are at a job interview. Together, these three create a much richer picture than your Sun sign alone. Think of it this way: your Sun is who you ARE, your Moon is who you FEEL, your Rising is who you SEEM.",
                iconName: "sun.and.horizon.fill"
            )

            expandableCard(
                id: "four_elements",
                title: "The 4 Elements",
                brief: "Fire, Earth, Air, Water \u{2014} the building blocks of every sign",
                body: "Every zodiac sign belongs to one of four elements. Fire signs (Aries \u{2648}\u{FE0E}, Leo \u{264C}\u{FE0E}, Sagittarius \u{2650}\u{FE0E}) are passionate, bold, and action-oriented. Earth signs (Taurus \u{2649}\u{FE0E}, Virgo \u{264D}\u{FE0E}, Capricorn \u{2651}\u{FE0E}) are grounded, practical, and reliable. Air signs (Gemini \u{264A}\u{FE0E}, Libra \u{264E}\u{FE0E}, Aquarius \u{2652}\u{FE0E}) are intellectual, communicative, and social. Water signs (Cancer \u{264B}\u{FE0E}, Scorpio \u{264F}\u{FE0E}, Pisces \u{2653}\u{FE0E}) are emotional, intuitive, and deep. Elements that naturally flow together: Fire + Air feed each other. Earth + Water nourish each other. Opposite pairings (Fire + Water, Earth + Air) create tension \u{2014} but tension can also drive transformation.",
                iconName: "flame.fill"
            )

            expandableCard(
                id: "what_is_synastry",
                title: "What is Synastry?",
                brief: "How two charts interact \u{2014} the astrology of relationships",
                body: "Synastry is the comparison of two people\u{2019}s birth charts to understand relationship dynamics. It looks at how your planets interact with another person\u{2019}s planets \u{2014} where they align, where they clash, and where they create chemistry. Compatible elements often create natural flow, while challenging combinations create friction that can also spark growth. This is the core of what Simastry does \u{2014} simulate the interplay between two charts to predict how people will communicate, connect, and clash. Jaylen Brown applied this concept to his NBA teammates \u{2014} learning each person\u{2019}s sign to adjust his communication style.",
                iconName: "link"
            )

            expandableCard(
                id: "jaylen_brown",
                title: "How Jaylen Brown Uses Astrology",
                brief: "An NBA Finals MVP studies his teammates\u{2019} signs to lead better",
                body: "Jaylen Brown, the Boston Celtics star and 2024 NBA Finals MVP, revealed that he memorized every teammate\u{2019}s Western zodiac sign, Chinese zodiac sign, and numerology numbers as part of his leadership approach this season. He uses this knowledge to adapt how he communicates with each person. As Brown said: \u{201C}I started utilizing that when I speak to each and every guy. I didn\u{2019}t know if it would work before the season started, but that stuff definitely works.\u{201D} His coach Joe Mazzulla confirmed it transformed team dynamics, saying Brown\u{2019}s leadership approach has been about understanding how to push his teammates\u{2019} buttons and how to communicate with them better. For example, Brown noted that Jayson Tatum is a Pisces \u{2014} known for being empathetic and emotionally sensitive \u{2014} and adjusted his communication accordingly. This is exactly what Simastry automates: understanding someone\u{2019}s cosmic wiring to communicate more effectively.",
                iconName: "trophy.fill"
            )
        }
    }

    // MARK: - Numerology 101

    private var numerology101Section: some View {
        VStack(alignment: .leading, spacing: 16) {
            educationalSectionHeader("Numerology 101")

            expandableCard(
                id: "what_is_numerology",
                title: "What is Numerology?",
                brief: "The mystical study of numbers and their influence on your life",
                body: "Numerology is a belief system that assigns spiritual and personality meaning to numbers, especially those connected to your birth date and name. While astrology maps celestial positions, numerology distills your identity into core numbers. The practice dates back thousands of years \u{2014} Pythagoras believed numbers were the foundation of the universe. It\u{2019}s not a replacement for astrology \u{2014} it\u{2019}s a complementary lens that adds another layer to understanding yourself and others.",
                iconName: "number"
            )

            lifePathCard

            expandableCard(
                id: "expression_numbers",
                title: "Expression, Soul Urge & Personality Numbers",
                brief: "The numbers hidden in your name",
                body: "Beyond your birth date, numerology also analyzes your full birth name. Your Expression Number (from all letters in your full name) reveals your natural talents and abilities. Your Soul Urge Number (from vowels only) reveals your inner desires and deepest motivations. Your Personality Number (from consonants only) reveals how others perceive you. Each letter maps to a number using the Pythagorean system: A/J/S=1, B/K/T=2, C/L/U=3, D/M/V=4, E/N/W=5, F/O/X=6, G/P/Y=7, H/Q/Z=8, I/R=9.",
                iconName: "textformat.abc"
            )

            expandableCard(
                id: "astrology_vs_numerology",
                title: "Astrology vs. Numerology \u{2014} What\u{2019}s the Difference?",
                brief: "Two ancient systems, one cosmic picture",
                body: "Astrology is based on celestial positions (planets, stars) at your time and place of birth. It uses your birth date, time, AND location to generate 12 archetypal signs with nuanced placements. Numerology is based on numbers derived from your birth date and name. It only needs your date and name to calculate core numbers (1\u{2013}9 plus master numbers). They complement each other beautifully: your Sun sign describes WHO you are, your Life Path number describes your JOURNEY. Jaylen Brown studied both for his Celtics teammates \u{2014} Western zodiac signs AND numerology \u{2014} because using them together gives a more complete picture of how to communicate with someone. Think of astrology as the \u{201C}what\u{201D} (what kind of person are you) and numerology as the \u{201C}how\u{201D} (how you move through life).",
                iconName: "arrow.triangle.branch"
            )
        }
    }

    // MARK: - Life Path Calculator Card

    private var lifePathCard: some View {
        let isExpanded = expandedCards.contains("life_path")

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    if expandedCards.contains("life_path") {
                        expandedCards.remove("life_path")
                    } else {
                        expandedCards.insert("life_path")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3.middle.filled")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 36, height: 36)
                        .background(SimastryColor.gold.opacity(0.14), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Life Path Number")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("The most important number in numerology \u{2014} derived from your birthday")
                            .font(.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(SimastryColor.gold.opacity(0.15))
                        .frame(height: 1)
                        .padding(.top, 14)

                    Text("Your Life Path Number is calculated by reducing your full birth date to a single digit (or master number). Example: Born March 15, 1996 \u{2192} 3+1+5+1+9+9+6 = 34 \u{2192} 3+4 = 7. Life Path 7.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 14) {
                        HStack {
                            Text("Your birthday")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(SimastryColor.offWhite)

                            Spacer()

                            DatePicker("", selection: $lifePathBirthday, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(SimastryColor.gold)
                        }

                        Button {
                            HapticManager.signConfirmed()
                            let number = NumerologyTemplates.calculateLifePathNumber(from: lifePathBirthday)
                            let animal = NumerologyTemplates.chineseZodiacAnimal(from: lifePathBirthday)
                            withAnimation(.spring(SimastrySpring.bouncy)) {
                                lifePathResult = number
                                chineseZodiacResult = animal
                                hasCalculatedLifePath = true
                                hasCalculatedChinese = true
                            }
                        } label: {
                            Text("Calculate")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SimastryColor.midnight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(SimastryColor.gold, in: .capsule)
                        }
                        .buttonStyle(SpringPressStyle())
                    }
                    .padding(16)
                    .simastryGlass(cornerRadius: 16)

                    if let result = lifePathResult, let meaning = NumerologyTemplates.lifePathMeanings[result] {
                        VStack(spacing: 8) {
                            Text("\(result)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(SimastryColor.gold)

                            Text(meaning.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(SimastryColor.offWhite)

                            Text(meaning.description)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .goldGlassRect(cornerRadius: 20)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
    }

    // MARK: - Chinese Zodiac

    private var chineseZodiacSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            educationalSectionHeader("Chinese Zodiac")

            chineseZodiacCard
        }
    }

    private var chineseZodiacCard: some View {
        let isExpanded = expandedCards.contains("chinese_zodiac")

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    if expandedCards.contains("chinese_zodiac") {
                        expandedCards.remove("chinese_zodiac")
                    } else {
                        expandedCards.insert("chinese_zodiac")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hare.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SimastryColor.sunCoral)
                        .frame(width: 36, height: 36)
                        .background(SimastryColor.sunCoral.opacity(0.14), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("The Chinese Zodiac")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)

                        Text("12 animals, 12 years \u{2014} another layer of your cosmic identity")
                            .font(.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(SimastryColor.sunCoral.opacity(0.15))
                        .frame(height: 1)
                        .padding(.top, 14)

                    Text("The Chinese zodiac assigns an animal to each person based on birth year, cycling through 12 animals: Rat, Ox, Tiger, Rabbit, Dragon, Snake, Horse, Goat, Monkey, Rooster, Dog, Pig. Each animal carries distinct personality traits. Unlike Western astrology (based on birth month and the sun\u{2019}s position), Chinese astrology is based on birth year and follows a lunar calendar.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    if hasCalculatedChinese, let animal = chineseZodiacResult {
                        VStack(spacing: 8) {
                            Text(animal.emoji)
                                .font(.system(size: 48))

                            Text(animal.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(SimastryColor.offWhite)

                            Text(animal.trait)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .tintedGlass(SimastryColor.sunCoral.opacity(0.16), cornerRadius: 20)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        VStack(spacing: 14) {
                            HStack {
                                Text("Your birthday")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(SimastryColor.offWhite)

                                Spacer()

                                DatePicker("", selection: $lifePathBirthday, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(SimastryColor.gold)
                            }

                            Button {
                                HapticManager.signConfirmed()
                                let animal = NumerologyTemplates.chineseZodiacAnimal(from: lifePathBirthday)
                                withAnimation(.spring(SimastrySpring.bouncy)) {
                                    chineseZodiacResult = animal
                                    hasCalculatedChinese = true
                                }
                            } label: {
                                Text("Find My Animal")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(SimastryColor.midnight)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(SimastryColor.sunCoral, in: .capsule)
                            }
                            .buttonStyle(SpringPressStyle())
                        }
                        .padding(16)
                        .simastryGlass(cornerRadius: 16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
    }

    // MARK: - Shared Components

    private func educationalSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AstropediaColors.gold)
    }

    private func expandableCard(
        id: String,
        title: String,
        brief: String,
        body: String,
        iconName: String
    ) -> some View {
        let isExpanded = expandedCards.contains(id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.buttonPress()
                withAnimation(.spring(SimastrySpring.smooth)) {
                    if expandedCards.contains(id) {
                        expandedCards.remove(id)
                    } else {
                        expandedCards.insert(id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SimastryColor.gold)
                        .frame(width: 36, height: 36)
                        .background(SimastryColor.gold.opacity(0.14), in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SimastryColor.offWhite)

                        Text(brief)
                            .font(.caption)
                            .foregroundStyle(SimastryColor.mutedSilver)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SimastryColor.mutedSilver)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(SimastryColor.gold.opacity(0.15))
                        .frame(height: 1)
                        .padding(.top, 14)

                    Text(body)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(SimastryColor.offWhite.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .simastryGlass(cornerRadius: 20)
    }
}
