# AWS Multi-AZ Web Infrastructure 詳細設計書

## 1. ネットワーク詳細設計

### 1.1 VPC設計

| 項目 | 設定値 |
|---|---|
| VPC名 | portfolio-vpc |
| CIDR | 10.0.0.0/16 |
| リージョン | ap-northeast-1 |
| DNS解決 | 有効 |
| DNSホスト名 | 有効 |

### 1.2 サブネット設計

| サブネット名 | AZ | CIDR | Public IP自動割り当て |
|---|---|---|---|
| portfolio-public-1a | ap-northeast-1a | 10.0.1.0/24 | 有効 |
| portfolio-public-1c | ap-northeast-1c | 10.0.2.0/24 | 有効 |
| portfolio-private-1a | ap-northeast-1a | 10.0.11.0/24 | 無効 |
| portfolio-private-1c | ap-northeast-1c | 10.0.12.0/24 | 無効 |

### 1.3 ルートテーブル設計

| ルートテーブル | 関連付けるサブネット | 主なルート |
|---|---|---|
| portfolio-public-rt | Public 1a・1c | 0.0.0.0/0 → IGW |
| portfolio-private-rt-1a | Private 1a | VPC内通信、S3 Gateway Endpoint |
| portfolio-private-rt-1c | Private 1c | VPC内通信、S3 Gateway Endpoint |

### 1.4 VPC Endpoint設計

| 種類 | サービス名 | 用途 | 関連付け・配置先 |
|---|---|---|---|
| Gateway | S3 | Amazon Linux 2023のパッケージ取得（Nginxなど） | Private Route Table 1a / 1c |
| Interface | SSM |  Systems ManagerによるEC2管理| Private Subnet 1a / 1c |
| Interface | SSM Messages | Session Managerの通信 | Private Subnet 1a / 1c |
| Interface | CloudWatch Logs | Nginxのログ送信 | Private Subnet 1a / 1c |

- NAT Gatewayは使用せず、VPC Endpointを利用してAWSサービスへプライベート接続する。
- Interface EndpointはPrivate DNSを有効にする。
- Interface Endpoint用Security Groupでは、EC2からのHTTPS（TCP 443）を許可する。
- S3 Gateway EndpointはPrivate Route Table 1a / 1cに関連付ける。

## 2. セキュリティ詳細設計

### 2.1 Security Group設計

#### ALB用Security Group

| 方向 | プロトコル | ポート | 送信元・宛先 |
|---|---|---|---|
| Inbound | TCP | 80 | 0.0.0.0/0 |
| Inbound | TCP | 443 | 0.0.0.0/0 |
| Outbound | TCP | 80 | EC2用SG |

#### EC2用Security Group

| 方向 | プロトコル | ポート | 送信元・宛先 |
|---|---|---|---|
| Inbound | TCP | 80 | ALB用SG |
| Outbound | TCP | 443 | Interface Endpoint用SG |
| Outbound | TCP | 443 | S3 Prefix List |

#### Interface Endpoint用Security Group

| 方向 | プロトコル | ポート | 送信元・宛先 |
|---|---|---|---|
| Inbound | TCP | 443 | EC2用SG |

### 2.2 IAMロール設計

EC2にIAMロールを付与し、Systems Managerによる管理と
CloudWatch Logsへのログ送信を可能にする。

| 項目 | 設定値 |
|---|---|
| IAMロール名 | portfolio-ec2-role |
| 信頼されたエンティティ | EC2 |
| マネージドポリシー① | AmazonSSMManagedInstanceCore |
| マネージドポリシー② | CloudWatchAgentServerPolicy |

- EC2にはインスタンスプロファイルを通じてIAMロールを付与する。
- S3へのアクセスはGateway Endpointを使用する。
- Amazon Linux 2023のパッケージ取得用に、EC2へ追加のS3 IAMポリシーは付与しない。
- IAMユーザーのアクセスキーをEC2内に保存しない。

## 3. EC2・Nginx詳細設計

### 3.1 EC2インスタンス設計

| 項目 | EC2-1a | EC2-1c |
|---|---|---|
| インスタンス名 | portfolio-web-1a | portfolio-web-1c |
| AZ | ap-northeast-1a | ap-northeast-1c |
| サブネット | Private Subnet 1a | Private Subnet 1c |
| AMI | Amazon Linux 2023 | Amazon Linux 2023 |
| インスタンスタイプ | t3.micro | t3.micro |
| EBS | gp3 / 8GiB | gp3 / 8GiB |
| パブリックIP | なし | なし |
| Security Group | EC2用SG | EC2用SG |
| IAMロール | portfolio-ec2-role | portfolio-ec2-role |
| SSHキーペア | なし | なし |

### 3.2 Nginx設計

| 項目 | 設定値 |
|---|---|
| Webサーバー | Nginx |
| 使用ポート | TCP 80 |
| 公開ディレクトリ | /usr/share/nginx/html |
| 公開ファイル | index.html |
| サービス起動 | systemd |
| 自動起動 | 有効 |
| HTTPS終端 | ALB |
| ヘルスチェックパス | / |

## 4. ALB・Target Group詳細設計

### 4.1 ALB設計

| 項目 | 設定値 |
|---|---|
| 項目	設定値
ALB名 | portfolio-alb |
| 種類 | Application Load Balancer |
| スキーム | Internet-facing |
| IPアドレスタイプ | IPv4 |
| 配置先 | Public Subnet 1a / 1c |
| Security Group | ALB用SG |
| HTTPリスナー | 80 → HTTPS 443へリダイレクト |
| HTTPSリスナー | 443 → Target Groupへ転送 |
| SSL/TLS証明書 | ACMで発行した www.kamino-infra.com 用証明書 |

### 4.2 Target Group設計

| 項目 | 設定値 |
|---|---|
| Target Group名 | portfolio-web-tg |
| ターゲットタイプ | Instance |
| プロトコル | HTTP |
| ポート | 80 |
| 登録ターゲット | EC2-1a / EC2-1c |
| ヘルスチェックプロトコル | HTTP |
| ヘルスチェックパス | / |
| 成功コード | 200 |
| ヘルスチェック間隔 | 30秒 |
| タイムアウト | 5秒 |
| 正常判定しきい値 | 2回 |
| 異常判定しきい値 | 2回 |

### 4.3 リスナー設計

| ポート | プロトコル | アクション |
|---|---|---|
| 80 | HTTP | HTTPS 443へ301リダイレクト |
| 443 | HTTPS | portfolio-web-tg へ転送 |

## 5. Route 53・ACM詳細設計

### 5.1 Route 53設計

| 項目 | 設定値 |
|---|---|
| ドメイン名 | `kamino-infra.com` |
| Hosted Zone | 既存のPublic Hosted Zoneを使用 |
| レコード名 | `www.kamino-infra.com` |
| レコードタイプ | A |
| Alias | 有効 |
| Alias先 | `portfolio-alb` |
| ルーティングポリシー | シンプルルーティング |

### 5.2 ACM設計

| 項目 | 設定値 |
|---|---|
| サービス | AWS Certificate Manager |
| 証明書タイプ | パブリック証明書 |
| ドメイン名 | `www.kamino-infra.com` |
| 検証方法 | DNS検証 |
| リージョン | `ap-northeast-1` |
| 使用先 | ALBのHTTPSリスナー（443） |


### 5.3 既存リソースの取り扱い

| リソース | 管理方針 |
|---|---|
| `kamino-infra.com` ドメイン | 既存のものを継続利用 |
| Public Hosted Zone | 既存のものを参照 |
| `www` のA Aliasレコード | 今回の構築で作成 |
| ACM証明書 | 今回の構築で作成 |
| ACM検証用CNAMEレコード | 今回の構築で作成 |

## 6. WAF詳細設計

### 6.1 Web ACL設計

| 項目 | 設定値 |
|---|---|
| Web ACL名 | `portfolio-web-acl` |
| サービス | AWS WAF |
| スコープ | REGIONAL |
| リージョン | `ap-northeast-1` |
| 関連付け先 | `portfolio-alb` |
| デフォルトアクション | Allow |
| CloudWatchメトリクス | 有効 |
| サンプリングリクエスト | 有効 |

### 6.2 WAFルール設計

AWSマネージドルールとレートベースルールを使用し、
一般的なWeb攻撃や同一IPアドレスからの大量アクセスを制限する

| 優先順位 | ルール名 | 種類 | アクション | 用途 |
|---|---|---|---|---|
| 0 | AWSManagedRulesCommonRuleSet | AWSマネージドルール | ルールに従う | 一般的なWeb攻撃への対策 |
| 1 | portfolio-rate-limit | レートベースルール | Block | 同一IPからの大量アクセスを制限 |

#### レートベースルールの設定

| 項目 | 設定値 |
|---|---|
| 集計キー | IPアドレス |
| 評価期間 | 5分 |
| しきい値 | 100リクエスト |
| アクション | Block |

- Web ACLのデフォルトアクションはAllowとする。
- AWSマネージドルールは各ルールに定義されたアクションを適用する。
- レートベースルールのしきい値は検証用の設定とし、実運用ではアクセス状況に応じて調整する。

### 6.3 WAFの動作確認

| テスト項目 | 確認内容 |
|---|---|
| 通常アクセス | Webページが正常に表示される |
| マネージドルール | WAFのメトリクスでルールの動作を確認する |
| レート制限 | テスト用の連続リクエストでBlockを確認する |
| ALBとの関連付け | Web ACLがALBに関連付けられていることを確認する |

## 7. CloudWatch・SNS詳細設計

### 7.1 CloudWatchアラーム設計

| アラーム名 | メトリクス | しきい値 | 評価期間 |
|---|---|---|---|
| `portfolio-ec2-cpu-high` | CPUUtilization | 80%以上 | 5分×2回 |
| `portfolio-ec2-status-check` | StatusCheckFailed | 1以上 | 1分×2回 |
| `portfolio-alb-unhealthy` | UnHealthyHostCount | 1以上 | 1分×2回 |
| `portfolio-alb-5xx` | HTTPCode_ELB_5XX_Count | 5回以上 | 5分×1回 |

### 7.2 CloudWatch Logs設計

| 項目 | 設定値 |
|---|---|
| ロググループ名 | `/portfolio/nginx` |
| ログ保存期間 | 7日 |
| ログ送信方法 | CloudWatch Agent |
| アクセスログ | `/var/log/nginx/access.log` |
| エラーログ | `/var/log/nginx/error.log` |
| ログストリーム | EC2インスタンスIDごとに分離 |

### 7.3 SNS通知設計

| 項目 | 設定値 |
|---|---|
| SNSトピック名 | `portfolio-alert-topic` |
| トピックタイプ | Standard |
| 通知プロトコル | Email |
| 通知先 | 自分のメールアドレス |
| 通知条件 | CloudWatchアラームがALARM状態になったとき |

## 8. 運用・テスト設計

### 8.1 運用設計

| 項目 | 運用方針 |
|---|---|
| インフラ管理 | TerraformでAWSリソースを管理する |
| EC2管理 | Systems Manager Session Managerを使用する |
| SSH接続 | 使用しない（TCP 22は開放しない） |
| Webサーバー管理 | systemdでNginxを管理する |
| ログ管理 | CloudWatch LogsでNginxログを確認する |
| 監視・通知 | CloudWatchアラームとSNSを使用する |
| 障害対応 | CloudWatchで異常を確認し、Session Managerで原因を調査する |
| コスト管理 | 検証終了後、作成したAWSリソースを削除する |

### 8.2 テスト設計

| No. | テスト項目 | テスト内容 | 期待結果 |
|---|---|---|---|
| T01 | HTTPS接続 | `https://www.kamino-infra.com` にアクセス | Webページが正常に表示される |
| T02 | HTTPリダイレクト | HTTPでアクセス | HTTPSへ301リダイレクトされる |
| T03 | ALB負荷分散 | 複数回Webページにアクセス | 2台のEC2への振り分けを確認できる |
| T04 | 障害試験 | 片方のEC2でNginxを停止 | 異常なEC2が振り分け対象から外れ、正常なEC2でWebページを表示できる |
| T05 | 復旧試験 | 停止したNginxを再起動 | ヘルスチェックが正常に戻り、振り分け対象に復帰する |
| T06 | Session Manager | Private EC2へ接続 | SSHを使用せずに接続できる |
| T07 | CloudWatch Logs | Nginxログを確認 | アクセスログ・エラーログが記録される |
| T08 | CloudWatchアラーム | Nginx停止による異常を発生させる | UnHealthyHostCountのアラームがALARM状態になる |
| T09 | SNS通知 | CloudWatchアラームを発報させる | 登録したメールアドレスに通知が届く |
| T10 | WAF | レート制限の動作を確認 | しきい値超過後にBlockが確認できる |
| T11 | セキュリティ | EC2のネットワーク設定を確認 | EC2にパブリックIPがなく、SSHポートも開放されていない |
| T12 | Terraform | `terraform apply` で環境を構築 | 設計したAWSリソースが正常に作成される |
| T13 | リソース削除 | `terraform destroy` を実行 | 今回作成したリソースが削除され、既存Hosted Zoneは維持される |

### 8.3 リソース削除・コスト管理

| 対象 | 方針 |
|---|---|
| EC2・ALB | 検証終了後に削除 |
| VPC Endpoint | 検証終了後に削除 |
| WAF | 検証終了後に削除 |
| CloudWatch・SNS | 今回作成したものを削除 |
| ACM証明書 | 今回作成したものを削除 |
| Route 53のA Aliasレコード | 今回作成したものを削除 |
| 既存Hosted Zone | 維持 |
| 既存ドメイン | 維持 |
