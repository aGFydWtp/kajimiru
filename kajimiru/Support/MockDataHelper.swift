import Foundation
import KajimiruKit

/// Helper to create MVP mock data matching product spec.
struct MockDataHelper {
    static let userId = UUID()

    static func createMVPData() -> (group: Group, members: [Member], chores: [Chore], logs: [ChoreLog]) {
        // デフォルトのメンバー作成
        let tarou = Member(
            userId: nil,
            displayName: "たろう",
            avatarURL: nil,
            createdBy: userId,
            updatedBy: userId
        )

        let hanako = Member(
            userId: nil,
            displayName: "はなこ",
            avatarURL: nil,
            createdBy: userId,
            updatedBy: userId
        )

        let members = [tarou, hanako]

        // デフォルトのグループ作成
        let group = Group(
            name: "自宅",
            icon: "house.fill",
            members: members,
            createdBy: userId,
            updatedBy: userId
        )

        // サンプル家事
        let chores = [
            Chore(
                groupId: group.id,
                title: "食器洗い",
                weight: 2,
                notes: "食後の食器を洗う",
                createdBy: userId,
                updatedBy: userId
            ),
            Chore(
                groupId: group.id,
                title: "掃除機がけ",
                weight: 3,
                notes: "リビングと寝室",
                createdBy: userId,
                updatedBy: userId
            ),
            Chore(
                groupId: group.id,
                title: "ゴミ出し",
                weight: 1,
                notes: "燃えるゴミ",
                createdBy: userId,
                updatedBy: userId
            ),
            Chore(
                groupId: group.id,
                title: "洗濯",
                weight: 2,
                createdBy: userId,
                updatedBy: userId
            ),
            Chore(
                groupId: group.id,
                title: "お風呂掃除",
                weight: 5,
                notes: "浴槽とカビ取り",
                createdBy: userId,
                updatedBy: userId
            )
        ]

        // サンプルログ（過去1週間分）
        let now = Date()
        let calendar = Calendar.current
        var logs: [ChoreLog] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            // 1日に1-3個のランダムな家事ログ
            let numLogs = Int.random(in: 1...3)
            for logIndex in 0..<numLogs {
                let chore = chores.randomElement()!

                // 30%の確率で二人一緒にやったログを作成
                if logIndex == 0 && Bool.random() && Bool.random() {
                    // 二人で一緒にやった場合
                    let batchId = UUID()
                    let weightPerPerson = Double(chore.weight) / 2.0
                    let logTime = calendar.date(byAdding: .hour, value: -Int.random(in: 8...20), to: date) ?? date

                    for member in members {
                        logs.append(ChoreLog(
                            choreId: chore.id,
                            groupId: group.id,
                            performerId: member.id,
                            weight: weightPerPerson,
                            batchId: batchId,
                            performerCount: 2,
                            createdAt: logTime,
                            createdBy: userId,
                            updatedAt: logTime,
                            updatedBy: userId
                        ))
                    }
                } else {
                    // 一人でやった場合
                    let performer = members.randomElement()!
                    let logTime = calendar.date(byAdding: .hour, value: -Int.random(in: 8...20), to: date) ?? date

                    logs.append(ChoreLog(
                        choreId: chore.id,
                        groupId: group.id,
                        performerId: performer.id,
                        weight: Double(chore.weight),
                        createdAt: logTime,
                        createdBy: userId,
                        updatedAt: logTime,
                        updatedBy: userId
                    ))
                }
            }
        }

        return (group, members, chores, logs)
    }
}
