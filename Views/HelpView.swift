import SwiftUI

/// 互換性のために残すプレーンテキスト用ヘルプビュー
struct HelpView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(content)
                            .foregroundColor(Theme.textMain)
                            .lineSpacing(6)
                            .font(.body)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

/// 共通のヘルプボタン
struct HelpCircleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.accent)
                .background(Circle().fill(Theme.cardBackground))
                .shadow(radius: 4)
        }
    }
}

// MARK: - RowMode Help View (Portrait)
struct RowModePortraitHelpView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var langManager = LocalizationManager.shared
    
    private var isJA: Bool {
        langManager.language == .japanese
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        overviewCard
                        stepsCard
                        metricsCard
                        safetyCard
                    }
                    .padding()
                }
            }
            .navigationTitle(isJA ? "乗艇モード ヘルプ" : "RowMode Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.rower")
                    .foregroundColor(Theme.accent)
                    .font(.title3)
                Text(isJA ? "機能概要" : "Overview")
                    .font(Theme.subHeaderFont())
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            
            Text(isJA ? "iPhoneのGPSと内蔵モーションセンサーのみでボートの計測を行うモードです。エルゴ等の外部機器への接続は不要で、水上での練習を記録できます。" : "This mode measures your rowing session using only the iPhone's GPS and internal motion sensors. No external connection is required, perfect for water training.")
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06)
    }
    
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .foregroundColor(Theme.accent)
                    .font(.title3)
                Text(isJA ? "計測の手順" : "Steps to Record")
                    .font(Theme.subHeaderFont())
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                stepRow(num: "1", text: isJA ? "オールの動きを正確に検知するため、iPhoneを防水ケース等に入れてボート（艇）に動かないようしっかりと固定します。" : "Secure the iPhone firmly to the boat in a waterproof case to detect strokes accurately.")
                stepRow(num: "2", text: isJA ? "「Start Rowing」ボタンをタップして計測を開始します。" : "Tap the \"Start Rowing\" button to begin.")
                stepRow(num: "3", text: isJA ? "漕ぎ始めると、ストローク数(SPM)や500mペースが自動で算出・表示されます。" : "Once rowing, SPM (stroke rate) and 500m pace are automatically calculated.")
                stepRow(num: "4", text: isJA ? "終了時は「Stop」をタップし、記録の保存または破棄を選択します。" : "Tap \"Stop\" when finished and choose to Save or Discard.")
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06)
    }
    
    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(Theme.accent)
                    .font(.title3)
                Text(isJA ? "表示項目の説明" : "Display Metrics")
                    .font(Theme.subHeaderFont())
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                metricRow(label: "SPM", desc: isJA ? "毎分ストローク数。iPhoneの加速度センサーからピッチを自動検出します。" : "Strokes Per Minute. Automatically detected via accelerometer.")
                metricRow(label: "Pace", desc: isJA ? "500mあたりの現在のペース。GPSの移動速度から換算されます。" : "Current pace per 500m, calculated from GPS speed.")
                metricRow(label: "Distance & Time", desc: isJA ? "GPSによる走行距離（m）と、セッションの経過時間。" : "Workout distance (m) via GPS and elapsed time.")
            }
        }
        .padding()
        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06)
    }
    
    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text(isJA ? "安全とSOS機能" : "Safety & SOS")
                    .font(Theme.subHeaderFont())
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(Theme.accent)
                        .font(.footnote)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isJA ? "GPS精度インジケータ" : "GPS Signal Strength")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.textMain)
                        Text(isJA ? "画面上部で精度（強・中・弱）を確認できます。上空が遮られていない水上でお使いください。" : "Check signal strength (High/Mid/Low) at the top of the screen. Best used under open sky.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sos")
                        .foregroundColor(.red)
                        .font(.footnote)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isJA ? "緊急SOSボタン" : "Emergency SOS")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Theme.textMain)
                        Text(isJA ? "緊急時に「sos」ボタンをタップ/長押しすると、事前に「設定」＞「緊急連絡先設定」で登録した連絡先に、現在位置やバッテリー残量を含むメッセージをSMS送信する画面を立ち上げます。" : "In emergencies, tap/hold the SOS button to auto-compose an SMS with coordinates and battery status to your emergency contact.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding()
        .glassCardStyle(glowColor: .orange, opacity: 0.06)
    }
    
    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.caption)
                .bold()
                .foregroundColor(Theme.mainBackground)
                .frame(width: 20, height: 20)
                .background(Theme.accent)
                .clipShape(Circle())
                .padding(.top, 2)
            
            Text(text)
                .font(.footnote)
                .foregroundColor(Theme.textMain)
                .lineSpacing(3)
        }
    }
    
    private func metricRow(label: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundColor(Theme.accent)
            Text(desc)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
        }
    }
}

// MARK: - RowMode Help View (Landscape)
struct RowModeLandscapeHelpView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var langManager = LocalizationManager.shared

    private var isJA: Bool {
        langManager.language == .japanese
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        // ─── 上段: 計測手順 / 横画面専用機能（2カラム） ───
                        HStack(alignment: .top, spacing: 12) {
                            stepsCard
                            landscapeExclusiveCard
                        }

                        // ─── 下段: 表示指標の説明 / 安全 & SOS（2カラム） ───
                        HStack(alignment: .top, spacing: 12) {
                            metricsCard
                            safetyCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(isJA ? "乗艇モード ヘルプ（横画面）" : "RowMode Help (Landscape)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: Cards

    private var stepsCard: some View {
        cardContainer(glowColor: Theme.accent) {
            cardHeader(icon: "checklist", title: isJA ? "計測手順" : "How to Record")

            VStack(alignment: .leading, spacing: 8) {
                lsStepRow(num: "1", text: isJA ? "iPhoneを防水ケースに入れ、ボートに固定。" : "Secure iPhone in a waterproof case on the boat.")
                lsStepRow(num: "2", text: isJA ? "「Start Rowing」をタップして計測を開始。" : "Tap \"Start Rowing\" to begin the session.")
                lsStepRow(num: "3", text: isJA ? "漕ぎ始めると SPM・Pace が自動算出される。" : "SPM and Pace are calculated automatically once rowing starts.")
                lsStepRow(num: "4", text: isJA ? "終了時は「Stop」をタップし、保存 or 破棄を選択。" : "Tap \"Stop\" when done, then choose Save or Discard.")
            }
        }
    }

    private var landscapeExclusiveCard: some View {
        cardContainer(glowColor: Theme.accent) {
            HStack(spacing: 6) {
                cardHeader(icon: "rectangle.landscape.rotate", title: isJA ? "横画面専用機能" : "Landscape-Only Features")
                Spacer()
                Text(isJA ? "縦画面にはない機能" : "Not in Portrait")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                lsFeatureRow(
                    icon: "arrow.left.arrow.right",
                    title: isJA ? "下部メトリクスの入れ替え" : "Swap Bottom Metrics",
                    desc: isJA
                        ? "⚙️ 設定ボタンから、画面下部の左右ふたつの表示項目（平均ペース・ストローク数・Dist/Stroke など）を自由に切り替えられます。縦画面では固定表示です。"
                        : "Tap ⚙️ to freely swap the two bottom metrics (Avg Pace, Stroke Count, Dist/Stroke, etc.). In portrait mode, these are fixed."
                )

                lsFeatureRow(
                    icon: "waveform.path.ecg",
                    title: isJA ? "モーション感度の調整" : "Motion Sensitivity",
                    desc: isJA
                        ? "⚙️ 設定のスライダーで、ストローク検出に使う加速度センサーの閾値（G）を変更できます。艇の揺れや漕ぎ方に合わせて微調整することで、SPM の精度が向上します。"
                        : "Adjust the accelerometer threshold (G) via the ⚙️ slider to match your boat's motion. Fine-tuning this improves SPM accuracy."
                )

                lsFeatureRow(
                    icon: "gauge.with.needle",
                    title: isJA ? "大型メトリクス表示" : "Large Metric Display",
                    desc: isJA
                        ? "横画面では SPM・Pace・Distance・Time の4つの主要値が大きく表示され、漕ぎながら一目で確認できます。"
                        : "Landscape mode shows 4 key metrics (SPM, Pace, Distance, Time) in large type, easy to read while rowing."
                )
            }
        }
    }

    private var metricsCard: some View {
        cardContainer(glowColor: Theme.accent) {
            cardHeader(icon: "gauge.with.needle", title: isJA ? "表示指標の説明" : "Metrics Guide")

            VStack(alignment: .leading, spacing: 8) {
                lsMetricRow(label: "SPM", icon: "figure.rower",
                            desc: isJA ? "毎分ストローク数。iPhoneの加速度センサーがオールの動きを検出し自動計算。" : "Strokes Per Minute, auto-detected via accelerometer.")
                lsMetricRow(label: "Pace", icon: "speedometer",
                            desc: isJA ? "500m あたりのペース。GPS の移動速度から換算されます。" : "Pace per 500 m, derived from GPS ground speed.")
                lsMetricRow(label: "Distance", icon: "map",
                            desc: isJA ? "GPS による走行距離（m）。精度は電波状況に依存します。" : "GPS-tracked distance (m). Accuracy depends on signal quality.")
                lsMetricRow(label: "Avg Pace", icon: "clock.arrow.circlepath",
                            desc: isJA ? "セッション開始からの平均 500m ペース。下部メトリクスに表示可。" : "Average 500 m pace since session start. Shown in bottom metrics.")
                lsMetricRow(label: "Dist/Stroke", icon: "arrow.forward",
                            desc: isJA ? "1 ストロークあたりの移動距離。効率の目安として活用できます。" : "Distance covered per stroke. Useful as a rowing efficiency indicator.")
            }
        }
    }

    private var safetyCard: some View {
        cardContainer(glowColor: .orange) {
            cardHeader(icon: "exclamationmark.triangle.fill", title: isJA ? "安全 & SOS" : "Safety & SOS", iconColor: .orange)

            VStack(alignment: .leading, spacing: 10) {
                lsFeatureRow(
                    icon: "location.fill",
                    iconColor: Theme.accent,
                    title: isJA ? "GPS 精度インジケータ" : "GPS Signal Strength",
                    desc: isJA
                        ? "画面上部で GPS 精度（強・中・弱）を常時確認できます。開けた水上での使用を推奨します。"
                        : "Signal strength (High / Mid / Low) is shown at the top of the screen. Best used under open sky."
                )

                lsFeatureRow(
                    icon: "sos",
                    iconColor: .red,
                    title: isJA ? "緊急 SOS ボタン" : "Emergency SOS Button",
                    desc: isJA
                        ? "画面上の「SOS」をタップ／長押しすると、設定済みの緊急連絡先へ現在位置・バッテリー残量を含む SMS 作成画面を自動で開きます。事前に「設定 ＞ 緊急連絡先設定」で連絡先を登録しておいてください。"
                        : "Tap or hold the \"SOS\" button to auto-compose an SMS with current GPS coordinates and battery level to your preset emergency contact. Set up the contact in Settings › Emergency Contact."
                )
            }
        }
    }

    // MARK: Reusable Components

    private func cardContainer<Content: View>(
        glowColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCardStyle(glowColor: glowColor, opacity: 0.06)
    }

    private func cardHeader(icon: String, title: String, iconColor: Color = Theme.accent) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textMain)
        }
        .padding(.bottom, 2)
    }

    private func lsStepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.mainBackground)
                .frame(width: 18, height: 18)
                .background(Theme.accent)
                .clipShape(Circle())
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMain)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lsFeatureRow(icon: String, iconColor: Color = Theme.accent, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 12))
                .frame(width: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMain)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func lsMetricRow(label: String, icon: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .font(.system(size: 11))
                .frame(width: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Tide Help View
struct TideHelpView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var langManager = LocalizationManager.shared
    
    private var isJA: Bool {
        langManager.language == .japanese
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 概要
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(isJA ? "機能概要" : "Overview")
                                    .font(Theme.subHeaderFont())
                                    .bold()
                                    .foregroundColor(Theme.textMain)
                            }
                            
                            Text(isJA ? "気象庁が提供する全国239地点の潮汐（潮位）データを取得し、グラフとリストで表示する機能です。" : "This feature retrieves and displays tide level data from 239 stations around Japan provided by the Japan Meteorological Agency.")
                                .font(.footnote)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06)
                        
                        // 使い方
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text(isJA ? "使い方" : "How to Use")
                                    .font(Theme.subHeaderFont())
                                    .bold()
                                    .foregroundColor(Theme.textMain)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                helpBulletRow(title: isJA ? "最寄り観測点の自動選択" : "Automatic Station Selection",
                                             desc: isJA ? "GPSによる位置情報を利用し、現在地から最も近い観測点のデータを自動で取得・表示します。" : "Uses GPS to automatically search and retrieve tide data from the nearest observation station.")
                                
                                helpBulletRow(title: isJA ? "日付の切り替え" : "Date Navigation",
                                             desc: isJA ? "グラフエリアを左右にスワイプするか、上部の日付リストをタップすることで、前後 60日間の任意の日のデータを表示できます。" : "Swipe the chart area left/right or tap the date list at the top to navigate between up to 60 days.")
                                
                                helpBulletRow(title: isJA ? "現在時刻のインジケータ" : "Current Time Indicator",
                                             desc: isJA ? "「今日」のデータを表示している場合、現在の時間を示す破線（バー）がグラフ内に縦に表示されます。" : "When viewing \"Today's\" data, a vertical dashed line marks the current hour on the chart.")
                            }
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.accent, opacity: 0.06)
                        
                        // 警告と制限
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                Text(isJA ? "重要・注意事項" : "Important Warnings")
                                    .font(Theme.subHeaderFont())
                                    .bold()
                                    .foregroundColor(Theme.textMain)
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("⚠︎")
                                        .foregroundColor(.orange)
                                        .bold()
                                    Text(isJA ? "表示される潮位データは、気象庁の予測計算値に過ぎません。実際の潮位は、洪水や台風などの気圧変化、風、河川の流入状況により異なることがあります。水上に出る際は必ず現地の実際の状況を見て、安全を優先した判断を行ってください。" : "Tide levels are calculated predictions. Actual water levels may differ due to typhoons, atmospheric pressure changes, wind, or river inflows. Always verify local conditions before getting on the water.")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(4)
                                }
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Text("※")
                                        .foregroundColor(Theme.textSecondary)
                                    Text(isJA ? "当機能は、日本国内でのみご利用いただけます。" : "This feature is only functional near coastal observation stations in Japan.")
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineSpacing(4)
                                }
                            }
                        }
                        .padding()
                        .glassCardStyle(glowColor: .orange, opacity: 0.06)
                    }
                    .padding()
                }
            }
            .navigationTitle(isJA ? "潮汐情報 ヘルプ" : "Tide Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func helpBulletRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(.footnote)
                    .bold()
                    .foregroundColor(Theme.textMain)
            }
            Text(desc)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.leading, 12)
        }
    }
}
