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
            topActions

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
            AppleHealthImportSheet { result in
                store.applyHealthImport(result)
                store.saveCheckIn(in: modelContext)
                isShowingHealthImport = false
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Required answer missing", isPresented: $isShowingMissingDataWarning) {
            Button("Review", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "Please answer before completing this AI check-in.\n\n\(labels)"
    }

    private func completeWithValidation() {
        if !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.checkIn.movementBreaks = typedAnswer
        }
        guard !store.checkIn.movementBreaks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            missingItems = [
                MissingDataItem(field: "movement_breaks", label: "Movement breaks", code: MissingDataCode.missing)
            ]
            isShowingMissingDataWarning = true
            return
        }
        store.checkIn.isCompleted = true
        store.saveCheckIn(in: modelContext)
        store.screen = .completion
    }

    private var topActions: some View {
        VStack(spacing: 10) {
            AppleHealthRow {
                isShowingHealthImport = true
            }

            Button {
                store.screen = .manualCheckIn
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundStyle(AppColor.blue)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch to manual input")
                            .font(.headline)
                            .foregroundStyle(AppColor.text)
                        Text("Use the guided form instead")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColor.text)
                }
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
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
