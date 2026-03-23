import SwiftUI

/// Code-based localization manager for Simastry.
/// Supports runtime language switching without restart.
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case spanish = "es"
        case portuguese = "pt-BR"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .portuguese: return "Português"
            }
        }

        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .spanish: return "🇪🇸"
            case .portuguese: return "🇧🇷"
            }
        }
    }

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        currentLanguage = Language(rawValue: saved) ?? .english
    }

    /// Get localized string
    func string(_ key: String) -> String {
        return LocalizedStrings.strings[currentLanguage.rawValue]?[key] ?? LocalizedStrings.strings["en"]?[key] ?? key
    }
}

/// All localized strings organized by language
enum LocalizedStrings {
    static let strings: [String: [String: String]] = [
        "en": en,
        "es": es,
        "pt-BR": ptBR
    ]

    // MARK: - English
    static let en: [String: String] = [
        // Landing
        "landing.title": "Simastry",
        "landing.subtitle": "Understand people through the stars",
        "landing.getStarted": "Get Started",
        "landing.signIn": "Already have an account? Sign in",
        "landing.terms": "Terms",
        "landing.privacy": "Privacy",
        "landing.privacyBadge": "Your birth data is never sold or shared",
        "landing.legalPrefix": "By continuing, you agree to our",
        "landing.and": "and",
        "landing.alreadyHaveAccount": "I already have an account",

        // Age Gate
        "ageGate.welcome": "Welcome to Simastry",
        "ageGate.confirm": "To use Simastry, please confirm your age.",
        "ageGate.over13": "I am 13 or older",
        "ageGate.under13": "I am under 13",
        "ageGate.underage": "Simastry is designed for users 13 and older. Please come back when you're old enough!",
        "ageGate.legal": "By continuing, you confirm that you are at least 13 years of age.",

        // Home
        "home.goodMorning": "Good morning",
        "home.goodAfternoon": "Good afternoon",
        "home.goodEvening": "Good evening",
        "home.predict": "Predict",
        "home.companions": "Companions",
        "home.guides": "Guides",
        "home.profile": "Profile",
        "home.didYouKnow": "Did you know?",
        "home.tryIt": "Try it",
        "home.savedGuides": "Saved Guides",

        // Birth Details
        "birth.birthday": "Birthday",
        "birth.time": "Birth Time",
        "birth.place": "Birth Place",
        "birth.next": "Next",
        "birth.done": "Done",
        "birth.unknownTime": "I don't know my birth time",
        "birth.unknownTimeNote": "That's okay — your Sun and Moon signs are still accurate. We'll estimate your Rising sign.",

        // Predict
        "predict.title": "Predict",
        "predict.generate": "Generate Prediction",
        "predict.regenerate": "Regenerate",
        "predict.paste": "Paste your conversation",
        "predict.share": "Share Result",
        "predict.disclaimer": "This is a pattern-based prediction, not a guarantee.",
        "predict.goTalk": "Now that you know what they might say — go have the real conversation",

        // Companions
        "companions.title": "Companions",
        "companions.add": "Add Companion",
        "companions.empty": "No companions yet",

        // Guides
        "guides.title": "Guides",
        "guides.savedGuides": "My Saved Guides",
        "guides.addGuide": "Add Guide",

        // Profile
        "profile.title": "Profile",
        "profile.signOut": "Sign Out",
        "profile.darkMode": "Dark Mode",
        "profile.methodology": "How Simastry Works",
        "profile.language": "Language",
        "profile.appearance": "Appearance",
        "profile.dark": "Dark",
        "profile.light": "Light",
        "profile.aboutApproach": "About Our Approach",
        "profile.selectLanguage": "Select Language",

        // Common
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.delete": "Delete",
        "common.share": "Share",
        "common.continue": "Continue",
        "common.gotIt": "Got it",

        // Upsell
        "upsell.unlock": "Unlock Full Access",
        "upsell.restore": "Restore Purchases",

        // AI Disclosure
        "ai.badge": "Powered by AI · Based on Western tropical synastry",

        // Ethics
        "ethics.stereotyping": "These are tendencies, not rules. Use them as a starting point, not a script.",
        "ethics.understanding": "Simastry helps you understand people — not control them.",
    ]

    // MARK: - Spanish
    static let es: [String: String] = [
        // Landing
        "landing.title": "Simastry",
        "landing.subtitle": "Entiende a las personas a través de las estrellas",
        "landing.getStarted": "Comenzar",
        "landing.signIn": "¿Ya tienes cuenta? Inicia sesión",
        "landing.terms": "Términos",
        "landing.privacy": "Privacidad",
        "landing.privacyBadge": "Tus datos de nacimiento nunca se venden ni comparten",
        "landing.legalPrefix": "Al continuar, aceptas nuestros",
        "landing.and": "y",
        "landing.alreadyHaveAccount": "Ya tengo una cuenta",

        // Age Gate
        "ageGate.welcome": "Bienvenido a Simastry",
        "ageGate.confirm": "Para usar Simastry, confirma tu edad.",
        "ageGate.over13": "Tengo 13 años o más",
        "ageGate.under13": "Tengo menos de 13 años",
        "ageGate.underage": "Simastry está diseñado para usuarios de 13 años o más. ¡Vuelve cuando seas mayor!",
        "ageGate.legal": "Al continuar, confirmas que tienes al menos 13 años.",

        // Home
        "home.goodMorning": "Buenos días",
        "home.goodAfternoon": "Buenas tardes",
        "home.goodEvening": "Buenas noches",
        "home.predict": "Predecir",
        "home.companions": "Compañeros",
        "home.guides": "Guías",
        "home.profile": "Perfil",
        "home.didYouKnow": "¿Sabías que...?",
        "home.tryIt": "Pruébalo",
        "home.savedGuides": "Guías guardadas",

        // Birth Details
        "birth.birthday": "Cumpleaños",
        "birth.time": "Hora de nacimiento",
        "birth.place": "Lugar de nacimiento",
        "birth.next": "Siguiente",
        "birth.done": "Listo",
        "birth.unknownTime": "No sé mi hora de nacimiento",
        "birth.unknownTimeNote": "No te preocupes — tu signo solar y lunar siguen siendo precisos. Estimaremos tu ascendente.",

        // Predict
        "predict.title": "Predecir",
        "predict.generate": "Generar predicción",
        "predict.regenerate": "Regenerar",
        "predict.paste": "Pega tu conversación",
        "predict.share": "Compartir resultado",
        "predict.disclaimer": "Esta es una predicción basada en patrones, no una garantía.",
        "predict.goTalk": "Ahora que sabes lo que podrían decir — ve y ten la conversación real",

        // Companions
        "companions.title": "Compañeros",
        "companions.add": "Agregar compañero",
        "companions.empty": "Aún no hay compañeros",

        // Guides
        "guides.title": "Guías",
        "guides.savedGuides": "Mis guías guardadas",
        "guides.addGuide": "Agregar guía",

        // Profile
        "profile.title": "Perfil",
        "profile.signOut": "Cerrar sesión",
        "profile.darkMode": "Modo oscuro",
        "profile.methodology": "Cómo funciona Simastry",
        "profile.language": "Idioma",
        "profile.appearance": "Apariencia",
        "profile.dark": "Oscuro",
        "profile.light": "Claro",
        "profile.aboutApproach": "Nuestro enfoque",
        "profile.selectLanguage": "Seleccionar idioma",

        // Common
        "common.cancel": "Cancelar",
        "common.save": "Guardar",
        "common.delete": "Eliminar",
        "common.share": "Compartir",
        "common.continue": "Continuar",
        "common.gotIt": "Entendido",

        // Upsell
        "upsell.unlock": "Desbloquear acceso completo",
        "upsell.restore": "Restaurar compras",

        // AI Disclosure
        "ai.badge": "Impulsado por IA · Basado en sinastría tropical occidental",

        // Ethics
        "ethics.stereotyping": "Estas son tendencias, no reglas. Úsalas como punto de partida, no como un guión.",
        "ethics.understanding": "Simastry te ayuda a entender a las personas — no a controlarlas.",
    ]

    // MARK: - Portuguese (Brazil)
    static let ptBR: [String: String] = [
        // Landing
        "landing.title": "Simastry",
        "landing.subtitle": "Entenda as pessoas através das estrelas",
        "landing.getStarted": "Começar",
        "landing.signIn": "Já tem uma conta? Entrar",
        "landing.terms": "Termos",
        "landing.privacy": "Privacidade",
        "landing.privacyBadge": "Seus dados de nascimento nunca são vendidos ou compartilhados",
        "landing.legalPrefix": "Ao continuar, você concorda com nossos",
        "landing.and": "e",
        "landing.alreadyHaveAccount": "Já tenho uma conta",

        // Age Gate
        "ageGate.welcome": "Bem-vindo ao Simastry",
        "ageGate.confirm": "Para usar o Simastry, confirme sua idade.",
        "ageGate.over13": "Tenho 13 anos ou mais",
        "ageGate.under13": "Tenho menos de 13 anos",
        "ageGate.underage": "O Simastry é feito para usuários com 13 anos ou mais. Volte quando for mais velho!",
        "ageGate.legal": "Ao continuar, você confirma que tem pelo menos 13 anos.",

        // Home
        "home.goodMorning": "Bom dia",
        "home.goodAfternoon": "Boa tarde",
        "home.goodEvening": "Boa noite",
        "home.predict": "Prever",
        "home.companions": "Companheiros",
        "home.guides": "Guias",
        "home.profile": "Perfil",
        "home.didYouKnow": "Você sabia?",
        "home.tryIt": "Experimente",
        "home.savedGuides": "Guias salvos",

        // Birth Details
        "birth.birthday": "Aniversário",
        "birth.time": "Hora de nascimento",
        "birth.place": "Local de nascimento",
        "birth.next": "Próximo",
        "birth.done": "Pronto",
        "birth.unknownTime": "Não sei minha hora de nascimento",
        "birth.unknownTimeNote": "Tudo bem — seus signos solar e lunar ainda são precisos. Vamos estimar seu ascendente.",

        // Predict
        "predict.title": "Prever",
        "predict.generate": "Gerar previsão",
        "predict.regenerate": "Regenerar",
        "predict.paste": "Cole sua conversa",
        "predict.share": "Compartilhar resultado",
        "predict.disclaimer": "Esta é uma previsão baseada em padrões, não uma garantia.",
        "predict.goTalk": "Agora que você sabe o que podem dizer — vá ter a conversa real",

        // Companions
        "companions.title": "Companheiros",
        "companions.add": "Adicionar companheiro",
        "companions.empty": "Nenhum companheiro ainda",

        // Guides
        "guides.title": "Guias",
        "guides.savedGuides": "Meus guias salvos",
        "guides.addGuide": "Adicionar guia",

        // Profile
        "profile.title": "Perfil",
        "profile.signOut": "Sair",
        "profile.darkMode": "Modo escuro",
        "profile.methodology": "Como o Simastry funciona",
        "profile.language": "Idioma",
        "profile.appearance": "Aparência",
        "profile.dark": "Escuro",
        "profile.light": "Claro",
        "profile.aboutApproach": "Nossa abordagem",
        "profile.selectLanguage": "Selecionar idioma",

        // Common
        "common.cancel": "Cancelar",
        "common.save": "Salvar",
        "common.delete": "Excluir",
        "common.share": "Compartilhar",
        "common.continue": "Continuar",
        "common.gotIt": "Entendi",

        // Upsell
        "upsell.unlock": "Desbloquear acesso completo",
        "upsell.restore": "Restaurar compras",

        // AI Disclosure
        "ai.badge": "Alimentado por IA · Baseado em sinastria tropical ocidental",

        // Ethics
        "ethics.stereotyping": "Estas são tendências, não regras. Use-as como ponto de partida, não como roteiro.",
        "ethics.understanding": "O Simastry ajuda você a entender as pessoas — não a controlá-las.",
    ]
}
