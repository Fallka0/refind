//
//  SafetySheets.swift
//  refind
//
//  Report, block and dispute. None of these are drawn in the handoff; they are
//  built from the same pieces as everything else — chips for the reason, a card
//  textarea for the detail, one primary action.
//
//  Tone note: these screens stay plainer than the rest of the product. Someone
//  reaching them is having a bad time, and Fin does not belong here.
//

import SwiftUI

// MARK: - Report

struct ReportSheet: View {
    let subject: ReportSubject
    let subjectName: String
    var onReported: () -> Void = {}

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var detail = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        SafetySheetLayout(
            title: "\(subjectName) melden",
            subtitle: "Wir schauen uns das an. Du bleibst anonym.",
            actionTitle: isSending ? "Wird gesendet …" : "Melden",
            actionEnabled: reason != nil && !isSending,
            actionKind: .offerFilled,
            errorMessage: errorMessage,
            action: send
        ) {
            RFFieldGroup(title: "Grund") {
                FlowRow(spacing: 8) {
                    ForEach(ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            RFChip(title: option.displayName,
                                   selected: reason == option,
                                   caps: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                }
            }
            RFFieldGroup(title: "Was ist passiert?") {
                SafetyTextEditor(text: $detail)
            }
        }
        .accessibilityIdentifier("report.sheet")
    }

    private func send() {
        guard let reason else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                try await environment.repository.report(subject, reason: reason, detail: detail)
                onReported()
                dismiss()
            } catch {
                errorMessage = (error as? RepositoryError)?.inlineMessage
                    ?? RepositoryError.server.inlineMessage
            }
            isSending = false
        }
    }
}

// MARK: - Dispute

struct DisputeSheet: View {
    let escrowID: String
    let partnerName: String
    var onOpened: (Escrow) -> Void = { _ in }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var reason: DisputeReason?
    @State private var detail = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        SafetySheetLayout(
            title: "Problem melden",
            subtitle: "Das Geld bleibt bei uns, bis das geklärt ist. \(partnerName) wird informiert.",
            actionTitle: isSending ? "Wird gemeldet …" : "Problem melden",
            actionEnabled: reason != nil && !isSending,
            actionKind: .offerFilled,
            errorMessage: errorMessage,
            action: send
        ) {
            RFFieldGroup(title: "Was stimmt nicht?") {
                FlowRow(spacing: 8) {
                    ForEach(DisputeReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            RFChip(title: option.displayName,
                                   selected: reason == option,
                                   caps: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                }
            }
            RFFieldGroup(title: "Beschreib es kurz") {
                SafetyTextEditor(text: $detail)
            }
        }
        .accessibilityIdentifier("dispute.sheet")
    }

    private func send() {
        guard let reason else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                let escrow = try await environment.repository.openDispute(
                    escrowID: escrowID, reason: reason, detail: detail
                )
                onOpened(escrow)
                dismiss()
            } catch {
                errorMessage = (error as? RepositoryError)?.inlineMessage
                    ?? RepositoryError.server.inlineMessage
            }
            isSending = false
        }
    }
}

// MARK: - Blocked users

struct BlockedUsersList: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var users: LoadState<[User]> = .idle

    var body: some View {
        Group {
            Group {
                    switch users {
                    case .idle, .loading:
                        RFSkeletonCard(lines: [120, 180])
                    case .loaded(let list) where list.isEmpty:
                        Text("Du hast niemanden blockiert.")
                            .font(RF.ui(14))
                            .foregroundStyle(RF.Palette.muted)
                            .padding(.vertical, 30)
                    case .loaded(let list):
                        VStack(spacing: 0) {
                            ForEach(list) { user in
                                HStack(spacing: 14) {
                                    RFAvatar(user: user, size: RF.Metric.avatarChatRow)
                                    Text(user.displayName)
                                        .font(RF.ui(15, weight: .medium))
                                        .foregroundStyle(RF.Palette.ink)
                                    Spacer()
                                    Button("Aufheben") { unblock(user) }
                                        .font(RF.ui(14, weight: .medium))
                                        .foregroundStyle(RF.Palette.offer)
                                        .buttonStyle(.plain)
                                }
                                .padding(.vertical, 14)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(RF.Palette.line)
                                        .frame(height: RF.Metric.hairline)
                                }
                            }
                        }
                    case .failed(let message):
                        RFErrorState(message: message) { Task { await load() } }
                    }
                }
        }
        .task { await load() }
    }

    private func load() async {
        users = .loading
        do { users = .loaded(try await environment.repository.blockedUsers()) }
        catch {
            users = .failed((error as? RepositoryError)?.inlineMessage
                            ?? RepositoryError.server.inlineMessage)
        }
    }

    private func unblock(_ user: User) {
        Task {
            try? await environment.repository.setBlocked(userID: user.id, blocked: false)
            await load()
        }
    }
}

// MARK: - Shared chrome

private struct SafetySheetLayout<Content: View>: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let actionEnabled: Bool
    let actionKind: RFButtonKind
    let errorMessage: String?
    let action: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(RF.ui(14))
                    .foregroundStyle(RF.Palette.inkMid)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 26) {
                    content
                }
                .padding(.top, 26)

                if let errorMessage {
                    Text(errorMessage.uppercased())
                        .rfLabel(11, color: RF.Palette.offer)
                        .padding(.top, 18)
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    Button(actionTitle, action: action)
                        .buttonStyle(RFButtonStyle(kind: actionEnabled ? actionKind : .disabled))
                        .disabled(!actionEnabled)
                        .accessibilityIdentifier("safety.submit")
                    Button("Abbrechen") { dismiss() }
                        .buttonStyle(RFButtonStyle(kind: .secondary))
                }
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.top, 34)
            .padding(.bottom, 40)
            .rfScrollableScreen()
        }
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
    }
}

private struct SafetyTextEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(RF.ui(14))
            .foregroundStyle(RF.Palette.inkSoft)
            .scrollContentBackground(.hidden)
            .frame(height: 100)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RF.Palette.card)
            .overlay { Rectangle().strokeBorder(RF.Palette.line, lineWidth: RF.Metric.hairline) }
    }
}
