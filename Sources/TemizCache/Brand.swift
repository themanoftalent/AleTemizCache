import Foundation

/// Developer and brand identity shown in the About panel, Settings and footer.
enum Brand {
    static let developer = "Mehmet Akif Cifci"
    static let identity = "TheManOfTalent"
    static let credit = "Developed by Mehmet Akif Cifci | TheManOfTalent"
    static let github = URL(string: "https://github.com/themanoftalent")!
    static let repository = URL(string: "https://github.com/themanoftalent/TemizCache")!

    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
