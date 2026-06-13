import SwiftUI
import StoreKit

// MARK: - Plan定義（アイコン・グラデーション）
private extension SubscriptionPlan {
    var icon: String {
        switch self {
        case .free: return "leaf.fill"
        case .pro:  return "bolt.fill"
        case .manager: return "briefcase.fill"
        case .team: return "person.3.fill"
        case .max:  return "crown.fill"
        case .organization: return "building.fill"
        case .enterprise: return "building.2.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .free: return [Color(hex: "5E6C84"), Color(hex: "3A4255")]
        case .pro:  return [Color(hex: "5B8DEF"), Color(hex: "3563C3")]
        case .manager: return [Color(hex: "7B2FBE"), Color(hex: "C77DFF")]
        case .team: return [Color(hex: "10B981"), Color(hex: "065F46")]
        case .max:  return [Color(hex: "F59E0B"), Color(hex: "B45309")]
        case .organization: return [Color(hex: "6366F1"), Color(hex: "4338CA")]
        case .enterprise: return [Color(hex: "8B5CF6"), Color(hex: "5B21B6")]
        }
    }

    var accentColor: Color { gradientColors[0] }

    var tagline: String {
        switch self {
        case .free: return "まずは基本機能から".localized
        case .pro:  return "競技力向上をサポート".localized
        case .manager: return "マネージャー機能とPro機能".localized
        case .team: return "チーム全員で使える".localized
        case .max:  return "プロコーチのための最高峰".localized
        case .organization: return "中〜大規模チームで共有して使う".localized
        case .enterprise: return "大規模チーム・団体向け".localized
        }
    }

    /// サブスクリプション期間の表示テキスト（Guideline 3.1.2(c)準拠）
    var periodString: String {
        switch self {
        case .free: return "無料"
        case .pro, .manager, .team, .max, .organization, .enterprise: return "月額（毎月自動更新）"
        }
    }

    var allFeatures: [(String, Bool)] {
        let all: [(String, [SubscriptionPlan])] = [
            ("潮汐情報の確認".localized,                 [.free, .pro, .team, .max, .manager, .organization, .enterprise]),
            ("GPSレート計".localized,                    [.free, .pro, .team, .max, .manager, .organization, .enterprise]),
            ("PM5との1:1接続".localized,                [.free, .pro, .team, .max, .manager, .organization, .enterprise]),
            ("リギングの管理".localized,                 [.free, .pro, .team, .max, .manager, .organization, .enterprise]),
            ("iCloudバックアップ".localized,             [.free, .pro, .team, .max, .manager, .organization, .enterprise]),
            ("Force Curve の表示".localized,             [.pro, .team, .max, .manager, .organization, .enterprise]),
            ("ゴーストレース機能".localized,             [.pro, .team, .max, .manager, .organization, .enterprise]),
            ("Strava同期 (準備中)".localized,            [.pro, .team, .max, .manager, .organization, .enterprise]),
            ("PM5 複数台同時接続".localized,             [.team, .max, .organization, .manager, .enterprise]),
            ("リアルタイム一斉トレーニング".localized,    [.team, .max, .organization, .manager, .enterprise]),
            ("マネージャープランの共有 (3名)".localized,    [.team]),
            ("マネージャープランの共有 (5名)".localized,    [.max]),
            ("マネージャープランの共有 (最大10名)".localized, [.organization]),
            ("メンバー管理 (最大30名)".localized,         [.team]),
            ("メンバー管理 (最大50名)".localized,         [.max]),
            ("メンバー管理 (最大200名)".localized,        [.organization]),
            ("管理者の指定 (3名)".localized,             [.max]),
            ("管理者の指定 (7名)".localized,             [.organization]),
            ("AIとテンプレート型の分析機能 (準備中)".localized, [.team]),
            ("AIと対話型の分析機能 (準備中)".localized,    [.max]),
            ("AIと対話型の分析機能".localized,            [.organization]),
            ("CSV形式での記録出力".localized,             [.max, .organization, .enterprise]),
            ("レースビュー (高度な可視化)".localized,     [.max, .organization, .enterprise]),
        ]
        return all
            .filter { item in
                let name = item.0
                if self == .team {
                    return !name.contains("共有 (5名)") && !name.contains("共有 (最大10名)") &&
                           !name.contains("メンバー管理 (最大50名)") && !name.contains("メンバー管理 (最大200名)") &&
                           !name.contains("管理者の指定") && !name.contains("対話型の分析機能")
                } else if self == .max {
                    return !name.contains("共有 (3名)") && !name.contains("共有 (最大10名)") &&
                           !name.contains("メンバー管理 (最大30名)") && !name.contains("メンバー管理 (最大200名)") &&
                           !name.contains("管理者の指定 (7名)") && !name.contains("テンプレート型") &&
                           name != "AIと対話型の分析機能".localized
                } else if self == .organization {
                    return !name.contains("共有 (3名)") && !name.contains("共有 (5名)") &&
                           !name.contains("メンバー管理 (最大30名)") && !name.contains("メンバー管理 (最大50名)") &&
                           !name.contains("管理者の指定 (3名)") && !name.contains("テンプレート型") &&
                           !name.contains("(準備中)")
                } else {
                    return !name.contains("共有 (") && !name.contains("メンバー管理") && !name.contains("管理者の指定") && !name.contains("分析機能")
                }
            }
            .map { ($0.0, $0.1.contains(self)) }
    }
}

// MARK: - Main Subscription View
struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subManager = SubscriptionManager.shared

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // ── ヘッダー ──
                    headerSection

                    // ── 現在のプラン情報 ──
                    currentPlanCard

                    // ── プランカードリスト ──
                    plansSection
                        .padding(.bottom, 8)

                    // ── Guideline 3.1.2(c): Privacy Policy & Terms of Use ──
                    legalLinksSection
                        .padding(.bottom, 48)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Subscriptions".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Restore".localized) {
                    Task {
                        await subManager.restorePurchases()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done".localized) { dismiss() }
            }
        }
        .onAppear {
            subManager.checkSubscriptionStatus()
            if subManager.products.isEmpty {
                Task {
                    await subManager.loadProducts()
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.bottom, -45)
                .padding(.top, -40)

            Text("RowPilot プランを選ぶ".localized)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("あなたのトレーニングを、次のステージへ。".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Current Plan Card
    private var currentPlanCard: some View {
        let plan = subManager.currentPlan
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: plan.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: plan.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("現在のプラン".localized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.55))
                    Text(plan.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                if subManager.isSharedManagerPlan {
                    Label("共有プラン".localized, systemImage: "person.2.fill")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(plan.accentColor.opacity(0.2))
                        .foregroundColor(plan.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(16)

            if let expDate = subManager.expiresAt {
                Divider().background(Color.white.opacity(0.1))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("有効期限".localized)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        Text(expDate, style: .date)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("自動更新".localized)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Circle()
                                .fill(subManager.autoRenew ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                            Text(subManager.autoRenew ? "有効" : "停止")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(subManager.autoRenew ? .green : .red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if subManager.currentPlan == .team || subManager.currentPlan == .max || subManager.currentPlan == .organization {
                Divider().background(Color.white.opacity(0.1))
                NavigationLink(destination: TeamMaxManagerView()) {
                    HStack {
                        Image(systemName: "person.3.sequence.fill")
                            .foregroundColor(plan.accentColor)
                        Text("共有メンバーを管理".localized)
                            .fontWeight(.bold)
                            .foregroundColor(plan.accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().background(Color.white.opacity(0.1))
                NavigationLink(destination: TeamDashboardView()) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.green)
                        Text("メンバーを管理".localized)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(colors: plan.gradientColors.map { $0.opacity(0.5) },
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
        .shadow(color: plan.accentColor.opacity(0.2), radius: 12, x: 0, y: 4)
    }

    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 12) {
            // 商品取得中の表示
            if subManager.isLoadingProducts {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("価格情報を取得中...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // 商品取得エラー時の表示
            if let errorMsg = subManager.productsLoadError, !subManager.isLoadingProducts {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("価格情報の取得に失敗しました")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text(errorMsg)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Button(action: {
                        Task { await subManager.loadProducts() }
                    }) {
                        Label("再試行", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
            }

            SectionLabel(text: "Individual")
            PlanCard(plan: .free, currentPlan: subManager.currentPlan)
            PlanCard(plan: .pro,  currentPlan: subManager.currentPlan)

            SectionLabel(text: "For Manager")
                .padding(.top, 8)
            PlanCard(plan: .manager, currentPlan: subManager.currentPlan)

            SectionLabel(text: "For Team")
                .padding(.top, 8)
            PlanCard(plan: .team, currentPlan: subManager.currentPlan)
            PlanCard(plan: .max,  currentPlan: subManager.currentPlan)

            SectionLabel(text: "For Organization")
                .padding(.top, 8)
            PlanCard(plan: .organization, currentPlan: subManager.currentPlan)

            SectionLabel(text: "Enterprise")
                .padding(.top, 8)
            PlanCard(plan: .enterprise, currentPlan: subManager.currentPlan)
        }
    }

    // MARK: - Legal Links (Guideline 3.1.2(c))
    private var legalLinksSection: some View {
        VStack(spacing: 10) {
            Text("サブスクリプションについて".localized)
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.35))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("サブスクリプションは購入確認後、Apple IDアカウントに課金されます。サブスクリプションは現在の期間終了の24時間以上前にキャンセルしない限り自動更新されます。")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://rowpilot.jp/privacy-policy")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                        Text("Privacy Policy")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "5B8DEF"))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 14)

                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("Terms of Use")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "5B8DEF"))
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Section Label
private struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.leading, 4)
    }
}

// MARK: - Plan Card
private struct PlanCard: View {
    let plan: SubscriptionPlan
    let currentPlan: SubscriptionPlan
    var isSelected: Bool { currentPlan == plan }
    
    private var priceDisplay: String {
        if let productId = plan.productId,
           let product = SubscriptionManager.shared.products.first(where: { $0.id == productId }) {
            return product.displayPrice
        }
        return plan.priceString.localized
    }

    var body: some View {
        NavigationLink(destination: SubscriptionDetailView(plan: plan)) {
            HStack(spacing: 14) {
                // アイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(colors: plan.gradientColors,
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: plan.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: plan.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)

                // テキスト
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(plan.tagline)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                // 金額 + 矢印
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceDisplay)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(plan.accentColor)
                    if isSelected {
                        Label("利用中".localized, systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(14)
            .background(
                isSelected
                    ? LinearGradient(colors: plan.gradientColors.map { $0.opacity(0.15) },
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.03)],
                                     startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? plan.accentColor.opacity(0.6) : Color.white.opacity(0.07), lineWidth: 1.2)
            )
            .shadow(color: isSelected ? plan.accentColor.opacity(0.15) : .clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Detail View
struct SubscriptionDetailView: View {
    let plan: SubscriptionPlan
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subManager = SubscriptionManager.shared
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""

    var isSelected: Bool { subManager.currentPlan == plan }

    /// StoreKit から取得した Product（あれば）
    private var storeProduct: Product? {
        guard let productId = plan.productId else { return nil }
        return subManager.products.first(where: { $0.id == productId })
    }

    private var priceDisplay: String {
        if let product = storeProduct {
            return product.displayPrice
        }
        return plan.priceString.localized
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── ヒーローヘッダー ──
                    heroHeader

                    // ── サブスクリプション詳細（Guideline 3.1.2(c)）──
                    subscriptionInfoSection

                    // ── 概要説明 ──
                    descriptionSection

                    // ── 機能チェックリスト ──
                    featuresSection

                    Spacer(minLength: 32)

                    // ── アクションボタン ──
                    actionArea

                    // ── Legal Links（Guideline 3.1.2(c)）──
                    detailLegalSection
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(plan.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Authentication Error".localized, isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage)
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: plan.gradientColors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: plan.accentColor.opacity(0.5), radius: 12, x: 0, y: 5)
                Image(systemName: plan.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.displayName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(plan.tagline)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                Text(priceDisplay)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(colors: plan.gradientColors,
                                       startPoint: .leading, endPoint: .trailing)
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Subscription Info (Guideline 3.1.2(c): 名称・期間・価格)
    private var subscriptionInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("プラン詳細".localized)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                infoRow(label: "サブスクリプション名", value: plan.displayName)
                Divider().background(Color.white.opacity(0.08))
                infoRow(label: "期間", value: plan.periodString)
                if plan != .free && plan != .enterprise {
                    Divider().background(Color.white.opacity(0.08))
                    // 商品取得中・取得済みで表示を変える
                    if subManager.isLoadingProducts {
                        HStack {
                            Text("価格")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.55))
                            Spacer()
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    } else {
                        infoRow(label: "価格", value: priceDisplay, valueColor: plan.accentColor)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func infoRow(label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Description
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("プランについて".localized)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)

            Text(planDescriptionText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var planDescriptionText: String {
        switch plan {
        case .free:
            return "RowPilotの中核となる基本的な機能を使用できます。潮汐情報の確認やGPSレート計、PM5との1:1接続など、日常のトレーニングに必要な機能を揃えています。".localized
        case .pro:
            return "ForceCurveの可見化やゴーストレース機能、Stravaとの連携（準備中）など、より深いパフォーマンス分析が可能になります。個人アスリートに最適なプランです。".localized
        case .manager:
            return "Proプランのすべての機能に加え、PM5との複数接続やマネージャーモードといった、管理者・コーチ向けの高度な機能を利用可能にするプランです。".localized
        case .team:
            return "最大3人に「RowPilot Manager」を共有でき、最大30人のメンバーをまとめて管理できます。さらに、AIとテンプレート型の分析機能（準備中）が利用可能です。".localized
        case .max:
            return "最大5人に「RowPilot Manager」を共有でき、最大3人を管理者として指定、最大50人をメンバーとして追加できます。さらに、AIと対話型の分析機能（準備中）が追加されます。".localized
        case .organization:
            return "最大10人に「RowPilot Manager」を共有でき、最大7人の管理者として指定、最大200人をメンバーとして追加できます。さらに、AIと対話型の分析機能が利用可能です。".localized
        case .enterprise:
            return "お問い合わせください。".localized
        }
    }

    // MARK: - Features List
    @ViewBuilder
    private var featuresSection: some View {
        if plan != .enterprise {
            VStack(alignment: .leading, spacing: 10) {
                Text("含まれる機能".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)

                VStack(spacing: 0) {
                    ForEach(Array(plan.allFeatures.enumerated()), id: \.offset) { idx, item in
                        let (name, included) = item
                        HStack(spacing: 12) {
                            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(included ? plan.accentColor : Color.white.opacity(0.2))

                            Text(name)
                                .font(.subheadline)
                                .foregroundColor(included ? .white.opacity(0.9) : .white.opacity(0.25))

                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .background(idx % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Action Area
    @ViewBuilder
    private var actionArea: some View {
        if !isSelected {
            if plan == .enterprise {
                Button(action: contactEnterprise) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.headline)
                        Text("お問い合わせ".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: plan.gradientColors,
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: plan.accentColor.opacity(0.4), radius: 12, x: 0, y: 5)
                }
            } else if plan == .free {
                // Freeプランは購入ボタン不要
                EmptyView()
            } else {
                VStack(spacing: 12) {
                    // 商品取得中のローディング
                    if subManager.isLoadingProducts {
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(plan.accentColor)
                            Text("価格情報を取得中...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else if let product = storeProduct {
                        // StoreKit商品が取得できている場合 → 購入ボタン表示
                        Button(action: { purchase(product: product) }) {
                            HStack(spacing: 10) {
                                if subManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: plan.icon)
                                        .font(.headline)
                                }
                                Text(subManager.isPurchasing ? "購入処理中..." : "\(plan.displayName) を購入 — \(priceDisplay)/月")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                subManager.isPurchasing
                                    ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: plan.gradientColors,
                                                     startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: plan.accentColor.opacity(0.4), radius: 12, x: 0, y: 5)
                        }
                        .disabled(subManager.isPurchasing)
                        .id("purchase_button_\(plan.rawValue)")

                    } else if subManager.productsLoadError != nil {
                        // 商品取得エラー時 → 再試行ボタン
                        Button(action: { Task { await subManager.loadProducts() } }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("価格情報を再取得")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    } else {
                        // 商品IDはあるがproductsが空（Sandbox未設定など）
                        Button(action: { purchase(product: nil) }) {
                            HStack(spacing: 10) {
                                Image(systemName: plan.icon)
                                    .font(.headline)
                                Text("\(plan.displayName) を購入")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: plan.gradientColors,
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: plan.accentColor.opacity(0.4), radius: 12, x: 0, y: 5)
                        }
                        .id("purchase_button_fallback_\(plan.rawValue)")
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text("現在ご利用中のプランです".localized)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )

                if plan != .free {
                    if subManager.autoRenew {
                        Button(action: {
                            withAnimation {
                                subManager.cancelSubscription()
                            }
                        }) {
                            Text("自動更新をキャンセル".localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                )
                        }
                        Text("キャンセル後も有効期限まで利用できます。".localized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 6) {
                            Label("自動更新は停止されています".localized, systemImage: "arrow.counterclockwise.circle")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            if let exp = subManager.expiresAt {
                                Text("有効期限: \(exp.formatted(date: .abbreviated, time: .shortened)) に終了予定")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Detail Legal Section (Guideline 3.1.2(c))
    private var detailLegalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plan != .free && plan != .enterprise {
                Text("サブスクリプションは購入確認後、Apple IDアカウントに課金されます。現在の期間終了の24時間以上前にキャンセルしない限り自動更新されます。購入後は「設定 > Apple ID > サブスクリプション」からいつでも管理・キャンセルできます。")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://rowpilot.jp/privacy-policy")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield")
                            .font(.caption2)
                        Text("Privacy Policy")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "5B8DEF"))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 14)

                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("Terms of Use (EULA)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "5B8DEF"))
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Purchase Logic
    private func purchase(product: Product?) {
        print("[StoreKit] Purchase button tapped — plan: \(plan.displayName)")

        guard let product = product else {
            // StoreKit productが取得できていない場合のフォールバック
            print("[StoreKit] ⚠️ No StoreKit product found for plan: \(plan.rawValue). Attempting to reload products.")
            authErrorMessage = "商品情報が見つかりません。ネットワーク接続を確認して再度お試しください。"
            showingAuthError = true
            Task { await subManager.loadProducts() }
            return
        }

        Task {
            do {
                let success = try await subManager.purchase(product)
                if success {
                    await MainActor.run {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    print("[StoreKit] ❌ Purchase failed: \(error.localizedDescription)")
                    authErrorMessage = error.localizedDescription
                    showingAuthError = true
                }
            }
        }
    }

    private func contactEnterprise() {
        let email = "rowpilot.jp@gmail.com"
        let subject = "RowPilot Enterpriseプランについてのお問い合わせ".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "RowPilot Enterpriseプランについて、以下の内容でお問い合わせします。\n\n・チーム名:\n・ご利用予定人数:\n・お問い合わせ内容:\n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
