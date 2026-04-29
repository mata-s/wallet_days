//
//  QuicklyAdd.swift
//  QuicklyAdd
//
//  Created by 又吉真春 on 2026/04/20.
//



import WidgetKit
import SwiftUI

// Simple language helper
private func currentLang() -> String {
    return Locale.current.languageCode == "ja" ? "ja" : "en"
}

private func t(_ ja: String, _ en: String) -> String {
    return currentLang() == "ja" ? ja : en
}

private enum QuicklyAddDefaults {
    static var title: String { t("クイック追加", "Quick Add") }
    static var subtitle: String { t("支出をすぐ記録", "Log expenses instantly") }
    static var remainingTitle: String { t("今月あと", "Remaining this month") }
    static var amountLabel: String { t("タップして入力", "Tap to enter") }
    static let fallbackRemainingAmountText = "--"
    static let fallbackURLString = "walletdays://quick-add"
}

private enum QuicklyAddWidgetKeys {
    static let remainingBudget = "remaining_budget"
    static let totalBudget = "total_budget"
    static let remainingAmountText = "remaining_amount_text"
    static let amountLabel = "quick_add_amount_label"
    static let title = "quick_add_title"
    static let subtitle = "quick_add_subtitle"
    static let remainingTitle = "quick_add_remaining_title"
    static let url = "quick_add_url"
    static let danger1Name = "danger_category_1_name"
    static let danger1Remaining = "danger_category_1_remaining"
    static let danger1Badge = "danger_category_1_badge"
    static let danger2Name = "danger_category_2_name"
    static let danger2Remaining = "danger_category_2_remaining"
    static let danger2Badge = "danger_category_2_badge"
    static let danger1Budget = "danger_category_1_budget"
    static let danger2Budget = "danger_category_2_budget"
}

struct QuicklyAddDangerCategory {
    let name: String
    let remaining: Int
    let badge: String
    let budget: Int
}

struct QuicklyAddWidgetData {
    let title: String
    let subtitle: String
    let remainingTitle: String
    let remainingAmountText: String
    let remainingBudgetValue: Int?
    let totalBudgetValue: Int?
    let amountLabel: String
    let url: URL?
    let danger1: QuicklyAddDangerCategory?
    let danger2: QuicklyAddDangerCategory?

    static func load() -> QuicklyAddWidgetData {
        let defaults = sharedDefaults()

        let title = defaults?.string(forKey: QuicklyAddWidgetKeys.title)
            ?? QuicklyAddDefaults.title
        let subtitle = defaults?.string(forKey: QuicklyAddWidgetKeys.subtitle)
            ?? QuicklyAddDefaults.subtitle
        let remainingTitle = defaults?.string(forKey: QuicklyAddWidgetKeys.remainingTitle)
            ?? QuicklyAddDefaults.remainingTitle
        let amountLabel = defaults?.string(forKey: QuicklyAddWidgetKeys.amountLabel)
            ?? QuicklyAddDefaults.amountLabel

        let remainingBudgetValue = defaults?.object(forKey: QuicklyAddWidgetKeys.remainingBudget) as? Int
        let totalBudgetValue = defaults?.object(forKey: QuicklyAddWidgetKeys.totalBudget) as? Int

        let remainingAmountText: String
        if let remainingBudgetValue {
            if remainingBudgetValue < 0 {
                remainingAmountText = "\(formatMoney(0))（\(formatMoney(remainingBudgetValue))）"
            } else {
                remainingAmountText = formatMoney(remainingBudgetValue)
            }
        } else if let storedText = defaults?.string(forKey: QuicklyAddWidgetKeys.remainingAmountText),
                  !storedText.isEmpty {
            remainingAmountText = storedText
        } else {
            remainingAmountText = QuicklyAddDefaults.fallbackRemainingAmountText
        }

        let urlString = defaults?.string(forKey: QuicklyAddWidgetKeys.url)
            ?? QuicklyAddDefaults.fallbackURLString

        let danger1Name = defaults?.string(forKey: QuicklyAddWidgetKeys.danger1Name) ?? ""
        let danger1Remaining = defaults?.object(forKey: QuicklyAddWidgetKeys.danger1Remaining) as? Int ?? 0
        let danger1Badge = defaults?.string(forKey: QuicklyAddWidgetKeys.danger1Badge) ?? ""
        let danger1Budget = defaults?.object(forKey: QuicklyAddWidgetKeys.danger1Budget) as? Int ?? 0

        let danger2Name = defaults?.string(forKey: QuicklyAddWidgetKeys.danger2Name) ?? ""
        let danger2Remaining = defaults?.object(forKey: QuicklyAddWidgetKeys.danger2Remaining) as? Int ?? 0
        let danger2Badge = defaults?.string(forKey: QuicklyAddWidgetKeys.danger2Badge) ?? ""
        let danger2Budget = defaults?.object(forKey: QuicklyAddWidgetKeys.danger2Budget) as? Int ?? 0

        let danger1: QuicklyAddDangerCategory? = danger1Name.isEmpty
            ? nil
            : QuicklyAddDangerCategory(
                name: danger1Name,
                remaining: danger1Remaining,
                badge: danger1Badge,
                budget: danger1Budget
            )

        let danger2: QuicklyAddDangerCategory? = danger2Name.isEmpty
            ? nil
            : QuicklyAddDangerCategory(
                name: danger2Name,
                remaining: danger2Remaining,
                badge: danger2Badge,
                budget: danger2Budget
            )

        return QuicklyAddWidgetData(
            title: title,
            subtitle: subtitle,
            remainingTitle: remainingTitle,
            remainingAmountText: remainingAmountText,
            remainingBudgetValue: remainingBudgetValue,
            totalBudgetValue: totalBudgetValue,
            amountLabel: amountLabel,
            url: URL(string: urlString),
            danger1: danger1,
            danger2: danger2
        )
    }

    private static func sharedDefaults() -> UserDefaults? {
        guard let groupId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
              !groupId.isEmpty else {
            return nil
        }
        let defaults = UserDefaults(suiteName: groupId)
        return defaults
    }

    private static func formatMoney(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        if currentLang() == "ja" {
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "ja_JP")
            let value = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
            return "\(value)円"
        }

        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let dollars = Double(amount) / 100.0
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(String(format: "%.2f", dollars))"
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), widgetData: .load())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), widgetData: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), widgetData: .load())
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefreshDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let widgetData: QuicklyAddWidgetData
}

struct QuicklyAddEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.widgetData.remainingTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.widgetData.remainingAmountText)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if entry.widgetData.danger1 != nil || entry.widgetData.danger2 != nil {
                    Spacer()
                        .frame(height: 4)
                }

                if let danger1 = entry.widgetData.danger1 {
                    Text("\(danger1.badge.isEmpty ? "•" : danger1.badge) \(danger1.name) \(t("あと", "left "))\(formatMoney(danger1.remaining))")
                        .font(.caption2)
                        .foregroundStyle(dangerColor(danger1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let danger2 = entry.widgetData.danger2 {
                    Text("\(danger2.badge.isEmpty ? "•" : danger2.badge) \(danger2.name) \(t("あと", "left "))\(formatMoney(danger2.remaining))")
                        .font(.caption2)
                        .foregroundStyle(dangerColor(danger2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)
        }
        .widgetURL(entry.widgetData.url ?? URL(string: QuicklyAddDefaults.fallbackURLString))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(entry.widgetData.remainingTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.widgetData.remainingAmountText)
                    .font(.title.weight(.bold))
            }
            if let remaining = entry.widgetData.remainingBudgetValue,
               let total = entry.widgetData.totalBudgetValue {

                GeometryReader { geometry in
                    let ratio = remainingProgressRatio()
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.18))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(remainingBarColor())
                            .frame(width: max(geometry.size.width * ratio, ratio > 0 ? 10 : 0), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(formatMoney(total - remaining)) / \(formatMoney(total))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if let danger1 = entry.widgetData.danger1 {
                    Text("\(danger1.badge.isEmpty ? "•" : danger1.badge) \(danger1.name) \(t("あと", "left "))\(formatMoney(danger1.remaining)) \(Text("(\(formatPercent(danger1)))").foregroundStyle(dangerColor(danger1)))")
                        .font(.body)
                }

                if let danger2 = entry.widgetData.danger2 {
                    Text("\(danger2.badge.isEmpty ? "•" : danger2.badge) \(danger2.name) \(t("あと", "left "))\(formatMoney(danger2.remaining)) \(Text("(\(formatPercent(danger2)))").foregroundStyle(dangerColor(danger2)))")
                        .font(.body)
                }
            }

            Spacer()
        }
        .widgetURL(entry.widgetData.url ?? URL(string: QuicklyAddDefaults.fallbackURLString))
    }

    private func formatMoney(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        if currentLang() == "ja" {
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "ja_JP")
            let value = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
            return "\(value)円"
        }

        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let dollars = Double(amount) / 100.0
        return formatter.string(from: NSNumber(value: dollars)) ?? "$\(String(format: "%.2f", dollars))"
    }
    
    private func dangerColor(_ category: QuicklyAddDangerCategory) -> Color {
        if category.remaining < 0 {
            return .red
        }

        let ratio = Double(category.remaining) / Double(max(category.budget, 1))

        if ratio < 0.2 {
            return .orange
        }

        return .primary
    }

    private func formatPercent(_ category: QuicklyAddDangerCategory) -> String {
        guard category.budget > 0 else { return "0%" }
        let used = category.budget - category.remaining
        let ratio = Double(used) / Double(category.budget)
        let percent = Int(ratio * 100)
        return "\(percent)%"
    }

    private func remainingProgressRatio() -> CGFloat {
        guard let remaining = entry.widgetData.remainingBudgetValue else { return 0 }
        guard let total = entry.widgetData.totalBudgetValue, total > 0 else {
            return 0
        }

        let used = max(total - remaining, 0)
        let ratio = Double(used) / Double(total)
        return CGFloat(min(max(ratio, 0), 1))
    }

    private func remainingBarColor() -> Color {
        guard let remaining = entry.widgetData.remainingBudgetValue else {
            return .accentColor
        }
        if remaining < 0 {
            return .red
        }
        if remaining == 0 {
            return .orange
        }
        return .accentColor
    }
}

struct QuicklyAdd: Widget {
    let kind: String = "QuicklyAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                QuicklyAddEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuicklyAddEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("クイック追加")
        .description("今月あと使えるお金を表示して、タップですぐ支出追加へ移動します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    QuicklyAdd()
} timeline: {
    SimpleEntry(
        date: .now,
        widgetData: QuicklyAddWidgetData(
            title: "クイック追加",
            subtitle: "支出をすぐ記録",
            remainingTitle: "今月あと",
            remainingAmountText: "12,340円",
            remainingBudgetValue: 12340,
            totalBudgetValue: 50000,
            amountLabel: "タップして入力",
            url: URL(string: "walletdays://quick-add"),
            danger1: QuicklyAddDangerCategory(name: "食費", remaining: 3200, badge: "🍔", budget: 6400),
            danger2: QuicklyAddDangerCategory(name: "カフェ", remaining: 1100, badge: "☕️", budget: 2200)
        )
    )
}
