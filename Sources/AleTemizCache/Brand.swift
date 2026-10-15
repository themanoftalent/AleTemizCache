import Foundation

/// Product, brand and developer identity shown in the About panel, Settings and sidebar.
enum Brand {
    static let appName = "AleTemizCache"
    static let brand = "AleTemizCache"
    static let logoText = "Ale"
    static let developer = "Mehmet Akif Cifci"
    static let identity = "TheManOfTalent"
    static let credit = "Developed by Mehmet Akif Cifci | TheManOfTalent"
    static let github = URL(string: "https://github.com/themanoftalent")!
    static let repository = URL(string: "https://github.com/themanoftalent/AleTemizCache")!

    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
