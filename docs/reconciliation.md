# 設計資料とTerraform実装の照合結果

照合日：2026-10-19（日本時間）。対象は要件定義書、基本設計書、詳細設計書、構成図である。
本資料は前回の照合結果を参考にしつつ、最新のGitHub実装から再照合して記載した。

## 照合資料と修正の土台

| 資料 | 使用方法・確認結果 |
|---|---|
| GitHub | [nobuhitokamino/aws-multi-az-portfolio](https://github.com/nobuhitokamino/aws-multi-az-portfolio) のdefault branchを読み取り取得 |
| 実装基準コミット | `27572183242fb8c37dd6f3d3551b86fe441e8d7c`（feat: implement multi-AZ AWS infrastructure with Terraform） |
| 設計書の土台 | 上記コミットの詳しい元設計書。前回Workの短縮版は土台に使用しない |
| 元アーカイブ | `aws-multi-az-portfolio-review.tar.gz`。GitHubの設計書と比較したところ、要件定義書は完全一致、基本・詳細設計書の差は末尾空行または行末空白のみ。見出し・説明・設定表は一致 |
| 構成図の土台 | 元アーカイブとGitHubのdrawio・PNGは、それぞれSHA-256が一致 |
| 前回の照合資料 | `aws-multi-az-portfolio-updated-docs-and-diagrams.tar.gz` の `docs/reconciliation.md` と同内容の前回作業ファイルを参考として参照。既知の差異と過去の検証状況を把握する用途に限定 |
| Terraformの確認範囲 | `terraform/environments/dev`、全モジュール、`terraform/templates/user_data.sh.tftpl`、`terraform/bootstrap`、`config/nginx.conf`、`userdata/index.html` |
| 補足資料 | 基準コミットのREADME。`docs/aws-config` は過去の取得結果であり現行実装・現在のAWS状態の正とは扱わない |

元アーカイブのSHA-256：`74db14b6ebedfa61df2a9608a2b933a9332ea3b47477baa5eedc9fdd45b4121c`。
前回修正済みアーカイブのSHA-256：`5053940e7849b3c9199f153dc1683ea2171c6f83a5b3c6b690b1393c1783bf47`。

## 状態の前提

以下の3区分を分けて扱う。コードが存在することを、AWSへの反映や実機試験の合格と同一視しない。

| 区分 | この照合での扱い |
|---|---|
| Terraformに定義 | 指定コミットの実ファイルを静的に読み、devから渡す値を含めて確認したもの |
| 過去のAWS実機確認 | 利用者の申告およびREADMEの履歴にある過去の確認。本照合で再試験したものではなく、最新コミット全体の反映完了を保証しない |
| 未検証・今回未確認 | 実施していない試験、planのみの設定、証拠のない配送・現在状態など。未検証のまま明記する |

| 対象 | Terraform定義 | AWS実機確認・未検証の範囲と根拠 |
|---|---|---|
| ALB・ASG・2AZ | 2AZを起動先に指定、min=2 / desired=2 / max=3、ELBヘルスチェック、猶予600秒 | 利用者申告とREADME 7.4・7.5に、Nginx停止→unhealthy→ASG置換→healthy、片系障害中に観測したHTTP 200継続の履歴あり |
| AZ全体障害 | 2AZを使用する構成 | 試験未実施。片側Nginx停止からAZ全体障害時の可用性を実証したとは記載しない |
| HTTPS・HTTPリダイレクト | 既存ACM参照、443終端、80→443の301 | README 7.1に過去のHTTPS 200・HTTP 301・証明書利用確認の記載あり。今回の再試験なし |
| WAFリクエスト遮断 | 検証用ヘッダルール＋CommonRuleSet | README 7.2に通常200・ヘッダ遮断403の確認記載あり。CommonRuleSet個々のルール全ての実機確認を意味しない |
| WAF BLOCKログ | CloudWatch Logs、BLOCKのみ、14日保持 | 利用者申告・前回照合資料・README 6で過去のplan確認まで。apply・実配送は未実施。今回planは再実行していない |
| CloudWatch・SNS | ALB 5XX、UnHealthyHostCount、ASG平均CPU。ALARM・OK時にSNS | README 7.3に状態をテスト変更してメール受信した履歴あり。実メトリクスの閾値超過による全アラームの発報試験完了とは扱わない |
| Nginx・ALBログ | NginxはLogsに14日、ALBはS3に30日の設定 | READMEに収集・保存構成の説明あり。ただし全ログ種別の実配送・保持期間経過試験の結果は今回確認できない。現行実装での配送・削除タイミングは要確認 |
| Session Manager・VPC Endpoint | ssm / ssmmessages / logsを両Private Subnetへ配置、S3 Gateway Endpoint、NATなし | READMEに利用の説明あり。今回の接続試験なし。現在のEC2・Endpoint・IAMの状態は未確認 |
| Terraformによる再構築・削除 | dev構成と別管理のbootstrapを定義 | 今回はinit・validate・plan・apply・destroyを実行していない。現行構成全体の再構築・削除合格を追認しない |

前回資料にある「fmt確認済み」「55リソース追加のplan」は過去の記録である。
今回の最新コミットに対する新規実行結果や、現在のAWS上のリソース数として転記しない。

## 差異一覧

以下のファイルパスは基準コミット内の実装根拠を示す。優先度は事実誤認の影響に基づく。

| ID・重要度 | 元の記載／不足 | 実装（正）と修正理由 | 変更箇所 | 実装根拠 |
|---|---|---|---|---|
| D01 P1 | 固定EC2 2台、自動復旧なし、ASGは将来課題 | ASGで2AZへ通常2台、min=2 / desired=2 / max=3。ELBヘルスチェックにより異常インスタンスを自動置換。固定AZ名・固定EC2名による管理ではない | 要件3・4、基本1・2・5.1・7、詳細3.1・4.2・8.2、構成図 | `environments/dev/main.tf`、`modules/compute/asg.tf` |
| D02 P2 | AMI ID固定 | devのSSM Public Parameterから最新AL2023 x86_64を取得。AMI IDをcomputeへ渡しLTに設定。実行時にAMIが変わり得ることを補足 | 要件3～5、基本5.1・5.2・9.6、詳細3.1、構成図 | `environments/dev/main.tf`、`modules/compute/main.tf` |
| D03 P2 | EBS 8GiB、Launch Template・初期化説明が不足 | gp3 10GiB、暗号化・終了時削除、IMDSv2必須。User DataがNginx設定・HTML・Agent設定を配置し、Nginx検証・各サービス起動を実施 | 基本5、詳細3、構成図 | `modules/compute/main.tf`、`templates/user_data.sh.tftpl`、`config/nginx.conf`、`userdata/index.html` |
| D04 P2 | Public IP自動割り当て有効、Private RTがAZごと | 全Subnetで自動Public IP無効。Public RTはIGW向けデフォルトルート、Private RTは1つを共用しS3 Gateway Endpointを関連付け。Privateにデフォルトルートなし | 基本3.2・3.4、詳細1.2～1.4、構成図 | `modules/network/main.tf`、`routing.tf`、`s3_endpoint.tf` |
| D05 P2 | SSM Messages・Logs経路の説明が不足 | ssm・ssmmessages・logsのInterface Endpointを両Private Subnetへ配置、Private DNS有効。NAT Gatewayなしという設計意図を維持 | 要件5、基本2・3.4、詳細1.4、構成図 | `modules/endpoints/main.tf`、`environments/dev/main.tf` |
| D06 P2 | CloudWatchAgentServerPolicyを付与と記載 | 実際はAmazonSSMManagedInstanceCore＋対象ロググループへの限定インラインポリシー。DescribeLogGroupsのみリソース `*`。SGの既存の送受信表は維持 | 基本6.4、詳細2.1・2.2 | `modules/iam/main.tf`、`policies.tf`、`modules/security/rules.tf` |
| D07 P2 | www公開、ACMと検証CNAMEを新規作成・削除 | 公開FQDNはportfolio.kamino-infra.com。既存Hosted Zoneと既存ISSUED証明書（most_recent=true）を参照。Alias Aを作成、evaluate_target_health=false。ACM・検証CNAMEは新規作成しない | 要件5、基本3.3・4・9、詳細4.1・5・8、構成図 | `environments/dev/main.tf`、`modules/dns/main.tf`、`modules/alb/certificate.tf`・`listeners.tf` |
| D08 P1 | レートベース制限、マネージドルール優先順位0 | ヘッダx-portfolio-test=block-meの完全一致遮断が優先順位0、CommonRuleSetが1。レートベースルールはないため、表を現行ヘッダ検証条件へ置換 | 要件3・4、基本6.5、詳細6.2・6.3・8.2、構成図 | `modules/waf/main.tf` |
| D09 P1 | WAFログの実装と実検証の混同を防ぐ必要 | BLOCKのみKEEP、他はDROP、14日保持はTerraform定義・過去planまで。apply・CloudWatch Logsへの配送は未実施と明記 | 要件4、基本7.4・8.5・9.5、詳細6.2・7.2・8.2、本資料、構成図 | `modules/waf/logging.tf`、利用者申告、README 6 |
| D10 P2 | CPU条件、StatusCheckFailed、HealthyHostCount、Target 5XX等の旧監視表 | ASG平均CPU≥80%（300秒×2）、異常Host最大≥1（60秒×2）、ALB生成5XX合計≥1（60秒×1）。統計・dimensions・欠損データ処理も追記 | 要件3、基本8.2、詳細7.1、構成図 | `modules/monitoring/alarms.tf` |
| D11 P2 | 通知がALARM時のみ、旧SNSトピック名 | 全3アラームでALARM・OK時にSNS。トピックはaws-multi-az-portfolio-alarms、alert_emailで購読登録し承認が必要。Publish条件を補足 | 基本8.3、詳細7.3、構成図 | `modules/monitoring/alarms.tf`・`sns.tf`・`sns_policy.tf` |
| D12 P2 | Nginxログ7日、旧ロググループ、ALBログ保存説明不足 | Nginxは/aws-multi-az-portfolio/dev/nginxへ14日。インスタンスIDとaccess/errorで分離。ALBログは専用S3のalb/配下、30日後削除・暗号化・公開禁止 | 基本8.5・9.5・9.7、詳細7.2・8.3、構成図 | `modules/observability/main.tf`、`modules/compute/main.tf`、`modules/alb/main.tf`、`modules/alb_logs/main.tf`・`policy.tf` |
| D13 P2 | リソース管理範囲・State・削除時ログの扱いが不足 | State S3はbootstrapで別管理。devは既存ACM等を参照。ALBログS3はforce_destroy=true、State S3はprevent_destroy=true。今回操作は実施しない | 基本9.2・9.7、詳細5.3・8.1・8.3 | `environments/dev/backend.tf`、`bootstrap/main.tf`、`modules/alb_logs/main.tf` |
| D14 P3 | 旧リソース名、ALB表の構文崩れ | 実装のaws-multi-az-portfolio接頭辞へ修正し、ALB名行を正常な表の1行に修復。名称の更新は実装との対応づけに必要な箇所のみ | 詳細1～7、構成図のSNS誤字 | 各モジュールのname・tags |
| D15 P2 | Nginx手動再起動を主とする復旧試験 | ASGの自動置換とUser Dataによる新EC2初期化を試験の主対象へ変更。手動調査・再起動という運用上の説明は残す | 基本7.3・7.4・8.4、詳細8.2 T05 | `modules/compute/asg.tf`、README 7.4・7.5 |
| D16 P3 | 図にASG・起動設定・専用ALBログS3・ログ状態の情報が不足 | 元のAWSアイコン・2AZ・サブネット配置を維持。ASG枠、共通RT表記、Endpointの3サービス名を更新し、右側に設定・ログ先の補足を追加。ALBから専用ログS3への配送線を追加 | drawio・PNG | D01～D13の実装根拠 |

上表の `environments/`、`modules/`、`templates/`、`bootstrap/` はいずれも `terraform/` 配下を指す。
ALBヘルスチェック（HTTP /、80、30秒、timeout 5秒、healthy/unhealthy 2回、200）など、
既に一致する設定表は維持し、登録解除待機30秒とTLSポリシーなど不足する実装情報を該当表に追記した。

## 反映方針と元資料の保持確認

- 章番号・主見出し・小見出しの順序を維持した。唯一、詳細6.2の第4階層見出し「レートベースルールの設定」は、未実装機能を説明し続けないため「検証用ヘッダ遮断ルールの設定」へ変更した。
- AWSサービスの用途・採用理由の表、ネットワーク、SG、IAM、サーバー、ALB、DNS、WAF、監視、ログ、運用・テストの各表を維持した。新要素は既存の該当章に追記した。
- Private RTの2行は実装に合わせて共通RTの1行へ統合した。未定義の監視行は現行3アラームへ修正した。WAFの旧レート制限表は実装されているヘッダ遮断条件表へ置換した。これらは不整合修正であり、章や表そのものの省略ではない。
- 詳細設計3.1の2AZ比較表は残し、固定EC2ではなくASGの通常配置であることを明記した。
- 原文の説明文は一致するものを保持し、不整合のあるAMI・復旧・WAF等の段落のみ修正した。手動調査やログ調査等の運用上の意図も保持した。
- テスト表は期待結果と実績を混同しないよう注記を追加した。手順として残すapply・destroyは今回の実施結果ではない。

| 資料 | GitHub元版の行数 → 修正版 | 第2・第3階層見出し数（前→後） | 設定・試験等の表数（前→後） |
|---|---|---|---|
| 要件定義書 | 50 → 62 | 5 → 5 | 2 → 2 |
| 基本設計書 | 356 → 419 | 41 → 41 | 10 → 10 |
| 詳細設計書 | 319 → 405 | 31 → 31 | 26 → 28 |

行数は空行を含む。元アーカイブの基本設計書は末尾空行のため357行である。
表数はMarkdownの区切り行で計数した。詳細設計ではASG・起動設定表と追加ログ設定表を増設した。
構成図は元の全セルIDを保持し、必要なラベル・枠を変更して補足セルを追加した。
PNGは修正版drawioを同一のdraw.io描画エンジンで描画した結果から生成し、図の表示を目視確認した。

## READMEとの整合性と未解決事項

READMEは修正対象外のため変更していない。以下を除き、READMEにある構成説明と修正版の主要設定は一致する。

| ID | 対象・残る確認事項 | 状態・扱い |
|---|---|---|
| R01 | README 8の「S3ロックファイル機能を利用」 | `backend.tf` は空のs3 backend定義で、`use_lockfile` を確認できない。`backend.hcl` はGit管理対象外で取得できないため実効値は未確認。State管理方式自体はS3 Backendで一致。実行環境の設定確認が必要 |
| R02 | `config/amazon-cloudwatch-agent.json` | 旧ロググループ等の値を含むが、実際のUser Dataではcomputeの動的設定を使用し、このファイルを参照しない。今回はコード・config変更対象外のため残置。削除またはサンプルと明示して更新するかは保守課題 |
| R03 | README 2の「Route 53を経由してALBに振り分け」 | DNS名前解決の意味と読む必要があり、HTTP通信がRoute 53を通過する意味では不正確。設計書は「名前解決→ALBへのHTTPS接続」と記載。READMEの表現改善候補として記録 |
| R04 | 最新AMIと既存EC2更新 | AMI ID固定・Instance Refreshは定義なし。再構築時点のAMI、LTバージョン、既存EC2への反映を記録・確認する必要あり。現行コードの動作範囲として記載し、更新完了と断定しない |
| R05 | WAFログとAZ試験 | WAFログのapply・配送、AZ全体障害試験は未実施。定義上の構成と試験済み範囲を区別したまま残す |
| R06 | 過去の試験と現行構成の差 | READMEの過去のASG単体試験には1台構成で行った試験も含まれる。現行devのdesired=2と矛盾する設定値として転記せず、履歴として扱う。全最新設定の再試験は今回未実施 |
| R07 | ログ配送・保持・アラームの実条件 | Nginx/ALBログの現行構成での配送、経過日数による削除、実メトリクス閾値での全アラーム・SNS通知、負荷分散の識別確認は今回未検証。READMEの状態変更による通知試験のみで全項目合格とはしない |
| R08 | 既存ACM証明書の属性 | コードはdomain・ISSUED・most_recentで選択する。DNS検証・パブリック証明書利用は設計前提だが、現在の証明書属性・検証CNAME維持状況は今回AWS上で確認していない |

R01・R03はREADMEとの整合性確認で残った確認事項・表現上の差異である。
R02・R04・R08は保守または外部前提の確認事項、R05～R07は検証範囲の限界である。
成果物中で既知の設定値不一致を未修正のまま残すことは避け、確認できない値を推測で補ってはいない。

## 今後の確認項目

1. 承認された別の検証作業で、使用するコミット・AMI ID・LTバージョン・適用日時を記録する。
2. WAFログ設定のapply後にヘッダ遮断を発生させ、指定ロググループへのBLOCKログ配送を確認する。リクエスト遮断確認とログ配送確認を別に記録する。
3. HTTPS 200、HTTP 301、負荷分散、Session Manager接続、Nginx/ALBログ配送を現行構成で確認する。
4. 実メトリクスの条件とSNSのALARM・OK通知を確認する。状態をテスト変更しただけの試験と区別する。
5. Nginx停止による単体障害試験を記録し、AZ全体試験と混同しない。AZ全体試験を実施する場合は別途試験計画を定める。
6. R01のBackend設定、R02の未使用config、R03のREADME表現、R04の更新反映方針を確認する。

## 今回の実施範囲

最新GitHubの読み取り、元資料の比較、設計書・drawioの部分修正、PNG描画、
差分・見出し順・表構造・主要設定の照合を実施した。
Terraform実装コードは変更していない。AWS APIによる操作、apply、リソース削除、
Gitコミット、GitHubへのpushは実行していない。

成果物は指定された6ファイルを格納したアーカイブと、元版に対する差分資料として出力する。

## 照合後の追加確認・修正（2026-10-19）

- R01：backend.hclにuse_lockfile = trueが設定されていることを確認した。実際のBackend初期化は今回再検証していない。
- R02：旧CloudWatch Agent設定ファイルはGit管理対象外であり、現行TerraformのUser Dataから参照されていないことを確認した。
- R03：READMEのRoute 53に関する説明を修正し、DNS名前解決とHTTPS通信を区別した。
- 要件定義書、基本設計書、詳細設計書の表現とテスト内容を一部改善した。
- AWS構成図は技術的な構成を維持しながら、視認性を重視してレイアウトを調整した。
- Terraformの実装コードは変更していない。