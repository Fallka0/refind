//
//  SendOfferSheet.swift
//  refind
//
//  Screen 09 · Angebot senden — a sheet over Entdecken or a want detail.
//

import SwiftUI
import PhotosUI

@MainActor
@Observable
final class SendOfferStore {
    var draft: OfferDraft
    var priceText = ""
    var isSending = false
    var errorMessage: String?

    private let repository: any RefindRepository

    init(want: Want, repository: any RefindRepository) {
        self.draft = OfferDraft(wantID: want.id)
        self.repository = repository
    }

    func priceChanged(_ raw: String) {
        // Accept only digits; the apostrophe is ours to add back on display.
        let digits = raw.filter(\.isNumber)
        draft.price = Money(chf: Int(digits) ?? 0)
        priceText = digits.isEmpty ? "" : Money(chf: Int(digits) ?? 0).digitsOnly
    }

    func addPicked(_ items: [PhotosPickerItem]) async {
        for item in items where draft.photos.count < OfferDraft.maxPhotos {
            guard let data = await item.refindImageData() else { continue }
            draft.photos.append(
                PhotoRef(id: "draft-\(UUID().uuidString.prefix(8))", localData: data)
            )
        }
    }

    func removePhoto(_ photo: PhotoRef) {
        draft.photos.removeAll { $0.id == photo.id }
    }

    func send() async -> Bool {
        guard !isSending else { return false }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            _ = try await repository.sendOffer(draft)
            return true
        } catch {
            errorMessage = (error as? RepositoryError)?.inlineMessage
                ?? RepositoryError.server.inlineMessage
            return false
        }
    }
}

struct SendOfferSheet: View {
    let want: Want
    let recipient: User
    var onSent: () -> Void = {}

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var store: SendOfferStore?
    @State private var picked: [PhotosPickerItem] = []
    @FocusState private var priceFocused: Bool

    var body: some View {
        ZStack {
            RF.Palette.paper.ignoresSafeArea()
            if let store {
                content(store)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(RF.Metric.sheetRadius)
        .presentationBackground(RF.Palette.paper)
        .task {
            store = store ?? SendOfferStore(want: want, repository: environment.repository)
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await store?.addPicked(items)
                picked = []
            }
        }
    }

    private func content(_ store: SendOfferStore) -> some View {
        @Bindable var store = store
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(RF.Palette.lineStrong)
                    .frame(width: RF.Metric.grabberWidth, height: RF.Metric.grabberHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                Text("Dein Angebot an \(recipient.displayName)")
                    .font(RF.display(32))
                    .foregroundStyle(RF.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)

                Text("\(want.title) · Budget \(want.budgetMax.formatted)")
                    .rfLabel(11, tracking: 0.66)
                    .padding(.top, 8)

                priceField(store).padding(.top, 26)
                photos(store).padding(.top, 24)
                message(store).padding(.top, 24)

                if let errorMessage = store.errorMessage {
                    Text(errorMessage.uppercased())
                        .rfLabel(11, color: RF.Palette.offer)
                        .padding(.top, 18)
                }

                VStack(spacing: 12) {
                    Button(store.isSending ? "Wird gesendet …" : "Angebot senden") {
                        Task {
                            if await store.send() {
                                onSent()
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(RFButtonStyle(kind: store.draft.priceIsValid && !store.isSending
                                               ? .offerFilled : .disabled))
                    .disabled(!store.draft.priceIsValid || store.isSending)
                    .accessibilityIdentifier("offer.send")

                    Text("\(recipient.displayName) sieht dein Profil und deine Bewertung")
                        .rfLabel(10, tracking: 0.6)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, RF.Metric.screenMargin)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func priceField(_ store: SendOfferStore) -> some View {
        @Bindable var store = store
        return RFFieldGroup(title: "Dein Preis", spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("CHF")
                        .font(RF.num(14, weight: .medium))
                        .foregroundStyle(RF.Palette.muted)
                    TextField("0", text: $store.priceText)
                        .font(RF.num(30, weight: .medium))
                        .foregroundStyle(RF.Palette.ink)
                        .keyboardType(.numberPad)
                        .tint(RF.Palette.offer)
                        .focused($priceFocused)
                        .onChange(of: store.priceText) { _, new in store.priceChanged(new) }
                        .accessibilityLabel("Dein Preis in Franken")
                }
                Rectangle()
                    .fill(RF.Palette.ink)
                    .frame(height: RF.Metric.inputRule)
            }
            // Over budget warns, never blocks — the design shows such offers as
            // ÜBER BUDGET rather than refusing them.
            if store.draft.exceedsBudget(of: want) {
                Text("Über dem Budget von \(want.budgetMax.formatted)")
                    .rfLabel(10, color: RF.Palette.offer)
            }
        }
    }

    private func photos(_ store: SendOfferStore) -> some View {
        RFFieldGroup(title: "Fotos", spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(store.draft.photos) { photo in
                        RFPhoto(photo: photo)
                            .frame(width: RF.Metric.offerPhotoSlot,
                                   height: RF.Metric.offerPhotoSlot)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    store.removePhoto(photo)
                                } label: {
                                    Text("×")
                                        .font(RF.ui(15, weight: .medium))
                                        .foregroundStyle(RF.Palette.paper)
                                        .frame(width: 22, height: 22)
                                        .background(RF.Palette.ink, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                                .accessibilityLabel("Foto entfernen")
                            }
                    }
                    if store.draft.photos.count < OfferDraft.maxPhotos {
                        RFPhotoPicker(selection: $picked,
                                      maxCount: OfferDraft.maxPhotos - store.draft.photos.count) {
                            Text("+")
                                .font(RF.ui(26))
                                .foregroundStyle(RF.Palette.muted)
                                .frame(width: RF.Metric.offerPhotoSlot,
                                       height: RF.Metric.offerPhotoSlot)
                                .overlay {
                                    Rectangle().strokeBorder(
                                        RF.Palette.lineStrong,
                                        style: StrokeStyle(lineWidth: RF.Metric.hairline,
                                                           dash: [4, 4])
                                    )
                                }
                        }
                        .accessibilityLabel("Foto hinzufügen")
                        .accessibilityIdentifier("offer.addPhoto")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func message(_ store: SendOfferStore) -> some View {
        @Bindable var store = store
        return RFFieldGroup(title: "Nachricht", spacing: 10) {
            TextEditor(text: $store.draft.message)
                .font(RF.ui(14))
                .foregroundStyle(RF.Palette.inkSoft)
                .scrollContentBackground(.hidden)
                .frame(height: 92)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RF.Palette.card)
                .overlay {
                    Rectangle().strokeBorder(RF.Palette.line, lineWidth: RF.Metric.hairline)
                }
                .accessibilityLabel("Nachricht")
        }
    }
}

#Preview("09 Angebot senden") {
    SendOfferSheet(want: MockSeed.eamesWant, recipient: MockSeed.nina)
        .environment(AppEnvironment.preview)
}
