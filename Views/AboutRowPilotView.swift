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
                                Text("RowPilotの生まれた背景")
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
                                Text("PM5との通信やUIデザインについて")
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
                                Text("RowPilotを支えてくれた人々")
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
                                Text("開発者からのメッセージ")
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
                        Text("RowPilotは、部活で使用するGPSレート計が不足していることを解決するために開発が始まりました。")
                            .foregroundColor(Theme.textMain)
                        Text("GPSレート計は、艇速やストロークテンポなどの重要な指標をリアルタイムで計測できる便利なツールですが、")
                            .foregroundColor(Theme.textMain)
                        Text("学校の部活動には十分な台数がなく、高価なので艇の人数分を用意することは難しいのが課題でした。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そこで、各クルーが持っているスマートフォンを使って")
                            .foregroundColor(Theme.textMain)
                        Text("GPSレート計の代わりとなる、")
                            .foregroundColor(Theme.textMain)
                        Text("艇速やストロークテンポを計測できるアプリを開発することを思い立ちました。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうしてRowPilotは、単なる計測アプリではなくなっていきました。")
                            .foregroundColor(Theme.textMain)
                        Text("潮汐データを表示したり、PM5と接続したりできる唯一の統合型アプリとなりました。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("RowPilotは、ボート競技における情報の非対称性をなくし、")
                            .foregroundColor(Theme.textMain)
                        Text("一人ひとりの努力が可視化され、")
                            .foregroundColor(Theme.textMain)
                        Text("チーム全体で高め合える文化を広げていきたいと考えています。")
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("About App")
    }
}

struct TechnicalChallengesView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "PM5との通信やUIデザインについて") {
                        Text("PM5と接続し、屋外だけでなく屋内での記録ができるようにすると思い立ったのは、2025/12/20のことでした。")
                            .foregroundColor(Theme.textMain)
                        Text("しかし、BluetoothでPM5と接続することは容易ではありませんでした。")
                            .foregroundColor(Theme.textMain)
                        Text("Concept2のPM5とのコミュニケーションドキュメントを読み漁り、")
                            .foregroundColor(Theme.textMain)
                        Text("AIと対話しながら続けていても埒が明かず、")
                            .foregroundColor(Theme.textMain)
                        Text("半ば諦めかけていたところ、本社の方にメールをすることにしました。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("すると、驚くべきことに")
                            .foregroundColor(Theme.textMain)
                        Text("開発の手伝いをしていただけたのです。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうして、2/12に初めてPM5にトレーニングメニューを送ることができ、")  
                            .foregroundColor(Theme.textMain)
                        Text("それから1ヶ月後には、9台のPM5に同時にトレーニングメニューを送信し、")
                            .foregroundColor(Theme.textMain)
                        Text("8台の相互通信の成功を収めることができました。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("また、UI面でも苦労しました。")
                            .foregroundColor(Theme.textMain)
                        Text("当初はシンプルなデザインを考えていたのですが、")
                            .foregroundColor(Theme.textMain)
                        Text("ボート部員全員が使いやすいアプリにしたいと考え直し、")
                            .foregroundColor(Theme.textMain)
                        Text("見やすい配色やアイコンを選んだり、")
                            .foregroundColor(Theme.textMain)
                        Text("操作しやすいレイアウトを心がけたりと、")
                            .foregroundColor(Theme.textMain)
                        Text("より多くの人が使いやすいように工夫しました。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("こうして、")
                            .foregroundColor(Theme.textMain)
                        Text("ボート部だけでなくローイングに関わるすべての人が使いやすいアプリを目指して")
                            .foregroundColor(Theme.textMain)
                        Text("RowPilotは誕生しました。")
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("技術的な挑戦")
    }
}

struct AboutSpecialThanksView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "RowPilotを支えてくれた人々") {
                        Text("このアプリが完成するまでには、本当にたくさんの人が関わってくれました。")
                            .foregroundColor(Theme.textMain)
                        Text("まず、PM5との通信について全くわからない時から支えてくださった")
                            .foregroundColor(Theme.textMain)
                        Text("Concept2のRyanさん")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("次に、開発案を出してくれた")
                            .foregroundColor(Theme.textMain)
                        Text("redditのユーザー")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("また、改善案を出してくれた")
                            .foregroundColor(Theme.textMain)
                        Text("ボート部の先輩方や友人たち。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                        Text("そして、")
                            .foregroundColor(Theme.textMain)
                        Text("実際にこのアプリの成長を願い、ローエルゴを貸してくださった")
                            .foregroundColor(Theme.textMain)
                        Text("顧問の先生")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("最後に、")
                            .foregroundColor(Theme.textMain)
                        Text("そして、データ取得の際に手助けをしてくれた、")
                            .foregroundColor(Theme.textMain)
                        Text("ボート部員たち。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("こうして皆さんの支えがあって、")
                            .foregroundColor(Theme.textMain)
                        Text("このアプリは完成しました。")
                            .foregroundColor(Theme.textMain)
                        Text("本当にありがとうございます。")
                            .foregroundColor(Theme.textMain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("謝辞")
    }
}

struct FromDeveloperView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    CreditSection(title: "開発者からのメッセージ") {
                        Text("このアプリは、たまたまパソコンがある環境だけを持ち合わせた、プログラミングについてはほとんど知らない高校生が、AIとともに興味と好奇心だけで作り上げたものです。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("僕が伝えたいことは、「興味を持ったことは、何でもやり続けてほしい」ということです。")
                            .foregroundColor(Theme.textMain)
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("このアプリの開発には約1年かかっています。手を動かした時間だけでも、ゆうに半年を超えます。")
                        Text("これほどの長期間、モチベーションなしに動き続けるのは、ごく一部の人間でない限り不可能です。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("僕は幸いにも恵まれた環境にいます。手元にはPCがあり、AIが急速に発展してきた時代のど真ん中で生きています。")
                        Text("さらに、顧問の先生に頼めばローエルゴを長期間貸してもらえたり、海外のConcept2のエンジニアにメールすると丁寧に返信・解説してもらえたりと、これ以上ないほど恵まれた環境にいます。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("しかし、環境があるだけではこのアプリは生まれませんでした。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そして仮にこのような環境になかったとしても、ローイング関連の部活に入り、技術マネージャーという立場を経験していれば、規模は違えど似たようなアプリは作っていたと思います。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("自分の中に抑えきれない何かがある時、それを思う存分さらけ出してください。（他人に迷惑をかけない範囲で）")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そして、その「何か」をどうか大切にしてください。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("続けることは簡単ではありません。")
                        Text("もちろんしんどいこともあります。")
                        Text("そんな時は、成功した時の情景を強くイメージしてみてください。きっとそこに向かうモチベーションが湧いてきます。")
                        Text("")
                            .foregroundColor(Theme.textMain)
                        Text("そうして続けることで、誰かの役に立つ新しい仕組みや、今までになかったアイデアが生まれるはずです。")
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
        .navigationTitle("開発者から")
    }
}

#Preview {
    NavigationStack {
        AboutRowPilotView()
    }
}
