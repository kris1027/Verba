import SwiftUI

/// Gallery section: the sample lesson as a real lesson page (header, Markdown explanation) with
/// all five exercise kinds live, so the keyboard map and feedback can be tried by hand.
struct LessonPageSection: View {
    @State private var simulatesFailure = false

    var body: some View {
        GallerySection(title: "Lesson page") {
            Toggle("Make checking fail (to try Try Again)", isOn: $simulatesFailure)
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                LessonHeader(topic: SampleLesson.topic, title: SampleLesson.title)
                MarkdownText(markdown: SampleLesson.explanation)
                ForEach(SampleLesson.exercises) { exercise in
                    SampleExerciseDemo(
                        exercise: exercise,
                        count: SampleLesson.exercises.count,
                        simulatesFailure: $simulatesFailure
                    )
                }
            }
            .readingColumnWidth()
        }
    }
}
