//
//  AskOpinionSheet.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// "Ask someone": he picks two looks, shares a link with people he trusts and
/// sees which one they recommend, with their reasons and comments.
struct AskOpinionSheet: View {
    @Bindable var viewModel: ConversationViewModel

    @State private var selected: [String] = []   // look ids, in tap order, at most two
    @State private var created: LookPoll? = nil

    private let refreshEvery: Duration = .seconds(10)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    Text(String(localized: "poll_intro"))
                        .font(.subheadline)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    picker

                    createOrShare

                    if let error = viewModel.pollError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(DS.danger)
                    }

                    if !viewModel.polls.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            sectionLabel(String(localized: "poll_results"))
                            ForEach(viewModel.polls) { poll in
                                PollResultCard(poll: poll)
                            }
                        }
                    }
                }
                .padding(DS.Space.m)
            }
            .refreshable { await viewModel.refreshPolls() }
            .background(DS.bg)
            .navigationTitle(String(localized: "poll_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(DS.bg)
        .onAppear(perform: preselect)
        .task {
            // Votes arrive while he waits: refresh while the sheet is open.
            while !Task.isCancelled {
                await viewModel.refreshPolls()
                try? await Task.sleep(for: refreshEvery)
            }
        }
    }

    // MARK: - Pick two looks

    @ViewBuilder private var picker: some View {
        let looks = viewModel.readyLooks
        VStack(alignment: .leading, spacing: DS.Space.s) {
            sectionLabel(String(localized: looks.count > 2 ? "poll_pick_two" : "poll_these_two"))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Space.s), count: looks.count > 2 ? 3 : 2), spacing: DS.Space.s) {
                ForEach(looks) { look in
                    let index = selected.firstIndex(of: look.id)
                    Button { toggle(look.id) } label: {
                        LookThumb(url: look.finalImageUrl, name: look.name, badge: index.map { letter($0) }, isSelected: index != nil)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(looks.count > 2) // with two looks there is nothing to pick
                    .accessibilityAddTraits(index != nil ? .isSelected : [])
                }
            }
        }
    }

    private func preselect() {
        guard selected.isEmpty else { return }
        var ids: [String] = []
        if let current = viewModel.currentLook { ids.append(current.id) }
        for look in viewModel.readyLooks where ids.count < 2 && !ids.contains(look.id) {
            ids.append(look.id)
        }
        selected = ids
    }

    private func toggle(_ id: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        created = nil
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
        } else {
            if selected.count == 2 { selected.removeFirst() }
            selected.append(id)
        }
    }

    // MARK: - Create, then share

    @ViewBuilder private var createOrShare: some View {
        if let poll = created, let url = URL(string: poll.url) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ShareLink(item: url, message: Text(String(localized: "poll_share_message"))) {
                    Label(String(localized: "poll_share"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(DS.onAccent)
                        .frame(maxWidth: .infinity, minHeight: DS.minTap)
                        .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.Radius.button))
                }
                Text(String(localized: "poll_link_ready"))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }
        } else {
            PrimaryButton(
                title: String(localized: viewModel.isCreatingPoll ? "poll_creating" : "poll_create"),
                systemImage: "link"
            ) {
                Task { created = await viewModel.createPoll(lookIds: selected) }
            }
            .disabled(selected.count != 2 || viewModel.isCreatingPoll)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(DS.Font.label)
            .tracking(DS.labelTracking)
            .foregroundStyle(DS.textSecondary)
    }
}

private func letter(_ index: Int) -> String { index == 0 ? "A" : "B" }

/// A rendered look as a 3:4 thumbnail.
private struct LookThumb: View {
    let url: String?
    let name: String
    var badge: String? = nil
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    DS.surfaceRaised
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m)
                    .stroke(isSelected ? DS.accent : DS.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge)
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.onAccent)
                        .frame(width: 26, height: 26)
                        .background(DS.accent, in: Circle())
                        .padding(DS.Space.xs)
                }
            }
            Text(name)
                .font(.caption)
                .foregroundStyle(isSelected ? DS.textPrimary : DS.textSecondary)
                .lineLimit(1)
        }
    }
}

/// Results of one poll: votes per look, top reasons and what people said.
private struct PollResultCard: View {
    let poll: LookPoll

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            HStack {
                Text(votesText(poll.totalVotes))
                    .font(DS.Font.mono)
                    .foregroundStyle(DS.textPrimary)
                Text("·").foregroundStyle(DS.textTertiary)
                Text(String(localized: poll.open ? "poll_open" : "poll_closed"))
                    .font(.footnote)
                    .foregroundStyle(poll.open ? DS.success : DS.textTertiary)
                Spacer()
                if poll.open, let url = URL(string: poll.url) {
                    ShareLink(item: url, message: Text(String(localized: "poll_share_message"))) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(DS.textPrimary)
                            .frame(width: DS.minTap, height: DS.minTap)
                    }
                    .accessibilityLabel(String(localized: "poll_share_again"))
                }
            }

            HStack(alignment: .top, spacing: DS.Space.s) {
                ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                    optionColumn(option, index: index)
                }
            }

            if poll.totalVotes == 0 {
                Text(String(localized: "poll_no_votes"))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    ForEach(Array(poll.votes.enumerated()), id: \.offset) { _, vote in
                        voteRow(vote)
                    }
                }
            }
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.l))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.l).stroke(DS.stroke, lineWidth: 1))
    }

    private func optionColumn(_ option: LookPollOption, index: Int) -> some View {
        let isLeader = poll.leader == index
        let share = poll.totalVotes > 0 ? Double(option.voteCount) / Double(poll.totalVotes) : 0
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            LookThumb(url: option.imageUrl, name: "\(letter(index)) · \(option.name)", isSelected: isLeader)
                .overlay(alignment: .topTrailing) {
                    if isLeader {
                        Text(String(localized: "poll_favorite"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DS.onAccent)
                            .padding(.horizontal, DS.Space.xs)
                            .padding(.vertical, DS.Space.xxs)
                            .background(DS.accent, in: Capsule())
                            .padding(DS.Space.xs)
                    }
                }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.stroke)
                    Capsule().fill(DS.accent).frame(width: geo.size.width * share)
                }
            }
            .frame(height: 6)
            Text("\(votesText(option.voteCount)) · \(Int((share * 100).rounded()))%")
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.textSecondary)
            ForEach(option.reasons.prefix(2), id: \.id) { reason in
                Text("\(reason.label) (\(reason.count))")
                    .font(.caption2)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func voteRow(_ vote: LookPollVote) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(String(format: String(localized: "poll_picked"), vote.voterName ?? String(localized: "poll_someone"), letter(vote.choice)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
            if let comment = vote.comment, !comment.isEmpty {
                Text("“\(comment)”")
                    .font(.subheadline)
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !vote.reasons.isEmpty {
                Text(vote.reasons.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Space.xs)
        .overlay(alignment: .top) { Rectangle().fill(DS.stroke).frame(height: 1) }
    }

    private func votesText(_ count: Int) -> String {
        count == 1 ? String(localized: "poll_vote_one") : String(format: String(localized: "poll_votes"), count)
    }
}
#endif
