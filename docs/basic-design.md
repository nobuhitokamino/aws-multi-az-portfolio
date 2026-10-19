# AWS Multi-AZ Web Infrastructure 基本設計書

## 1. システム概要

本システムは、AWS上に構築する高可用性とセキュリティを考慮したWebサーバー環境である。

東京リージョンの2つのアベイラビリティゾーン（AZ）を使用し、
両AZのプライベートサブネットをAuto Scaling Group（ASG）の起動先とし、
通常は各AZに1台、合計2台のEC2を配置する。インスタンスの配置・置換はASGが管理する。

Amazon Route 53で独自ドメインのDNS管理を行い、
AWS Certificate Manager（ACM）で発行した証明書を使用してHTTPS通信を実現する。

インターネットからのHTTPリクエストはALBでHTTPSへリダイレクトし、
HTTPSリクエストはALBで受け付け、正常なEC2へ振り分ける。

セキュリティ対策として、EC2への直接的なインターネットアクセスを制限し、
ALBにAWS WAFを関連付けてWebアプリケーション層の攻撃に対処する。

CloudWatchによる監視を実施し、
Terraformによってインフラ構成をコード化する。

## 2. システム構成

| AWSサービス | 用途 | 採用理由 |
|---|---|---|
| VPC | システム専用ネットワーク | ネットワークを論理的に分離するため |
| Subnet | Public/Privateネットワークの分離 | 外部公開部分とWebサーバーを分離するため |
| Internet Gateway | インターネット接続 | ALBを外部公開するため |
| Route 53 | DNS管理 | 独自ドメインでWebサイトを公開するため |
| ACM | SSL/TLS証明書の管理 | HTTPS通信を実現するため |
| ALB | HTTPS終端・リダイレクト・負荷分散 | 通信の暗号化、負荷分散、障害時の切り替えのため |
| EC2 | Webサーバー | Nginxで静的HTMLを配信するため |
| Auto Scaling Group | EC2の台数維持・異常インスタンスの置換 | ELBヘルスチェックに基づく自動復旧とMulti-AZ配置のため |
| Launch Template | EC2の起動設定 | AMI、EBS、IAM、User Dataを共通化するため |
| AWS WAF | Webアクセスの検査・制御 | 不正なHTTPリクエストを制限するため |
| Security Group | 通信制御 | 必要な通信のみ許可するため |
| Systems Manager Session Manager | EC2の管理 | SSHポートを開放せずにプライベートEC2を管理するため |
| SSM・SSM Messages Interface Endpoint | Systems Managerへの接続 | NAT Gatewayを使わずにプライベート通信でEC2を管理するため |
| CloudWatch Logs Interface Endpoint | Nginxログの送信 | NAT Gatewayを使わずにプライベート通信でログを送信するため |
| S3（ALBログ用） | ALBアクセスログの保存 | リクエストの調査と30日経過後の自動削除のため |
| SNS | アラームのメール通知 | 異常発生と正常復帰を管理者へ通知するため |
| S3 Gateway Endpoint | パッケージ取得 | NAT Gatewayを使わずにAmazon Linux 2023のリポジトリへアクセスするため |
| IAM | アクセス権限の管理 | EC2に必要最小限の権限を付与するため |
| CloudWatch | 監視 | EC2やALBの状態を確認するため |
| Terraform | IaC | インフラ環境を再現可能にするため |

## 3. ネットワーク設計

### 3.1 VPC

| 項目 | 設定 |
|---|---|
| リージョン | ap-northeast-1 |
| VPC CIDR | 10.0.0.0/16 |
| 使用AZ | ap-northeast-1a、ap-northeast-1c |

### 3.2 サブネット

| サブネット | CIDR | AZ | 用途 |
|---|---|---|---|
| Public Subnet 1 | 10.0.1.0/24 | ap-northeast-1a | ALB |
| Public Subnet 2 | 10.0.2.0/24 | ap-northeast-1c | ALB |
| Private Subnet 1 | 10.0.11.0/24 | ap-northeast-1a | EC2 |
| Private Subnet 2 | 10.0.12.0/24 | ap-northeast-1c | EC2 |

Public/PrivateともにPublic IP自動割り当ては無効にする。
Public Subnetは共通のPublic Route Tableから `0.0.0.0/0 → IGW` を使用する。
Private Subnetは1つのPrivate Route Tableを共用し、VPC内通信とS3 Gateway Endpointの経路を使用する。
Private側にインターネットへのデフォルトルートは設定しない。

### 3.3 通信経路

利用者は独自ドメイン（portfolio.kamino-infra.com）を使用してWebサイトへアクセスする。

Route 53のDNSレコードによってドメイン名をALBのアドレスへ名前解決する。

インターネットからのHTTP通信（80）は、
Internet Gatewayを経由してALBで受け付け、
HTTPS（443）へリダイレクトする。

HTTPS通信（443）はALBでTLS終端し、
ターゲットグループに登録された正常なEC2へHTTP（80）で転送する。

EC2はプライベートサブネットに配置し、
パブリックIPアドレスを割り当てない。

EC2へのインバウンド通信は、
Security GroupによってALBからのHTTP（80）のみ許可する。

### 3.4 VPCエンドポイント

プライベートサブネットのEC2からAmazon Linux 2023の
パッケージリポジトリへアクセスするため、
S3 Gateway Endpointを使用する。

S3 Gateway Endpointをプライベートサブネットの
ルートテーブルに関連付ける。

これにより、NAT Gatewayを使用せずに
NginxやCloudWatch Agentなどのパッケージを取得する。

SSM、SSM Messages、CloudWatch Logsの3種類のInterface Endpointを
両Private Subnetに配置し、Private DNSを有効にする。
これらはEC2の管理とログ送信に使用する。Interface Endpoint用Security Groupでは、EC2用Security GroupからのHTTPS（TCP 443）のインバウンド通信を許可する。

## 4. DNS・HTTPS設計

### 4.1 ドメイン設計

| 項目 | 設定 |
|---|---|
| ドメイン | kamino-infra.com |
| 公開URL | https://portfolio.kamino-infra.com |
| DNS | Amazon Route 53 |
| DNSレコード | ALBを参照するAレコード（Alias） |

### 4.2 HTTPS設計

- AWS Certificate Manager（ACM）で発行済みの既存パブリック証明書を参照する
- Terraformは公開FQDNに一致するISSUED証明書のうち最新のものをdata sourceで取得する
- DNS検証は証明書を事前に用意する際の手順であり、現行Terraformは証明書や検証用CNAMEを作成しない
- ALBのHTTPSリスナー（443）にACM証明書を設定する
- HTTPリスナー（80）はHTTPS（443）へ301リダイレクトする
- ALBからEC2への通信はHTTP（80）を使用する
- TLSポリシーは `ELBSecurityPolicy-TLS13-1-2-2021-06` を使用する

## 5. サーバー設計

### 5.1 EC2構成

| 項目 | 設定 |
|---|---|
| 用途 | Webサーバー |
| インスタンス数 | ASG管理：min=2 / desired=2 / max=3 |
| AMI | Amazon Linux 2023 |
| AMI管理方針 | SSM Public Parameterから最新AMIを動的取得 |
| インスタンスタイプ | t3.micro |
| CPUアーキテクチャ | x86_64 |
| ストレージ | EBS gp3 10GiB、暗号化、インスタンス終了時に削除 |
| 配置先 | Private Subnet 1、Private Subnet 2 |
| パブリックIP | 割り当てない |
| 起動設定 | Launch Template、IMDSv2必須、User Data |
| ASGヘルスチェック | ELB、起動猶予600秒 |

### 5.2 AMI管理方針

TerraformのdevルートでSSM Public Parameter
`/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` を参照し、
取得したAMI IDをcomputeモジュールの変数へ渡す。

同一Launch Templateバージョンから起動するEC2には同一のAMIを使用し、
起動設定を共通化する。実行時点で最新AMIが変わるため、AMI IDまで固定した再現ではない。

AMI更新時はplanでAMI IDとLaunch Templateの差分を確認し、
新しいAMIで動作検証を実施する。ASGは最新のLaunch Templateバージョン番号を参照するが、
既存インスタンスを一斉更新するInstance Refreshの設定はないため、
既存インスタンスへの反映方法は別途計画する。実行時のAMI IDを記録する。

### 5.3 ミドルウェア

| 項目 | 設定 |
|---|---|
| Webサーバー | Nginx |
| 配信コンテンツ | 静的HTML |
| 待ち受けポート | TCP 80 |
| 起動設定 | systemctl enable nginx |

### 5.4 初期設定

EC2の起動時にUser Dataを実行し、以下の初期設定を行う。

- Nginxのインストール
- Nginxの起動と自動起動設定
- 静的HTMLファイルの配置
- `config/nginx.conf` と `userdata/index.html` をUser Dataへ埋め込み、Nginx設定を検証して起動
- CloudWatch Agentのインストール、動的生成したログ収集設定の配置と起動
- SSM Agentの有効化と起動
- User Dataの実行ログを `/var/log/user-data.log` に保存

### 5.5 サーバー管理

- EC2の管理にはSystems Manager Session Managerを使用する
- SSHポート（22）は開放しない
- EC2にIAMロールを付与し、Systems Managerへの接続を許可する
- インターネットへの直接的なアウトバウンド通信は行わない

## 6. セキュリティ設計

### 6.1 基本方針

- Webサーバーはプライベートサブネットに配置する
- EC2にパブリックIPアドレスを割り当てない
- Security Groupで必要な通信のみ許可する
- AWS WAFをALBに関連付け、Webアプリケーション層の攻撃を制限する
- IAMロールを使用し、EC2に必要な権限のみ付与する
- EC2の管理にはSession Managerを使用し、SSHポートは開放しない

### 6.2 Security Group

| 対象 | インバウンド | 送信元 |
|---|---|---|
| ALB | TCP 80、443 | 0.0.0.0/0 |
| EC2 | TCP 80 | ALB用SG |
| VPC Endpoint | TCP 443 | EC2用SG |

### 6.3 Network ACL

今回はデフォルトのNetwork ACLを使用し、
カスタムNACLは設定しない。

リソース単位の通信制御はSecurity Groupで実施する。

### 6.4 IAM

EC2にIAMロールを付与し、
AmazonSSMManagedInstanceCoreポリシーを使用する。

Nginxログ用のカスタムインラインポリシーも付与する。
ログストリームの作成・参照・イベント送信は対象ロググループに限定し、
`logs:DescribeLogGroups` は `*` に許可する。
CloudWatchAgentServerPolicyは付与しない。

### 6.5 AWS WAF

ALBにAWS WAFを関連付け、以下のルールを設定する。

- AWS Managed Rules Common Rule Set
- 検証用カスタムルール `block-test-header`（優先順位0）

マネージドルールの優先順位は1で、各ルールのアクションに従う。
カスタムルールは `x-portfolio-test` ヘッダの値が `block-me` と完全一致する場合にBlockする。
デフォルトアクションはAllowとし、レートベースルールは定義しない。
検証時にはこのヘッダを使用し、WAFによるブロック動作を確認する。

## 7. 可用性設計

### 7.1 Multi-AZ構成

ASGの起動先を異なる2つのAZに設定し、通常はWebサーバーを1台ずつ配置して、
単一AZまたは単一Webサーバーの障害による
サービス停止リスクを低減する。

ALBを使用して、正常なWebサーバーへ通信を分散する。

### 7.2 ALBヘルスチェック

| 項目 | 設定 |
|---|---|
| プロトコル | HTTP |
| ポート | 80 |
| パス | / |
| 間隔 | 30秒 |
| タイムアウト | 5秒 |
| 正常判定閾値 | 2回 |
| 異常判定閾値 | 2回 |
| 成功コード | 200 |

### 7.3 障害時の動作

ALBのヘルスチェックで異常と判定されたEC2は、
正常なターゲットが存在する場合、
通常のリクエスト振り分け対象から除外する。

残りの正常なEC2でWebページの提供を継続する。

異常が解消し、ヘルスチェックで正常と判定された場合は、
再び振り分け対象に戻す。
ASGによって既に置換された場合は、新しいEC2が初期化・正常判定を経て振り分け対象になる。

### 7.4 復旧方針

本構成ではASGによる異常インスタンスの自動置換を実装する。
ASGはELBヘルスチェックを使用し、起動猶予は600秒、台数はmin=2 / desired=2 / max=3とする。

障害発生時はSession Managerを使用して原因を調査し、
必要に応じてNginxの再起動などを実施する。
ASGが先にインスタンスを置換する可能性があるため、調査時はASGのアクティビティも確認する。

CPU負荷に連動するスケーリングポリシーは定義していない。max=3は台数上限であり、
CPUアラームによって自動で3台へ増加する設定ではない。

検証状況はTerraform定義・過去のAWS実機確認・未検証を区別する。
過去にNginx停止、ALBのhealthy/unhealthy遷移、ASGによるインスタンス置換、
片系障害中に観測したHTTP 200の継続を確認している。AZ全体の障害試験は未実施である。
WAF BLOCKログは過去のTerraform planで確認済みだが、applyとCloudWatch Logsへの配送確認は未実施である。
今回の照合はコードと資料の静的確認であり、AWS実機試験やplanの再実行は行っていない。
その他の過去の確認内容と根拠、未検証事項は[照合結果](reconciliation.md)に記録する。


## 8. 監視設計

### 8.1 監視方針

Amazon CloudWatchを使用し、EC2およびALBの
稼働状況を監視する。

監視対象のメトリクスに閾値を設定し、
異常を検知した場合はCloudWatchアラームを発生させる。

重要なアラームについてはAmazon SNSを使用し、
メールで管理者へ通知する。

### 8.2 監視項目

| 監視対象 | メトリクス | アラーム条件 | 通知 |
|---|---|---|---|
| EC2（ASG単位） | CPUUtilization / Average | 80%以上、5分×2回 | SNS（ALARM・OK） |
| ALB・Target Group | UnHealthyHostCount / Maximum | 1以上、1分×2回 | SNS（ALARM・OK） |
| ALB | HTTPCode_ELB_5XX_Count / Sum | 1件以上、1分×1回 | SNS（ALARM・OK） |

CPUはASG名、5XXはALB、UnHealthyHostCountはALBとTarget Groupをディメンションに指定する。
欠損データはCPUで `missing`、ALBの2項目で `notBreaching` とする。
StatusCheckFailed、HealthyHostCount、Target生成5XXのアラームは定義しない。

### 8.3 通知設計

CloudWatchアラームがALARM状態またはOK状態へ遷移した場合、
Amazon SNSを使用して管理者へメール通知する。

SNSトピック `aws-multi-az-portfolio-alarms` を作成し、
変数 `alert_email` で通知先メールアドレスを登録する。メール購読は受信者による承認が必要である。
SNSトピックポリシーは、同一アカウント・東京リージョン・プロジェクト名接頭辞の
CloudWatchアラームからのPublishを許可する。

### 8.4 障害時の対応

アラーム発生時はCloudWatchで対象メトリクスを確認し、
異常が発生しているリソースを特定する。

EC2の調査が必要な場合はSession Managerで接続し、
Nginxの稼働状況やログを確認する。

原因を特定した後、必要に応じてNginxの再起動などを実施する。
ASGが先にインスタンスを置換する可能性があるため、調査時はASGのアクティビティも確認する。

### 8.5 ログ監視・管理

Amazon CloudWatch Logsを使用し、
EC2上のNginxのログを収集・保存する。

| ログ種別 | 収集対象 | 用途 |
|---|---|---|
| アクセスログ | /var/log/nginx/access.log | アクセス状況の確認 |
| エラーログ | /var/log/nginx/error.log | 障害原因の調査 |

ログ収集にはCloudWatch Agentを使用する。

プライベートEC2からCloudWatch Logsへ接続するため、
CloudWatch Logs Interface Endpointを設置する。

Nginxログは `/aws-multi-az-portfolio/dev/nginx` に14日間保存する。
ストリームは `{instance_id}/access` と `{instance_id}/error` に分離する。

ALBアクセスログは専用S3バケットの `alb/` 配下へ保存し、ライフサイクルで30日後に削除する。
S3はSSE-S3暗号化、パブリックアクセス禁止、BucketOwnerEnforcedを設定する。
WAFログは `aws-waf-logs-aws-multi-az-portfolio` に14日保持し、BLOCKのみKEEP、その他はDROPする。
WAFログはplan確認済みであり、applyと配送確認は未実施である。

## 9. 運用・管理設計

### 9.1 運用方針

本システムは学習・検証用の環境とし、
常時稼働は行わない。

AWSリソースの構成管理にはTerraformを使用し、
サーバーの管理にはSystems Manager Session Managerを使用する。

### 9.2 構成管理

- AWSリソースは原則としてTerraformで作成・変更・削除する
- 既存ドメイン、Hosted Zone、ACM証明書は作成・削除対象に含めない
- StateはS3 Backendを使用し、State用S3は `terraform/bootstrap` でdev環境とは別管理にする
- Backend設定はGit管理対象外の `backend.hcl` で渡す。READMEにS3ロックファイル利用の記述があるが、`use_lockfile` の実効値は未確認である
- Terraformコードと設計書はGitHubでバージョン管理する
- 構成変更前にterraform planで変更内容を確認する
- 変更後は動作確認を実施する
- Terraformの状態ファイルはGitHubに公開しない

### 9.3 サーバー管理

- EC2への管理アクセスにはSession Managerを使用する
- SSHポートは開放しない
- Nginxの稼働状況はsystemctlで確認する
- 障害調査時はjournalctlやNginxのログを確認する

### 9.4 障害対応

CloudWatchアラームやSNS通知で異常を検知した場合、
対象リソースの状態を確認する。

EC2の調査が必要な場合はSession Managerで接続し、
ログやサービスの稼働状況を確認する。

原因を特定した後、必要な復旧作業を実施し、
ALBのヘルスチェックが正常に戻ったことを確認する。

### 9.5 ログ管理

- NginxのアクセスログとエラーログをCloudWatch Logsに収集する
- Nginxログは14日、ALBアクセスログは30日、WAF BLOCKログは14日とする
- WAFログのapply・配送確認は未実施とし、plan確認と実機検証を区別する
- 障害発生時はCloudWatch Logsでログを確認する
- 必要に応じてSession ManagerでEC2に接続し、詳細調査を行う

### 9.6 更新管理

- AMIはSSM Public Parameterから動的取得し、planで変更を確認して実際のAMI IDを記録する
- Launch Template更新だけでは既存インスタンスを一斉置換しないため、更新反映を別途計画する
- AMIやミドルウェアの更新時は動作検証を行う
- 変更内容はGitHubで管理する

### 9.7 コスト管理

- 学習・検証時のみAWSリソースを稼働させる
- 検証終了後はterraform destroyで管理対象リソースを削除する
- Route 53の既存ドメインとホストゾーン、および既存ACM証明書は削除対象に含めない
- State用S3は別管理で `prevent_destroy=true`。ALBログ用S3は `force_destroy=true` のため、dev環境削除時にログが残っていても削除される
- 検証後はAWSコンソールでリソースの削除状況を確認する
