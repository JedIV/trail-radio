import SwiftUI

private let phosphor = Color(red: 0.12, green: 1, blue: 0.43)

struct ContentView: View {
    @EnvironmentObject private var audio: TrailAudio
    private let labels = ["WIND", "HOOFBEATS", "WAGON CREAKS", "DISTANT BIRDS"]
    @State private var timerMinutes = 0
    @State private var showPrivacy = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Label("OFFLINE · ALWAYS", systemImage: "waveform")
                        Spacer()
                        Circle().fill(audio.playing ? phosphor : phosphor.opacity(0.25)).frame(width: 7, height: 7)
                    }.font(.system(size: 11, design: .monospaced))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRAIL\nRADIO").font(.system(size: 54, weight: .black, design: .monospaced)).tracking(-3)
                            .shadow(color: phosphor.opacity(0.45), radius: 14)
                        Text("A little pocket prairie.").font(.system(size: 14, design: .monospaced)).opacity(0.7)
                    }
                    PrairieView().frame(height: 100).accessibilityHidden(true)
                    Button(action: audio.toggle) {
                        HStack {
                            Image(systemName: audio.playing ? "pause.fill" : "play.fill")
                            Text(audio.playing ? "REST A WHILE" : "TAKE THE TRAIL")
                            Spacer()
                            Text(audio.playing ? "ON" : "OFF").opacity(0.5)
                        }.font(.system(size: 16, weight: .bold, design: .monospaced))
                            .padding(20).frame(maxWidth: .infinity)
                            .background(phosphor.opacity(0.09))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(phosphor.opacity(0.6)))
                    }.accessibilityLabel(audio.playing ? "Pause ambience" : "Play ambience")
                    VStack(spacing: 20) {
                        soundSlider("VOLUME", value: $audio.volume)
                        Divider().overlay(phosphor.opacity(0.2))
                        ForEach(0..<4, id: \.self) { i in soundSlider(labels[i], value: $audio.levels[i]) }
                    }
                    HStack {
                        Image(systemName: "moon")
                        Text("SLEEP TIMER")
                        Spacer()
                        Menu {
                            ForEach([0, 15, 30, 60, 120, 480], id: \.self) { minutes in
                                Button(minutes == 0 ? "Off · play continuously" : "\(minutes) minutes") {
                                    timerMinutes = minutes; audio.setSleepTimer(minutes: minutes)
                                }
                            }
                        } label: {
                            Text(audio.sleepEnd == nil ? "OFF ⌄" : "\(timerMinutes) MIN ⌄")
                        }
                    }.font(.system(size: 12, design: .monospaced))
                    if let end = audio.sleepEnd {
                        Text("Stops at \(end.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11, design: .monospaced)).opacity(0.6)
                    }
                    if let error = audio.error { Text(error).font(.footnote).accessibilityAddTraits(.updatesFrequently) }
                    Button("PRIVACY & SUPPORT") { showPrivacy = true }
                        .font(.system(size: 11, design: .monospaced))
                    Text("Close your eyes. We’ll keep the wagon rolling.")
                        .font(.system(size: 11, design: .monospaced)).opacity(0.5)
                }.padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("A little pocket prairie.").font(.title2.bold())
                        Text("Trail Radio generates its sound on your device. Playback works without an internet connection.")
                        Text("Privacy policy").font(.headline)
                        Text("Effective November 3, 2026. Trail Radio does not collect, transmit, sell, or share personal data. It has no accounts, ads, analytics, or tracking. It does not access your microphone, location, contacts, or health data.")
                        Text("Your volume and sound levels are stored locally on your device. You can change them in the app. Deleting the app removes its locally stored settings.")
                        Text("If you contact support by email, your email address and message are used to respond to your request. Email is handled by your email provider and the support mailbox provider. Apple may separately process App Store purchases, downloads, and diagnostics under its own policies.")
                        Text("Support").font(.headline)
                        Text("Questions or feedback? Contact John Dougherty.")
                        Link("john.e.dougherty@gmail.com", destination: URL(string: "mailto:john.e.dougherty@gmail.com")!)
                        Text("Use a comfortable, low listening level. Trail Radio is an ambience app and does not provide medical treatment.").font(.footnote).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth: 600)
                }
                .navigationTitle("Privacy & support")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPrivacy = false } } }
            }.tint(phosphor)
        }
        .foregroundStyle(phosphor).tint(phosphor)
        .background(Color(red: 0.015, green: 0.035, blue: 0.022).ignoresSafeArea())
    }
    private func soundSlider(_ name: String, value: Binding<Float>) -> some View {
        VStack(spacing: 6) {
            HStack { Text(name); Spacer(); Text("\(Int(value.wrappedValue * 100))%") }
                .font(.system(size: 11, design: .monospaced)).opacity(0.75)
            Slider(value: value, in: 0...1).accessibilityLabel(name)
        }
    }
}

private struct PrairieView: View {
    var body: some View {
        Canvas { context, size in
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: 60))
            for x in stride(from: 0.0, through: size.width, by: 3) {
                let y = 48 + sin(x * 0.021) * 11 + sin(x * 0.059) * 5
                horizon.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(horizon, with: .color(phosphor.opacity(0.6)), lineWidth: 2)
            for x in stride(from: 4.0, through: size.width, by: 14) {
                let y = 80 + sin(x) * 10
                context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(phosphor.opacity(0.3)))
            }
            let wagonX = size.width * 0.62
            context.fill(Path(roundedRect: CGRect(x: wagonX, y: 23, width: 45, height: 30), cornerRadius: 10), with: .color(phosphor.opacity(0.8)))
            for x in [wagonX + 9, wagonX + 36] {
                context.stroke(Path(ellipseIn: CGRect(x: x - 7, y: 52, width: 14, height: 14)), with: .color(phosphor), lineWidth: 2)
            }
            context.stroke(Path(CGRect(x: wagonX - 8, y: 51, width: 60, height: 1)), with: .color(phosphor), lineWidth: 2)
        }
    }
}
