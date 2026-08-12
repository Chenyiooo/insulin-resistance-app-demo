import SwiftUI
import SwiftData

struct AICheckInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var typedAnswer = ""
    @State private var selectedOption: String?
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    private let options = ["Hourly or more", "A few times", "Once", "Not at all"]

    var body: some View {
        VStack(spacing: 0) {
            header
            progressHeader

            ScrollView {
                VStack(spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        CloudyMascotView(size: 110)
                        Text("Hi Root! Let's check in on your day.\nThis takes about 5 minutes.")
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                            .lineSpacing(6)
                            .padding(22)
                            .background(AppColor.softViolet)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.top, 42)

                    Text("While sitting today, how often did you get up and move for at least 2-3 minutes?")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.text)
                        .lineSpacing(8)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.softViolet)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Choose an option or tell me in your own words.")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                selectedOption = option
                                store.checkIn.movementBreaks = option
                            } label: {
                                Text(option)
                                    .font(.headline)
                                    .foregroundStyle(AppColor.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 72)
                                    .background(selectedOption == option ? Color.blue.opacity(0.12) : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.45)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        isShowingHealthImport = true
                    } label: {
                        SectionCard {
                            HStack(spacing: 14) {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                                    .frame(width: 58, height: 58)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Import available health data")
                                        .font(.headline)
                                        .foregroundStyle(AppColor.text)
                                    Text("Sleep, workouts, and other supported data")
                                        .font(.callout)
                                        .foregroundStyle(AppColor.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColor.text)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.screen = .manualCheckIn
                    } label: {
                        Text("Prefer forms? ")
                            .foregroundStyle(AppColor.text)
                        + Text("Switch to manual input")
                            .foregroundStyle(AppColor.blue)
                    }
                    .font(.callout)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 14) {
                TextField("Type your answer...", text: $typedAnswer)
                    .textFieldStyle(AppTextFieldStyle())
                    .overlay(alignment: .trailing) {
                        Image(systemName: "mic")
                            .font(.title2)
                            .foregroundStyle(AppColor.muted)
                            .padding(.trailing, 16)
                    }
                Button {
                    if !typedAnswer.isEmpty {
                        store.checkIn.movementBreaks = typedAnswer
                    }
                    completeWithValidation()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppColor.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(AppColor.line).frame(height: 1)
            }

            BottomTabBar()
        }
        .background(.white)
        .sheet(isPresented: $isShowingHealthImport) {
            AppleHealthImportSheet {
                store.importMockAppleHealthData()
                store.saveCheckIn(in: modelContext)
                isShowingHealthImport = false
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Check-in saved with missing data", isPresented: $isShowingMissingDataWarning) {
            Button("Complete Anyway") {
                store.screen = .completion
            }
            Button("Review", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "We need a little more information before we can update your risk estimate.\n\n\(labels)"
    }

    private func completeWithValidation() {
        store.checkIn.isCompleted = true
        missingItems = store.checkInMissingDataItems()
        store.saveCheckIn(in: modelContext)
        if missingItems.isEmpty {
            store.screen = .completion
        } else {
            isShowingMissingDataWarning = true
        }
    }

    private var header: some View {
        HStack {
            Button {
                store.screen = .checkInEntry
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title.weight(.regular))
                    .foregroundStyle(AppColor.text)
            }
            Spacer()
            Text("Daily Check-in")
                .font(.title.bold())
                .foregroundStyle(AppColor.text)
            Spacer()
            Button("Exit") {
                store.showMain(tab: .home)
            }
            .font(.headline)
            .foregroundStyle(AppColor.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue))
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's check-in")
                Spacer()
                Text("2 of 4")
            }
            .font(.title3)
            .foregroundStyle(AppColor.text)
            ProgressView(value: 0.44)
                .tint(AppColor.blue)
        }
        .padding(24)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }
}
