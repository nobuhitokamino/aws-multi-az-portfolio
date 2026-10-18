# AWS Multi-AZ Web Infrastructure 基本設計書

## 1. システム概要

本システムは、AWS上に構築する高可用性とセキュリティを考慮したWebサーバー環境である。

東京リージョンの2つのアベイラビリティゾーン（AZ）を使用し、
各AZのプライベートサブネットにEC2を配置する。

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
| AWS WAF | Webアクセスの検査・制御 | 不正なHTTPリクエストを制限するため |
| Security Group | 通信制御 | 必要な通信のみ許可するため |
| Systems Manager Session Manager | EC2の管理 | SSHポートを開放せずにプライベートEC2を管理するため |
| SSM Interface Endpoint | Systems Managerへの接続 | NAT Gatewayを使わずにプライベート通信でEC2を管理するため |
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

### 3.3 通信経路

利用者は独自ドメイン（www.kamino-infra.com）を使用してWebサイトへアクセスする。

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
Nginxなどのパッケージを取得する。

## 4. DNS・HTTPS設計

### 4.1 ドメイン設計

| 項目 | 設定 |
|---|---|
| ドメイン | kamino-infra.com |
| 公開URL | https://www.kamino-infra.com |
| DNS | Amazon Route 53 |
| DNSレコード | ALBを参照するAレコード（Alias） |

### 4.2 HTTPS設計

- AWS Certificate Manager（ACM）でパブリック証明書を発行する
- 証明書の検証にはDNS検証を使用する
- ALBのHTTPSリスナー（443）にACM証明書を設定する
- HTTPリスナー（80）はHTTPS（443）へ301リダイレクトする
- ALBからEC2への通信はHTTP（80）を使用する

## 5. サーバー設計

### 5.1 EC2構成

| 項目 | 設定 |
|---|---|
| 用途 | Webサーバー |
| インスタンス数 | 2台 |
| AMI | Amazon Linux 2023 |
| AMI管理方針 | 構築時に選定したAMI IDを固定 |
| インスタンスタイプ | t3.micro |
| CPUアーキテクチャ | x86_64 |
| ストレージ | EBS gp3 8GiB |
| 配置先 | Private Subnet 1、Private Subnet 2 |
| パブリックIP | 割り当てない |

### 5.2 AMI管理方針

構築時点で利用可能なAmazon Linux 2023のAMIを選定し、
AMI IDをTerraformの変数として管理する。

2台のEC2には同一のAMIを使用し、
環境の一貫性と再現性を確保する。

AMIを更新する際は、新しいAMIで動作検証を実施した後、
Terraformの設定を変更する。|

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

### 6.5 AWS WAF

ALBにAWS WAFを関連付け、以下のルールを設定する。

- AWS Managed Rules Common Rule Set
- Rate-based Rule

検証時にはテスト用ルールを使用し、
WAFによるブロック動作を確認する。

## 7. 可用性設計

### 7.1 Multi-AZ構成

Webサーバーを異なる2つのAZに1台ずつ配置し、
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

### 7.4 復旧方針

本構成ではEC2の自動復旧は実装しない。

障害発生時はSession Managerを使用して原因を調査し、
必要に応じてNginxの再起動などを実施する。

Auto Scalingによる自動復旧は今後の拡張課題とする。

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
| EC2 | CPUUtilization | 80%以上が5分間継続 | SNS |
| EC2 | StatusCheckFailed | 1以上 | SNS |
| ALB | HealthyHostCount | 2未満 | SNS |
| ALB | HTTPCode_Target_5XX_Count | 5分間で5件以上 | SNS |

### 8.3 通知設計

CloudWatchアラームがALARM状態になった場合、
Amazon SNSを使用して管理者へメール通知する。

SNSトピックを作成し、通知先メールアドレスを登録する。

### 8.4 障害時の対応

アラーム発生時はCloudWatchで対象メトリクスを確認し、
異常が発生しているリソースを特定する。

EC2の調査が必要な場合はSession Managerで接続し、
Nginxの稼働状況やログを確認する。

原因を特定した後、必要に応じてNginxの再起動などを実施する。

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

ログの保存期間は7日間とする。

## 9. 運用・管理設計

### 9.1 運用方針

本システムは学習・検証用の環境とし、
常時稼働は行わない。

AWSリソースの構成管理にはTerraformを使用し、
サーバーの管理にはSystems Manager Session Managerを使用する。

### 9.2 構成管理

- AWSリソースは原則としてTerraformで作成・変更・削除する
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
- ログの保存期間は7日間とする
- 障害発生時はCloudWatch Logsでログを確認する
- 必要に応じてSession ManagerでEC2に接続し、詳細調査を行う

### 9.6 更新管理

- AMIは選定したバージョンを固定して使用する
- AMIやミドルウェアの更新時は動作検証を行う
- 変更内容はGitHubで管理する

### 9.7 コスト管理

- 学習・検証時のみAWSリソースを稼働させる
- 検証終了後はterraform destroyで管理対象リソースを削除する
- Route 53の既存ドメインとホストゾーンは削除対象に含めない
- 検証後はAWSコンソールでリソースの削除状況を確認する
