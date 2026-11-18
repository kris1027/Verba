/// Built in sample lesson data for the Design Gallery and the print check: a Polish explanation
/// of Spanish `ser` and `estar` with a table and a nested list, plus one exercise of each kind.
nonisolated public enum SampleLesson {
    /// The lesson topic, shown in the header label.
    public static let topic = "Spanish · ser and estar"

    /// The lesson title.
    public static let title = "Ser i estar: dwa czasowniki „być”"

    /// The explanation in Markdown, in the learner's native language (Polish).
    public static let explanation = """
        Hiszpański ma **dwa** czasowniki znaczące „być”. *Ser* opisuje to, czym coś **jest**, \
        a *estar* to, w jakim jest **stanie** albo **miejscu**. Porównaj `soy` i `estoy`.

        ## Kiedy używamy ser

        1. Zawód i pochodzenie
           - Soy profesora. (Jestem nauczycielką.)
           - Soy de Polonia. (Jestem z Polski.)
        2. Cechy stałe
           - La casa es grande.

        ## Kiedy używamy estar

        - Samopoczucie i nastrój: *Estoy cansada.*
        - Położenie: *Madrid está en España.*

        | Osoba | ser | estar |
        |:--|:--|:--|
        | yo | soy | estoy |
        | tú | eres | estás |
        | él / ella | es | está |
        | nosotros | somos | estamos |

        > Wskazówka: jeśli pytasz „gdzie?” albo „jak się czujesz?”, prawie zawsze wybierz *estar*.

        ```
        ser   → soy, eres, es
        estar → estoy, estás, está
        ```
        """

    /// The five exercises, in lesson order.
    static let exercises: [SampleExercise] = [
        SampleExercise(
            position: 0,
            kind: .choice(options: ["está", "es", "son", "estamos"], correct: 1),
            kindLabel: "Choice",
            prompt: "Wybierz poprawną formę: Mi hermano ___ médico.",
            correctAnswer: "es",
            explanation: "Zawód to cecha stała, więc używamy ser: Mi hermano es médico.",
            sampleAnswer: "es",
            sampleTone: .correct
        ),
        SampleExercise(
            position: 1,
            kind: .fillBlank(answer: "estoy"),
            kindLabel: "Fill in",
            prompt: "Uzupełnij formą estar: Hoy ___ muy cansada.",
            correctAnswer: "estoy",
            explanation: "Zmęczenie to stan, więc estar. Pierwsza osoba to estoy, nie estoi.",
            sampleAnswer: "estoi",
            sampleTone: .partlyCorrect
        ),
        SampleExercise(
            position: 2,
            kind: .translate(answer: "Soy de Polonia, pero ahora estoy en Madrid."),
            kindLabel: "Translate",
            prompt: "Przetłumacz na hiszpański: Jestem z Polski, ale teraz jestem w Madrycie.",
            correctAnswer: "Soy de Polonia, pero ahora estoy en Madrid.",
            explanation: "Pochodzenie wyrażamy przez ser (soy de), a położenie przez estar (estoy en).",
            sampleAnswer: "Estoy de Polonia, pero ahora soy en Madrid.",
            sampleTone: .wrong
        ),
        SampleExercise(
            position: 3,
            kind: .reorder(tokens: ["está", "¿Dónde", "estación?", "la"], correctOrder: [1, 0, 3, 2]),
            kindLabel: "Order",
            prompt: "Ułóż pytanie: Gdzie jest dworzec?",
            correctAnswer: "¿Dónde está la estación?",
            explanation: "Pytamy o położenie, więc estar: ¿Dónde está…?",
            sampleAnswer: "¿Dónde está la estación?",
            sampleTone: .correct
        ),
        SampleExercise(
            position: 4,
            kind: .match(
                left: ["ser", "estar", "tener", "ir"],
                right: ["mieć", "iść", "być (cecha)", "być (stan)"],
                key: [
                    MatchPair(left: 0, right: 2), MatchPair(left: 1, right: 3),
                    MatchPair(left: 2, right: 0), MatchPair(left: 3, right: 1),
                ]
            ),
            kindLabel: "Match",
            prompt: "Połącz czasownik z jego znaczeniem.",
            correctAnswer: "ser = być (cecha), estar = być (stan), tener = mieć, ir = iść",
            explanation: "Ser i estar oba znaczą „być”, ale opisują co innego.",
            sampleAnswer: nil,
            sampleTone: nil
        ),
    ]
}

/// One sample exercise with its expected answer and a sample attempt for print and gallery states.
nonisolated struct SampleExercise: Identifiable, Sendable {
    enum Kind: Sendable {
        case choice(options: [String], correct: Int)
        case fillBlank(answer: String)
        case translate(answer: String)
        case reorder(tokens: [String], correctOrder: [Int])
        case match(left: [String], right: [String], key: [MatchPair])
    }

    let position: Int
    let kind: Kind
    let kindLabel: String
    let prompt: String
    let correctAnswer: String
    let explanation: String
    /// The learner's last answer in the sample, or `nil` when unanswered.
    let sampleAnswer: String?
    /// The grade of the sample answer.
    let sampleTone: FeedbackTone?

    var id: Int { position }
}
