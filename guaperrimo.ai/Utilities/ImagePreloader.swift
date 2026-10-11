//
//  ImagePreloader.swift
//  guaperrimo.ai
//

#if os(iOS)
import UIKit

actor ImagePreloader {
    static let shared = ImagePreloader()

    nonisolated(unsafe) private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 20
    }

    func preload(_ urlString: String) async -> UIImage? {
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached
        }

        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: urlString as NSString)
                return image
            } catch {
                return nil
            }
        }

        inFlight[urlString] = task
        let result = await task.value
        inFlight.removeValue(forKey: urlString)
        return result
    }

    func preloadAll(_ urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.preload(url)
                }
            }
        }
    }

    nonisolated func cachedImage(for urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }
}
#endif
