import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 34) {
            Spacer()
            CloudyMascotView(size: 250)
            Text("You are all set!")
                .font(.title.bold())
                .foregroundStyle(.black)
            Spacer()
            PrimaryButton(title: "Go to Homepage") {
                store.showMain(tab: .home)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(.white)
    }
}
