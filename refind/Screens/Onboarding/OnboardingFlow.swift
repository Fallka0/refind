//
//  OnboardingFlow.swift
//  refind
//
//  Screen 02 · Onboarding · Fin fragt. Step 1 is drawn; steps 2 and 3 reuse the
//  same skeleton, as the handoff specifies (region + radius, then notifications).
//

import SwiftUI

@MainActor
@Observable
final class OnboardingStore {
    var step = 1
    var interests: Set<Category> = []
    var region = "Zürich"
    var radiusKm = 30
    var notificationsAllowed = false

    let totalSteps = 3

    var canAdvance: Bool {
        switch step {
        case 1:  return !interests.isEmpty
        default: return true
        }
    }

    func toggle(_ category: Category) {
        if interests.contains(category) { interests.remove(category) }
        else { interests.insert(category) }
    }
}

struct OnboardingFlow: View {
    var onFinish: () -> Void = {}
    @Environment(AppEnvironment.self) private var environment
    @State private var store = OnboardingStore()

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                topRow
                progress.padding(.top, 14)

                FinSays(state: .asking, mascotHeight: 74) {
                    Text(speech)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 52)
                .id(store.step)   // Fin re-enters on each step

                Text(title)
                    .font(RF.display(44))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 44)

                stepContent.padding(.top, 28)

                Spacer(minLength: 20)

                Button(store.step == store.totalSteps ? "Los geht's" : "Weiter") {
                    advance()
                }
                .buttonStyle(RFButtonStyle(kind: store.canAdvance ? .primary : .disabled))
                .disabled(!store.canAdvance)
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 70)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
    }

    private var topRow: some View {
        HStack {
            Text("\(store.step) / \(store.totalSteps)").rfLabel(10)
            Spacer()
            Button("Überspringen", action: onFinish)
                .font(RF.ui(14))
                .foregroundStyle(RF.Palette.muted)
                .frame(minHeight: RF.Metric.minHitTarget, alignment: .trailing)
        }
    }

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(1...store.totalSteps, id: \.self) { index in
                Rectangle()
                    .fill(index <= store.step ? RF.Palette.ink : RF.Palette.line)
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schritt \(store.step) von \(store.totalSteps)")
    }

    private var speech: String {
        switch store.step {
        case 1:  return "Hoi, ich bin Fin. Hier zählt, was du suchst – nicht, was du loswerden willst."
        case 2:  return "Wo soll ich für dich schauen?"
        default: return "Soll ich dir Bescheid geben, wenn ein Angebot kommt?"
        }
    }

    private var title: String {
        switch store.step {
        case 1:  return "Was interessiert dich?"
        case 2:  return "Wo suchst du?"
        default: return "Bleibst du erreichbar?"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case 1:
            FlowRow(spacing: 10) {
                ForEach(Category.allCases) { category in
                    Button {
                        store.toggle(category)
                    } label: {
                        RFChip(title: category.displayName,
                               selected: store.interests.contains(category))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.interests.contains(category) ? .isSelected : [])
                }
            }
        case 2:
            VStack(spacing: 12) {
                FlowRow(spacing: 10) {
                    ForEach(RegionOption.all) { option in
                        Button {
                            store.region = option.name
                        } label: {
                            RFChip(title: option.name,
                                   selected: store.region == option.name,
                                   caps: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                FlowRow(spacing: 10) {
                    ForEach(RadiusOption.all) { option in
                        Button {
                            store.radiusKm = option.km
                        } label: {
                            RFChip(title: "\(option.km) km",
                                   selected: store.radiusKm == option.km,
                                   caps: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        default:
            VStack(alignment: .leading, spacing: 12) {
                RFCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Benachrichtigungen").rfLabel(10)
                        Text("Nur wenn jemand dir ein Angebot schickt oder im Chat antwortet.")
                            .font(RF.ui(14))
                            .foregroundStyle(RF.Palette.inkMid)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button("Erlauben") {
                    Task { store.notificationsAllowed = await environment.push.requestAuthorization() }
                }
                    .buttonStyle(RFButtonStyle(kind: store.notificationsAllowed
                                               ? .disabled : .secondary))
                    .disabled(store.notificationsAllowed)
            }
        }
    }

    private func advance() {
        if store.step < store.totalSteps {
            withAnimation(RF.Motion.entrance) { store.step += 1 }
        } else {
            onFinish()
        }
    }
}

#Preview("02 Onboarding") {
    OnboardingFlow()
}
