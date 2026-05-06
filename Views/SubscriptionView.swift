import SwiftUI
import LocalAuthentication

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    
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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT PLAN".localized)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(currentPlan.displayName)
                                .font(.headline)
                                .foregroundColor(Theme.accent)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // Plans List
                    VStack(spacing: 16) {
                        // Individual Plans
                        PlanSectionHeader(title: "Individual".localized)
                        SubscriptionCard(plan: .free, current: currentPlan)
                        SubscriptionCard(plan: .pro, current: currentPlan)
                        
                        // Manager Plans
                        PlanSectionHeader(title: "For Managers".localized)
                        SubscriptionCard(plan: .manager, current: currentPlan)
                        SubscriptionCard(plan: .team, current: currentPlan)
                        
                        // Professional Plans
                        PlanSectionHeader(title: "For Coaches & Teams".localized)
                        SubscriptionCard(plan: .max, current: currentPlan)
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
    @AppStorage("userSubscriptionPlan") private var currentPlan: SubscriptionPlan = .free
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""
    
    var isSelected: Bool { currentPlan == plan }
    
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
                    
                    // Detailed Content Section (User will write here)
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
                // ユーザーがここに詳細を書く
            }
        case .pro:
            VStack(alignment: .leading, spacing: 12) {
                Text("Freeプランで使用できる全機能に加え、ForceCurveを表示したりStravaとの同期が可能になります。")
                    .foregroundColor(.white.opacity(0.8))
                // ユーザーがここに詳細を書く
            }
        case .manager:
            VStack(alignment: .leading, spacing: 12) {
                Text("世界で唯一の機能であるPM5との複数台接続ができるようになります。 \n詳細を確認した上で購入してください。")
                    .foregroundColor(.white.opacity(0.8))
                // ユーザーがここに詳細を書く
            }
        case .team:
            VStack(alignment: .leading, spacing: 12) {
                Text("複数人にマネージャーモードを共有することが出来ます。\nまた、チーム単位で記録を保存できるようになります。")
                    .foregroundColor(.white.opacity(0.8))
                // ユーザーがここに詳細を書く
            }
        case .max:
            VStack(alignment: .leading, spacing: 12) {
                Text("Teamプランで使用できる全機能に加え、CSVで記録を出力したり臨場感あふれるレースのような画面を閲覧できるようになります。\n ※この機能は顧問や団体に向けた機能です。")
                    .foregroundColor(.white.opacity(0.8))
                // ユーザーがここに詳細を書く
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
                            currentPlan = plan
                        }
                        // 1秒待ってからサブスクリプション一覧へ戻る
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // dismiss detail view
                        }
                    } else if let error = authenticationError as? LAError, error.code != .userCancel {
                        authErrorMessage = error.localizedDescription
                        showingAuthError = true
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
    }
}
