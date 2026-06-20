import Foundation
import Supabase
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Uploads account avatar images to the public `account-images` Storage bucket.
///
/// Images are downsized to ≤256px and re-encoded to WebP before upload (objects
/// stay a few KB). Objects live at `{user_id}/{uuid}.webp`; the resulting public
/// URL is stored in `accounts.image_url`. See iOS Tech Plan §8.2 and System
/// Design §4.10, migration `20260607000002_account_images.sql`.
actor AccountImageService {
    enum ImageError: LocalizedError {
        case encodingFailed
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Could not process the selected image."
            }
        }
    }

    private let bucket = "account-images"
    private let maxDimension: CGFloat = 256

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// Downsizes + WebP-encodes the image, uploads it to `{user_id}/{uuid}.webp`,
    /// and returns the public URL to persist on the account row.
    func upload(image: UIImage) async throws -> String {
        guard let data = Self.webPData(from: image, maxDimension: maxDimension) else {
            throw ImageError.encodingFailed
        }
        let userId = try await client.auth.session.user.id
        let path = "\(userId.uuidString)/\(UUID().uuidString).webp"

        try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/webp", upsert: false))

        let url = try client.storage.from(bucket).getPublicURL(path: path)
        return url.absoluteString
    }

    /// Best-effort deletion of a previously stored object, given its public URL.
    /// Called only **after** the account row save succeeds, so a cancelled or
    /// failed save never removes a still-referenced image.
    func deletePreviousObject(publicURL: String) async {
        guard let path = Self.objectPath(fromPublicURL: publicURL) else { return }
        _ = try? await client.storage.from(bucket).remove(paths: [path])
    }

    // MARK: - Helpers

    /// Recovers the object path (`{user_id}/{uuid}.webp`) from a stored public URL
    /// like `.../object/public/account-images/{user_id}/{uuid}.webp`.
    private static func objectPath(fromPublicURL urlString: String) -> String? {
        guard let range = urlString.range(of: "/account-images/") else { return nil }
        let path = String(urlString[range.upperBound...])
        return path.isEmpty ? nil : path
    }

    private static func webPData(from image: UIImage, maxDimension: CGFloat) -> Data? {
        let cgImage: CGImage
        if let resized = resize(image, maxDimension: maxDimension)?.cgImage {
            cgImage = resized
        } else if let original = image.cgImage {
            cgImage = original
        } else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.webP.identifier as CFString, 1, nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Scales the image so its longest side is `maxDimension`; returns it unchanged
    /// when already small enough.
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
