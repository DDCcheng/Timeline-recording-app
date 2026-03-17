// Superbrain/Services/ImageStorageService.swift
import UIKit

final class ImageStorageService {
    private let baseURL: URL

    init(baseURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.baseURL = baseURL
    }

    // MARK: - Public API

    @discardableResult
    func save(image: UIImage, imageID: UUID, noteID: UUID) -> Result<Void, Error> {
        let dirURL = directoryURL(for: noteID)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent("\(imageID.uuidString).jpg")
            let quality: CGFloat = (image.jpegData(compressionQuality: 0.8).map {
                $0.count > 2 * 1024 * 1024 ? 0.5 : 0.8
            }) ?? 0.8
            guard let data = image.jpegData(compressionQuality: quality) else {
                return .failure(ImageStorageError.compressionFailed)
            }
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func load(imageID: UUID, noteID: UUID) -> UIImage? {
        let fileURL = directoryURL(for: noteID)
            .appendingPathComponent("\(imageID.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(for noteID: UUID) {
        try? FileManager.default.removeItem(at: directoryURL(for: noteID))
    }

    // MARK: - Private

    private func directoryURL(for noteID: UUID) -> URL {
        baseURL.appendingPathComponent("images").appendingPathComponent(noteID.uuidString)
    }
}

enum ImageStorageError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "图片压缩失败" }
}
