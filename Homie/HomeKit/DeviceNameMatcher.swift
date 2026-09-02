import Foundation

func deviceNameMatches(query: String, candidate: String) -> Bool {
    let normalizedQuery = normalizeDeviceName(query)
    let normalizedCandidate = normalizeDeviceName(candidate)
    guard !normalizedQuery.isEmpty else { return false }

    if normalizedCandidate.contains(normalizedQuery) {
        return true
    }

    let queryWords = normalizedQuery.split(separator: " ")
    let candidateWords = normalizedCandidate.split(separator: " ")
    return queryWords.allSatisfy { queryWord in
        candidateWords.contains { candidateWord in
            candidateWord.contains(queryWord)
        }
    }
}

func closestDeviceName(to query: String, in candidates: [String]) -> String? {
    let normalizedQuery = normalizeDeviceName(query)
    guard !normalizedQuery.isEmpty else { return nil }

    return candidates.min { lhs, rhs in
        levenshteinDistance(normalizedQuery, normalizeDeviceName(lhs))
            < levenshteinDistance(normalizedQuery, normalizeDeviceName(rhs))
    }
}

func normalizeDeviceName(_ value: String) -> String {
    value
        .replacingOccurrences(of: "_", with: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
    let left = Array(lhs)
    let right = Array(rhs)
    var previous = Array(0...right.count)

    for (leftIndex, leftCharacter) in left.enumerated() {
        var current = [leftIndex + 1]
        current.reserveCapacity(right.count + 1)

        for (rightIndex, rightCharacter) in right.enumerated() {
            let insertion = current[rightIndex] + 1
            let deletion = previous[rightIndex + 1] + 1
            let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
            current.append(min(insertion, deletion, substitution))
        }

        previous = current
    }

    return previous[right.count]
}
