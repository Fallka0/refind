//
//  SignInScreen.swift
//  refind
//
//  Not drawn in the handoff — the designs assume a signed-in user throughout.
//  Built from the same pieces as the post-a-want flow: serif title, underline
//  fields, one primary action.
//

import SwiftUI

struct SignInScreen: View {
    @Bindable var store: AuthStore

    @FocusState private var focus: Field?
    private enum Field { case email, password, name }

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("refind")
                    .font(RF.display(34))
                    .foregroundStyle(RF.Palette.ink)

                Text(store.title)
                    .font(RF.display(40))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)

                fields.padding(.top, 30)

                if let errorMessage = store.errorMessage {
                    Text(errorMessage.uppercased())
                        .rfLabel(11, color: RF.Palette.offer)
                        .padding(.top, 20)
                }

                Spacer(minLength: 30)

                VStack(spacing: 12) {
                    Button(store.actionTitle) {
                        focus = nil
                        Task { await store.submit() }
                    }
                    .buttonStyle(RFButtonStyle(kind: store.canSubmit ? .primary : .disabled))
                    .disabled(!store.canSubmit)
                    .accessibilityIdentifier("auth.submit")

                    Button(store.switchTitle) {
                        withAnimation(RF.Motion.entrance) {
                            store.isRegistering.toggle()
                            store.errorMessage = nil
                        }
                    }
                    .buttonStyle(RFButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("auth.switch")

                    Text("Mindestens 8 Zeichen. Länge zählt mehr als Sonderzeichen.")
                        .rfLabel(9, tracking: 0.9)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, RF.Metric.topInsetFlow)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 26) {
            if store.isRegistering {
                RFFieldGroup(title: "Name", spacing: 10) {
                    RFUnderlineField(placeholder: "Wie sollen dich andere sehen?",
                                     text: $store.displayName)
                        .focused($focus, equals: .name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                }
            }

            RFFieldGroup(title: "E-Mail", spacing: 10) {
                RFUnderlineField(placeholder: "du@beispiel.ch", text: $store.email)
                    .focused($focus, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }

            RFFieldGroup(title: "Passwort", spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    SecureField("", text: $store.password)
                        .font(RF.ui(20))
                        .tint(RF.Palette.offer)
                        .focused($focus, equals: .password)
                        // .newPassword tells the keychain to offer a strong one
                        // on register rather than autofilling an old password.
                        .textContentType(store.isRegistering ? .newPassword : .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await store.submit() } }
                        .accessibilityLabel("Passwort")
                    Rectangle()
                        .fill(RF.Palette.ink)
                        .frame(height: RF.Metric.inputRule)
                }
            }
        }
    }
}

#Preview("Sign in") {
    SignInScreen(store: AuthStore(api: RefindAPI(),
                                  repository: MockRefindRepository.instant))
}
