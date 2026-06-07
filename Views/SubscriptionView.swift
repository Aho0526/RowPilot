import SwiftUI
import LocalAuthentication

// MARK: - Plan定義（アイコン・グラデーション）
private extension SubscriptionPlan {
    var icon: String {
        switch self {
        case .free: return "leaf.fill"
        case .pro:  return "bolt.fill"
        case .team: return "person.3.fill"
        case .max:  return "crown.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .free: return [Color(hex: "5E6C84"), Color(hex: "3A4255")]
        case .pro:  return [Color(hex: "5B8DEF"), Color(hex: "3563C3")]
        case .team: return [Color(hex: "10B981"), Color(hex: "065F46")]
        case .max:  return [Color(hex: "F59E0B"), Color(hex: "B45309")]
        }
    }

    var accentColor: Color { gradientColors[0] }

    var tagline: String {
        switch self {
        case .free: return "まずは基本機能から".localized
        case .pro:  return "競技力向上をサポート".localized
        case .team: return "チーム全員で使える".localized
        case .max:  return "プロコーチのための最高峰".localized
        }
    }

    var allFeatures: [(String, Bool)] {
        let all: [(String, [SubscriptionPlan])] = [
            ("潮汐情報の確認".localized,                 [.free, .pro, .team, .max]),
            ("GPSレート計".localized,                    [.free, .pro, .team, .max]),
            ("PM5との1:1接続".localized,                [.free, .pro, .team, .max]),
            ("リギングの管理".localized,                 [.free, .pro, .team, .max]),
            ("Force Curve の表示".localized,             [.pro, .team, .max]),
            ("ゴーストレース機能".localized,             [.pro, .team, .max]),
            ("Strava同期 (準備中)".localized,            [.pro, .team, .max]),
            ("PM5 複数台同時接続".localized,             [.team, .max]),
            ("リアルタイム一斉トレーニング".localized,    [.team, .max]),
            ("プランの共有 (最大3名)".localized,         [.team]),
            ("プランの共有 (最大5名)".localized,         [.max]),
            ("CSV形式での記録出力".localized,             [.max]),
            ("レースビュー (高度な可視化)".localized,     [.max]),
        ]
        return all
            .filter { item in
                let name = item.0
                if self == .max {
                    return name != "プランの共有 (最大3名)"
                } else {
                    return name != "プランの共有 (最大5名)"
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
                        .padding(.bottom, 48)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Subscriptions".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done".localized) { dismiss() }
            }
        }
        .onAppear {
            subManager.checkSubscriptionStatus()
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

            if subManager.currentPlan == .team || subManager.currentPlan == .max {
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
            SectionLabel(text: "individual")
            PlanCard(plan: .free, currentPlan: subManager.currentPlan)
            PlanCard(plan: .pro,  currentPlan: subManager.currentPlan)

            SectionLabel(text: "For Teams")
                .padding(.top, 8)
            PlanCard(plan: .team, currentPlan: subManager.currentPlan)

            SectionLabel(text: "For Group, Advanced team")
                .padding(.top, 8)
            PlanCard(plan: .max,  currentPlan: subManager.currentPlan)
        }
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
                    Text(plan.priceString)
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

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // ── ヒーローヘッダー ──
                    heroHeader

                    // ── 概要説明 ──
                    descriptionSection

                    // ── 機能チェックリスト ──
                    featuresSection

                    Spacer(minLength: 32)

                    // ── アクションボタン ──
                    actionArea
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
                Text(plan.priceString)
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
            return "ForceCurveの可視化やゴーストレース機能、Stravaとの連携（準備中）など、より深いパフォーマンス分析が可能になります。個人アスリートに最適なプランです。".localized
        case .team:
            return "PM5複数台同時接続機能に加え、最大3名のメンバーにプランを共有できます。チーム全員でデータを共有し、練習の効率化と記録管理を一元化できます。".localized
        case .max:
            return "最大5名のメンバーへのプラン共有に加え、CSV形式での記録出力や高度なレースビュー、グラフィカルなアナリティクスを開放します。プロコーチ・エリートチームのためのプランです。".localized
        }
    }

    // MARK: - Features List
    private var featuresSection: some View {
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

    // MARK: - Action Area
    @ViewBuilder
    private var actionArea: some View {
        if !isSelected {
            Button(action: purchase) {
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

    private func purchase() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: "Confirm your subscription purchase.".localized) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation { subManager.purchasePlan(plan) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
                    } else if let e = authError as? LAError, e.code != .userCancel {
                        authErrorMessage = e.localizedDescription
                        showingAuthError = true
                    }
                }
            }
        } else {
            withAnimation { subManager.purchasePlan(plan) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
