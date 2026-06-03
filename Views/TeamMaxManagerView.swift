import SwiftUI

/// TeamおよびMAXプランユーザー向けのManagerPlan共有管理ビュー
struct TeamMaxManagerView: View {
    @ObservedObject var subManager = SubscriptionManager.shared
    @State private var newMemberId = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー情報
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.primaryGradient)
                            .padding(.top, 24)
                        
                        Text("Team & MAX Management".localized)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        
                        Text("Teammates can share RowPilot Manager features.".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // プラン情報・共有枠
                    VStack(alignment: .leading, spacing: 16) {
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
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("SHARING SLOTS".localized)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("\(subManager.sharedMembers.count) / \(subManager.shareLimit)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // 共有相手に伝えるための自分のユーザーID
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your ID (Share with your teammates):".localized)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            HStack {
                                Text(subManager.myUserRecordId)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                                
                                Button(action: copyToClipboard) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundColor(Theme.accent)
                                        .font(.body)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 16)
                    
                    // メンバー追加フォーム
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Teammate".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            TextField("Enter Teammate's ID".localized, text: $newMemberId)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            Button(action: addMember) {
                                if subManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Theme.accent)
                                }
                            }
                            .padding(.horizontal, 8)
                            .disabled(subManager.isLoading)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    // 共有中メンバーのリスト
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shared Members".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if subManager.sharedMembers.isEmpty {
                            Text("No shared members yet.".localized)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(subManager.sharedMembers, id: \.self) { member in
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(member)
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        Spacer()
                                        Button(action: { removeMember(member) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    
                                    if member != subManager.sharedMembers.last {
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    
                    // 共有ヘルプ（Q&A）
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.accent)
                            Text("Manager Plan Sharing Help".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HelpQAItem(
                                question: "どうすればメンバーにManagerPlanを共有できますか？",
                                answer: "共有したいメンバーの「ユーザーID」を上記の「Add Teammate」に入力し、追加ボタンをタップします。追加されたメンバーは、アプリ起動時または同期により自動的にManagerPlanの機能が使えるようになります。"
                            )
                            
                            HelpQAItem(
                                question: "個人で既にManagerPlan等に加入しているメンバーを追加できますか？",
                                answer: "いいえ。個人で既に有料プラン（Pro、Manager、Team、MAX）に加入しているユーザーには共有できません。もし共有させたい場合は、そのメンバーが個人サブスクリプションを解約し、有効期限が切れてFreeプランに戻るのを待ってから登録を行ってください。"
                            )
                            
                            HelpQAItem(
                                question: "共有元のサブスクリプションを解約した場合はどうなりますか？",
                                answer: "共有元のTeamまたはMAXユーザーがサブスクリプションを解約（自動更新の停止）した場合、翌月の有効期限が切れたタイミングで共有先メンバーも自動的にFreeプランに移行（共有の終了）されます。"
                            )
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Manager Sharing".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sharing Info".localized, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = subManager.myUserRecordId
        alertMessage = "Your ID has been copied to your clipboard.".localized
        showingAlert = true
    }
    
    private func addMember() {
        guard !newMemberId.isEmpty else { return }
        subManager.addMember(newMemberId) { success, error in
            if success {
                newMemberId = ""
                alertMessage = "Teammate added successfully.".localized
            } else {
                alertMessage = error ?? "Failed to add teammate.".localized
            }
            showingAlert = true
        }
    }
    
    private func removeMember(_ member: String) {
        if let index = subManager.sharedMembers.firstIndex(of: member) {
            subManager.removeMember(at: IndexSet(integer: index))
            alertMessage = "Teammate removed.".localized
            showingAlert = true
        }
    }
}

/// ヘルプQAアイテム用アコーディオンビュー
struct HelpQAItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Q: \(question)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text("A: \(answer)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(4)
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
            
            Divider().background(Color.white.opacity(0.1))
        }
    }
}
