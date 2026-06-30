import Foundation

struct AppUpdateInfo {
    let version: String
    let url: URL
    let title: String?
    let notes: String?
}

enum AppUpdateCheckResult {
    case updateAvailable(AppUpdateInfo)
    case upToDate(latestVersion: String)
    case failed(String)
}

final class GitHubUpdateChecker {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: String
        let body: String?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case body
        }
    }

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/saierda990-jpg/kegel-flower/releases/latest")!

    func check(currentVersion: String, completion: @escaping (AppUpdateCheckResult) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KikuKegelUpdateChecker", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failed(error.localizedDescription))
                }
                return
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let data
            else {
                DispatchQueue.main.async {
                    completion(.failed("GitHub 暂时没有返回可用的版本信息。"))
                }
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                guard let url = URL(string: release.htmlURL) else {
                    DispatchQueue.main.async {
                        completion(.failed("最新版本链接无效。"))
                    }
                    return
                }

                let version = Self.normalizedVersionLabel(release.tagName)
                let info = AppUpdateInfo(
                    version: version,
                    url: url,
                    title: release.name,
                    notes: release.body
                )

                DispatchQueue.main.async {
                    if Self.isVersion(version, newerThan: currentVersion) {
                        completion(.updateAvailable(info))
                    } else {
                        completion(.upToDate(latestVersion: version))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failed(error.localizedDescription))
                }
            }
        }.resume()
    }

    static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        let lhs = versionComponents(latest)
        let rhs = versionComponents(current)
        let count = max(lhs.count, rhs.count)

        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }

        return false
    }

    static func normalizedVersionLabel(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }

    private static func versionComponents(_ version: String) -> [Int] {
        normalizedVersionLabel(version)
            .split { character in
                character == "." || character == "-" || character == "_"
            }
            .compactMap { part in
                let digits = part.prefix { $0.isNumber }
                return digits.isEmpty ? nil : Int(digits)
            }
    }
}
