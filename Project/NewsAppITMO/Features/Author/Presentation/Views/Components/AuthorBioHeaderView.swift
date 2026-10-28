import SwiftUI

struct AuthorBioHeaderView: View {
    let author: AuthorModel
    let imageCache: any ImageCache

    var body: some View {
        VStack(spacing: 14) {
            avatar

            VStack(spacing: 4) {
                Text(author.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("author-profile-name")

                Text("@\(author.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let bio = author.bio {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasDetails {
                details
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }

    private var hasDetails: Bool {
        author.location != nil || author.websiteURL != nil || author.joinedAt != nil
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let location = author.location {
                Label(location, systemImage: "mappin.and.ellipse")
            }

            if let websiteURL = author.websiteURL {
                Link(destination: websiteURL) {
                    Label(displayAddress(of: websiteURL), systemImage: "link")
                }
            }

            if let joinedAt = author.joinedAt {
                Label {
                    Text("На DEV с \(joinedAt, format: .dateTime.day().month(.wide).year())")
                } icon: {
                    Image(systemName: "calendar")
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var avatar: some View {
        Circle()
            .fill(.quaternary)
            .overlay {
                CachedAsyncImage(url: author.avatarURL, imageCache: imageCache) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty where author.avatarURL != nil:
                        ProgressView()
                    default:
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func displayAddress(of url: URL) -> String {
        let address = (url.host() ?? url.absoluteString) + url.path()
        return address.hasSuffix("/") ? String(address.dropLast()) : address
    }
}
