import SwiftUI

struct AboutRowPilotView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    CreditSection(title: "RowPilotとは") {
                        NavigationLink(destination: AboutAppView()) {
                            HStack {
                                Text("RowPilotの生まれた背景".localized)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                                    
                    CreditSection(title: "技術的な挑戦") {
                        NavigationLink(destination: TechnicalChallengesView()) {
                            HStack {
                                Text("PM5との通信やUIデザインについて".localized)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    CreditSection(title: "謝辞") {
                        NavigationLink(destination: AboutSpecialThanksView()) {
                            HStack {
                                Text("RowPilotを支えてくれた人々".localized)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    CreditSection(title: "開発者から") {
                        NavigationLink(destination: FromDeveloperView()) {
                            HStack {
                                Text("開発者からのメッセージ".localized)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About RowPilot")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//MARK: - Detail Views

struct AboutAppView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "RowPilotの生まれた背景") {
                        Text("RowPilotは、部活で使用するGPSレート計が不足していることを解決するために開発が始まりました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("GPSレート計は、艇速やストロークテンポなどの重要な指標をリアルタイムで計測できる便利なツールですが、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("学校の部活動には十分な台数がなく、高価なので艇の人数分を用意することは難しいのが課題でした。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そこで、各クルーが持っているスマートフォンを使って".localized)
                            .foregroundColor(Theme.textMain)
                        Text("GPSレート計の代わりとなる、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("艇速やストロークテンポを計測できるアプリを開発することを思い立ちました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうしてRowPilotは、単なる計測アプリではなくなっていきました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("潮汐データを表示したり、PM5と接続したりできる唯一の統合型アプリとなりました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("RowPilotは、ボート競技における情報の非対称性をなくし、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("一人ひとりの努力が可視化され、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("チーム全体で高め合える文化を広げていきたいと考えています。".localized)
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About App")
    }
}
//MARK: - Technical Challenges
struct TechnicalChallengesView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "PM5との通信やUIデザインについて") {
                        Text("PM5と接続し、屋外だけでなく屋内での記録ができるようにすると思い立ったのは、2025/12/20のことでした。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("しかし、BluetoothでPM5と接続することは容易ではありませんでした。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("Concept2のPM5とのコミュニケーションドキュメントを読み漁り、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("AIと対話しながら続けていても埒が明かず、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("半ば諦めかけていたところ、本社の方にメールをすることにしました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("すると、驚くべきことに".localized)
                            .foregroundColor(Theme.textMain)
                        Text("開発の手伝いをしていただけたのです。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうして、2/12に初めてPM5にトレーニングメニューを送ることができ、".localized)  
                            .foregroundColor(Theme.textMain)
                        Text("それから1ヶ月後には、9台のPM5に同時にトレーニングメニューを送信し、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("8台の相互通信の成功を収めることができました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("また、UI面でも苦労しました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("当初はシンプルなデザインを考えていたのですが、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("ボート部員全員が使いやすいアプリにしたいと考え直し、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("見やすい配色やアイコンを選んだり、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("操作しやすいレイアウトを心がけたりと、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("より多くの人が使いやすいように工夫しました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("こうして、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("ボート部だけでなくローイングに関わるすべての人が使いやすいアプリを目指して".localized)
                            .foregroundColor(Theme.textMain)
                        Text("RowPilotは誕生しました。".localized)
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("技術的な挑戦".localized)
    }
}
//MARK: - Special Thanks
struct AboutSpecialThanksView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "RowPilotを支えてくれた人々") {
                        Text("このアプリが完成するまでには、本当にたくさんの人が関わってくれました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("まず、PM5との通信について全くわからない時から支えてくださった".localized)
                            .foregroundColor(Theme.textMain)
                        Text("Concept2のRyanさん".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("次に、開発案を出してくれた".localized)
                            .foregroundColor(Theme.textMain)
                        Text("redditのユーザー".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("また、改善案を出してくれた".localized)
                            .foregroundColor(Theme.textMain)
                        Text("ボート部の先輩方や友人たち。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                        Text("そして、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("実際にこのアプリの成長を願い、ローエルゴを貸してくださった".localized)
                            .foregroundColor(Theme.textMain)
                        Text("顧問の先生".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("最後に、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("そして、データ取得の際に手助けをしてくれた、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("ボート部員たち。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("こうして皆さんの支えがあって、".localized)
                            .foregroundColor(Theme.textMain)
                        Text("このアプリは完成しました。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("本当にありがとうございます。".localized)
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("謝辞".localized)
    }
}
//MARK: - From Developer
struct FromDeveloperView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "開発者からのメッセージ") {
                        Text("このアプリは、たまたまパソコンがある環境だけを持ち合わせた、プログラミングについてはほとんど知らない高校生が、AIとともに興味と好奇心だけで作り上げたものです。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("僕が伝えたいことは、「興味を持ったことは、何でもやり続けてほしい」ということです。".localized)
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("このアプリの開発には約1年かかっています。手を動かした時間だけでも、ゆうに半年を超えます。".localized)
                        Text("これほどの長期間、モチベーションなしに動き続けるのは、ごく一部の人間でない限り不可能です。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("僕は幸いにも恵まれた環境にいます。手元にはPCがあり、AIが急速に発展してきた時代のど真ん中で生きています。".localized)
                        Text("さらに、顧問の先生に頼めばローエルゴを長期間貸してもらえたり、海外のConcept2のエンジニアにメールすると丁寧に返信・解説してもらえたりと、これ以上ないほど恵まれた環境にいます。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("しかし、環境があるだけではこのアプリは生まれませんでした。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そして仮にこのような環境になかったとしても、ローイング関連の部活に入り、技術マネージャーという立場を経験していれば、規模は違えど似たようなアプリは作っていたと思います。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("自分の中に抑えきれない何かがある時、それを思う存分さらけ出してください。（他人に迷惑をかけない範囲で）".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そして、その「何か」をどうか大切にしてください。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("続けることは簡単ではありません。".localized)
                        Text("もちろんしんどいこともあります。".localized)
                        Text("そんな時は、成功した時の情景を強くイメージしてみてください。きっとそこに向かうモチベーションが湧いてきます。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうして続けることで、誰かの役に立つ新しい仕組みや、今までになかったアイデアが生まれるはずです。".localized)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("RowPilot Developer")
                            .foregroundColor(Theme.textMain)
                        Text("Kaito Nakahira")
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("開発者から".localized)
    }
}

#Preview {
    NavigationStack {
        AboutRowPilotView()
    }
}
