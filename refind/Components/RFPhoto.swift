//
//  RFPhoto.swift
//  refind
//
//  One call site for every picture in the app: a picked image, a remote one, or
//  the deterministic stand-in when there is neither.
//

import SwiftUI
import PhotosUI

struct RFPhoto: View {
    let photo: PhotoRef
    var cornerRadius: CGFloat = RF.Metric.cardRadius
    var bordered: Bool = true

    var body: some View {
        Group {
            if let data = photo.localData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = photo.url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RFMockPhoto(seed: photo.id, cornerRadius: 0, bordered: false)
                }
            } else {
                RFMockPhoto(seed: photo.id, cornerRadius: 0, bordered: false)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(RF.Palette.line, lineWidth: RF.Metric.hairline)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Wraps PhotosPicker so the brand's "+" slot is the affordance, not Apple's.
struct RFPhotoPicker<Label: View>: View {
    @Binding var selection: [PhotosPickerItem]
    var maxCount: Int
    @ViewBuilder var label: Label

    var body: some View {
        PhotosPicker(selection: $selection,
                     maxSelectionCount: maxCount,
                     matching: .images,
                     photoLibrary: .shared()) {
            label
        }
        .buttonStyle(.plain)
    }
}

extension PhotosPickerItem {
    /// Downscaled JPEG data — the raw asset is far larger than any slot needs.
    func refindImageData() async -> Data? {
        guard let raw = try? await loadTransferable(type: Data.self),
              let image = UIImage(data: raw) else { return nil }
        let maxSide: CGFloat = 1200
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.85) }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
