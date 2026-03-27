import Foundation

nonisolated struct LifePathMeaning: Sendable {
    let number: Int
    let name: String
    let description: String
}

nonisolated struct ChineseZodiacAnimal: Sendable {
    let name: String
    let emoji: String
    let trait: String
}

nonisolated struct NumerologyTemplates {
    static let lifePathMeanings: [Int: LifePathMeaning] = [
        1: LifePathMeaning(number: 1, name: "The Leader", description: "Independent, ambitious, pioneering"),
        2: LifePathMeaning(number: 2, name: "The Diplomat", description: "Cooperative, sensitive, peacemaker"),
        3: LifePathMeaning(number: 3, name: "The Communicator", description: "Creative, expressive, social"),
        4: LifePathMeaning(number: 4, name: "The Builder", description: "Disciplined, stable, hardworking"),
        5: LifePathMeaning(number: 5, name: "The Adventurer", description: "Freedom-loving, adaptable, curious"),
        6: LifePathMeaning(number: 6, name: "The Nurturer", description: "Responsible, caring, community-oriented"),
        7: LifePathMeaning(number: 7, name: "The Seeker", description: "Analytical, introspective, spiritual"),
        8: LifePathMeaning(number: 8, name: "The Powerhouse", description: "Ambitious, authoritative, material success"),
        9: LifePathMeaning(number: 9, name: "The Humanitarian", description: "Compassionate, idealistic, selfless"),
        11: LifePathMeaning(number: 11, name: "Master Intuitive", description: "Heightened intuition, spiritual insight"),
        22: LifePathMeaning(number: 22, name: "Master Builder", description: "Visionary, capable of manifesting big dreams"),
        33: LifePathMeaning(number: 33, name: "Master Teacher", description: "Compassionate leadership, healing")
    ]

    static let chineseZodiacAnimals: [Int: ChineseZodiacAnimal] = [
        0: ChineseZodiacAnimal(name: "Monkey", emoji: "🐵", trait: "Clever, curious, and playful"),
        1: ChineseZodiacAnimal(name: "Rooster", emoji: "🐓", trait: "Honest, hardworking, and observant"),
        2: ChineseZodiacAnimal(name: "Dog", emoji: "🐕", trait: "Loyal, honest, and protective"),
        3: ChineseZodiacAnimal(name: "Pig", emoji: "🐷", trait: "Generous, compassionate, and diligent"),
        4: ChineseZodiacAnimal(name: "Rat", emoji: "🐀", trait: "Quick-witted, resourceful, and adaptable"),
        5: ChineseZodiacAnimal(name: "Ox", emoji: "🐂", trait: "Dependable, strong, and determined"),
        6: ChineseZodiacAnimal(name: "Tiger", emoji: "🐅", trait: "Brave, competitive, and confident"),
        7: ChineseZodiacAnimal(name: "Rabbit", emoji: "🐇", trait: "Gentle, elegant, and compassionate"),
        8: ChineseZodiacAnimal(name: "Dragon", emoji: "🐉", trait: "Charismatic, ambitious, and energetic"),
        9: ChineseZodiacAnimal(name: "Snake", emoji: "🐍", trait: "Wise, intuitive, and mysterious"),
        10: ChineseZodiacAnimal(name: "Horse", emoji: "🐴", trait: "Active, energetic, and freedom-loving"),
        11: ChineseZodiacAnimal(name: "Goat", emoji: "🐐", trait: "Calm, gentle, and creative")
    ]

    static func calculateLifePathNumber(from date: Date) -> Int {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        let digitSum = sumDigits(day) + sumDigits(month) + sumDigits(year)

        if digitSum == 11 || digitSum == 22 || digitSum == 33 {
            return digitSum
        }

        return reduceToSingleDigit(digitSum)
    }

    static func chineseZodiacAnimal(from date: Date) -> ChineseZodiacAnimal {
        let year = Calendar.current.component(.year, from: date)
        let index = year % 12
        return chineseZodiacAnimals[index] ?? ChineseZodiacAnimal(name: "Unknown", emoji: "✨", trait: "A mysterious cosmic energy")
    }

    private static func sumDigits(_ number: Int) -> Int {
        var n = abs(number)
        var total = 0
        while n > 0 {
            total += n % 10
            n /= 10
        }
        return total
    }

    private static func reduceToSingleDigit(_ number: Int) -> Int {
        var n = number
        while n > 9 && n != 11 && n != 22 && n != 33 {
            n = sumDigits(n)
        }
        return n
    }
}
