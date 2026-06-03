import SwiftUI
import LocalAuthentication

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subManager = SubscriptionManager.shared
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Upgrade RowPilot".localized)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Unlock premium features and reach your potential.".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Current Plan Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT PLAN".localized)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(subManager.currentPlan.displayName)
                                    .font(.headline)
                                    .foregroundColor(Theme.accent)
                            }
                            Spacer()
                            
                            if subManager.isSharedManagerPlan {
                                Text("Shared Plan".localized)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.2))
                                    .foregroundColor(Theme.accent)
                                    .cornerRadius(6)
                            }
                        }
                        
                        if let expDate = subManager.expirationDate {
                            Divider().background(Color.white.opacity(0.2))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Expiration Date".localized)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(expDate, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Auto Renew".localized)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(subManager.isAutoRenew ? "Enabled".localized : "Disabled".localized)
                                        .font(.subheadline)
                                        .foregroundColor(subManager.isAutoRenew ? .green : .red)
                                }
                            }
                        }
                        
                        // Team, MAX の場合は共有管理ページへのリンクを追加
                        if subManager.currentPlan == .team || subManager.currentPlan == .max {
                            Divider().background(Color.white.opacity(0.2))
                            NavigationLink(destination: TeamMaxManagerView()) {
                                HStack {
                                    Image(systemName: "person.3.sequence.fill")
                                    Text("Manage Teammates".localized)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.accent)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // Plans List
                    VStack(spacing: 16) {
                        // Individual Plans
                        PlanSectionHeader(title: "Individual".localized)
                        SubscriptionCard(plan: .free, current: subManager.currentPlan)
                        SubscriptionCard(plan: .pro, current: subManager.currentPlan)
                        
                        // Manager Plans
                        PlanSectionHeader(title: "For Managers".localized)
                        SubscriptionCard(plan: .manager, current: subManager.currentPlan)
                        SubscriptionCard(plan: .team, current: subManager.currentPlan)
                        
                        // Professional Plans
                        PlanSectionHeader(title: "For Coaches & Teams".localized)
                        SubscriptionCard(plan: .max, current: subManager.currentPlan)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal)
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
}

struct PlanSectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .padding(.leading, 4)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct SubscriptionCard: View {
    let plan: SubscriptionPlan
    let current: SubscriptionPlan
    
    var isSelected: Bool { current == plan }
    
    var body: some View {
        NavigationLink(destination: SubscriptionDetailView(plan: plan)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(plan.priceString)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.accent)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                
                Text(plan.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding()
            .background(isSelected ? Theme.accent.opacity(0.1) : Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Plan Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.displayName)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(plan.priceString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.top, 20)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Detailed Content Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Plan Details".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        planDescriptionView
                    }
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Included Features".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(plan.features, id: \.self) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                                Text(feature)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    Spacer(minLength: 40)
                    
                    if !isSelected {
                        // Purchase Button
                        Button(action: purchase) {
                            Text("Purchase".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.primaryGradient)
                                .cornerRadius(14)
                                .shadow(color: Theme.accent.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                    } else {
                        // 現在購入中かつ Free 以外のときにキャンセル（自動更新の停止）ボタンを設置
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Current Plan".localized)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            
                            if plan != .free {
                                if subManager.isAutoRenew {
                                    Button(action: {
                                        withAnimation {
                                            subManager.cancelSubscription()
                                        }
                                    }) {
                                        Text("Cancel Subscription".localized)
                                            .font(.headline)
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                } else {
                                    Text("Subscription will end at the end of the period.".localized)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(24)
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
    
    @ViewBuilder
    private var planDescriptionView: some View {
        switch plan {
        case .free:
            VStack(alignment: .leading, spacing: 12) {
                Text("RowPilotの中核となる基本的な機能を使用できます。")
                    .foregroundColor(.white.opacity(0.8))
            }
        case .pro:
            VStack(alignment: .leading, spacing: 12) {
                Text("Freeプランで使用できる全機能に加え、ForceCurveを表示したり過去の自分とレースしたりできます。")
                    .foregroundColor(.white.opacity(0.8))
                Text("Stravaとの同期は準備中です。")
                    .foregroundColor(.white.opacity(0.8))
            }
        case .manager:
            VStack(alignment: .leading, spacing: 12) {
                Text("業界初のPM5との複数台接続ができるようになります。")
                    .foregroundColor(.white.opacity(0.8))
                Text("1台の端末から最大10台の")
                    .foregroundColor(.white.opacity(0.8))
                Text("記録をリアルタイムに確認したり、")
                    .foregroundColor(.white.opacity(0.8))
                Text("チーム全員で一斉にトレーニングを行うことができます。")
                    .foregroundColor(.white.opacity(0.8))
            }
        case .team:
            VStack(alignment: .leading, spacing: 12) {
                Text("最大3名のメンバーにマネージャーモード（ManagerPlan）を共有することができます。")
                    .foregroundColor(.white.opacity(0.8))
                Text("チーム全員でデータを共有し、練習の効率化を図ることができます。")
                    .foregroundColor(.white.opacity(0.8))
            }
        case .max:
            VStack(alignment: .leading, spacing: 12) {
                Text("最大5名のメンバーにマネージャーモード（ManagerPlan）を共有することができます。")
                    .foregroundColor(.white.opacity(0.8))
                Text("Teamの全機能に加え、記録のCSV書き出し、グラフィカルなレースビューの表示が可能になります。")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private func purchase() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Confirm your subscription purchase.".localized
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            subManager.purchasePlan(plan)
                        }
                        // 1秒待ってから画面を閉じる
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            dismiss()
                        }
                    } else if let error = authenticationError as? LAError, error.code != .userCancel {
                        authErrorMessage = error.localizedDescription
                        showingAuthError = true
                    }
                }
            }
        } else {
            // パスコード等の生体認証が利用できない場合はテスト用にそのまま購入成功させる
            withAnimation {
                subManager.purchasePlan(plan)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
