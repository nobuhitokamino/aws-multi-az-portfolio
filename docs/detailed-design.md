# AWS Multi-AZ Web Infrastructure 詳細設計書

## 1. ネットワーク詳細設計

### 1.1 VPC設計

| 項目 | 設定値 |
|---|---|
| VPC名 | aws-multi-az-portfolio-vpc |
| CIDR | 10.0.0.0/16 |
| リージョン | ap-northeast-1 |
| DNS解決 | 有効 |
| DNSホスト名 | 有効 |

### 1.2 サブネット設計

| サブネット名 | AZ | CIDR | Public IP自動割り当て |
|---|---|---|---|
| aws-multi-az-portfolio-public-1a | ap-northeast-1a | 10.0.1.0/24 | 無効 |
| aws-multi-az-portfolio-public-1c | ap-northeast-1c | 10.0.2.0/24 | 無効 |
| aws-multi-az-portfolio-private-1a | ap-northeast-1a | 10.0.11.0/24 | 無効 |
| aws-multi-az-portfolio-private-1c | ap-northeast-1c | 10.0.12.0/24 | 無効 |

### 1.3 ルートテーブル設計

| ルートテーブル | 関連付けるサブネット | 主なルート |
|---|---|---|
| aws-multi-az-portfolio-public-rt | Public 1a・1c | 0.0.0.0/0 → IGW |
| aws-multi-az-portfolio-private-rt | Private 1a・1c（1つを共用） | VPC内通信、S3 Gateway Endpoint |

### 1.4 VPC Endpoint設計

| 種類 | サービス名 | 用途 | 関連付け・配置先 |
|---|---|---|---|
| Gateway | S3 | Amazon Linux 2023のパッケージ取得（Nginxなど） | 共通Private Route Table |
| Interface | SSM |  Systems ManagerによるEC2管理| Private Subnet 1a / 1c |
| Interface | SSM Messages | Session Managerの通信 | Private Subnet 1a / 1c |
| Interface | CloudWatch Logs | Nginxのログ送信 | Private Subnet 1a / 1c |

- NAT Gatewayは使用せず、VPC Endpointを利用してAWSサービスへプライベート接続する。
- Interface EndpointはPrivate DNSを有効にする。
- Interface Endpoint用Security Groupでは、EC2からのHTTPS（TCP 443）を許可する。
- S3 Gateway Endpointは共通Private Route Tableに関連付ける。
- Private Route Tableにインターネットへのデフォルトルートは設定しない。Public SubnetはIGWへのルートによって外部公開用とし、Public IP自動割り当てとは区別する。

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

上記以外の明示的な許可ルールは定義しない。Interface Endpoint用SGのアウトバウンドルールは追加していない。
カスタムNetwork ACLは定義せず、VPCのデフォルトNACLを利用する。

### 2.2 IAMロール設計

EC2にIAMロールを付与し、Systems Managerによる管理と
CloudWatch Logsへのログ送信を可能にする。

| 項目 | 設定値 |
|---|---|
| IAMロール名 | aws-multi-az-portfolio-ec2-role |
| 信頼されたエンティティ | EC2 |
| マネージドポリシー① | AmazonSSMManagedInstanceCore |
| カスタムインラインポリシー | aws-multi-az-portfolio-nginx-logs-policy |
| インスタンスプロファイル | aws-multi-az-portfolio-ec2-profile |

- EC2にはインスタンスプロファイルを通じてIAMロールを付与する。
- 信頼ポリシーは `ec2.amazonaws.com` に `sts:AssumeRole` を許可する。
- ログ用ポリシーは `logs:CreateLogStream`、`logs:DescribeLogStreams`、`logs:PutLogEvents` をNginxロググループのARN（末尾 `:*`）に限定する。
- `logs:DescribeLogGroups` は `*` に許可する。CloudWatchAgentServerPolicyは付与しない。
- S3へのアクセスはGateway Endpointを使用する。
- Amazon Linux 2023のパッケージ取得用に、EC2へ追加のS3 IAMポリシーは付与しない。
- IAMユーザーのアクセスキーをEC2内に保存しない。

## 3. EC2・Nginx詳細設計

### 3.1 EC2インスタンス設計

| 項目 | AZ 1aの通常配置 | AZ 1cの通常配置 |
|---|---|---|
| インスタンスNameタグ | aws-multi-az-portfolio-web | aws-multi-az-portfolio-web |
| AZ | ap-northeast-1a | ap-northeast-1c |
| サブネット | Private Subnet 1a | Private Subnet 1c |
| AMI | Amazon Linux 2023 x86_64（SSMで動的取得） | 同一Launch TemplateバージョンのAMI |
| インスタンスタイプ | t3.micro | t3.micro |
| EBS | gp3 / 10GiB（暗号化・終了時削除） | gp3 / 10GiB（暗号化・終了時削除） |
| パブリックIP | なし | なし |
| Security Group | EC2用SG | EC2用SG |
| IAMロール | aws-multi-az-portfolio-ec2-role | aws-multi-az-portfolio-ec2-role |
| SSHキーペア | なし | なし |

上表は通常のAZ分散配置を示し、固定EC2リソースやAZごとの固定インスタンス名は定義しない。
EC2の配置・Target Group登録・置換はASGが管理する。

| 起動・自動復旧項目 | 設定値 |
|---|---|
| ASG名 | aws-multi-az-portfolio-web-asg |
| min / desired / max | 2 / 2 / 3（devから明示指定） |
| 起動先 | Private Subnet 1a / 1c |
| ヘルスチェック | ELB |
| 起動猶予 | 600秒 |
| Launch Template名 | aws-multi-az-portfolio-web-lt |
| ASGが使用するバージョン | Launch Templateのlatest_versionの番号 |
| AMI取得元 | `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` |
| メタデータ | IMDS有効、IMDSv2トークン必須 |
| ルートデバイス | `/dev/xvda` |
| Instance Refresh・負荷連動スケーリング | 定義なし |

起動猶予600秒は新規インスタンスのヘルスチェック猶予であり、障害検出から600秒以内の復旧を保証する値ではない。

AMIはdevルートのdata sourceで取得しcomputeモジュールに渡す。
実行時点で値が変わり得るため、同一AMIでの再現が必要な場合は取得したAMI IDを記録する。
Launch Templateの更新と既存インスタンスへの反映は分けて確認する。

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

User Dataは `terraform/templates/user_data.sh.tftpl` で生成する。
`dnf install -y nginx amazon-cloudwatch-agent` を実行し、`config/nginx.conf` を
`/etc/nginx/nginx.conf`、`userdata/index.html` を公開ディレクトリへ配置する。
`nginx -t` 成功後に `systemctl enable --now nginx` を実行する。
CloudWatch Agentの設定はcomputeモジュールで動的生成し、
`/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` に配置して起動する。
SSM Agentも有効化・起動し、初期化ログは `/var/log/user-data.log` に保存する。
`config/amazon-cloudwatch-agent.json` はUser Dataから参照されない旧設定である。

## 4. ALB・Target Group詳細設計

### 4.1 ALB設計

| 項目 | 設定値 |
|---|---|
| ALB名 | aws-multi-az-portfolio-alb |
| 種類 | Application Load Balancer |
| スキーム | Internet-facing |
| IPアドレスタイプ | IPv4 |
| 配置先 | Public Subnet 1a / 1c |
| Security Group | ALB用SG |
| HTTPリスナー | 80 → HTTPS 443へリダイレクト |
| HTTPSリスナー | 443 → Target Groupへ転送 |
| SSL/TLS証明書 | 既存ISSUEDの portfolio.kamino-infra.com 用ACM証明書を参照 |
| TLSポリシー | ELBSecurityPolicy-TLS13-1-2-2021-06 |
| 削除保護 | 無効 |
| アクセスログ | S3へ出力、prefix=alb、30日後に削除 |

### 4.2 Target Group設計

| 項目 | 設定値 |
|---|---|
| Target Group名 | aws-multi-az-portfolio-web-tg |
| ターゲットタイプ | Instance |
| プロトコル | HTTP |
| ポート | 80 |
| 登録ターゲット | ASG管理のEC2を自動登録・解除 |
| 登録解除待機時間 | 30秒 |
| ヘルスチェックプロトコル | HTTP |
| ヘルスチェックパス | / |
| ヘルスチェックポート | traffic-port（80） |
| 成功コード | 200 |
| ヘルスチェック間隔 | 30秒 |
| タイムアウト | 5秒 |
| 正常判定しきい値 | 2回 |
| 異常判定しきい値 | 2回 |

### 4.3 リスナー設計

| ポート | プロトコル | アクション |
|---|---|---|
| 80 | HTTP | HTTPS 443へ301リダイレクト |
| 443 | HTTPS | aws-multi-az-portfolio-web-tg へ転送 |

## 5. Route 53・ACM詳細設計

### 5.1 Route 53設計

| 項目 | 設定値 |
|---|---|
| ドメイン名 | `kamino-infra.com` |
| Hosted Zone | 既存のPublic Hosted Zoneを使用 |
| レコード名 | `portfolio.kamino-infra.com` |
| レコードタイプ | A |
| Alias | 有効 |
| Alias先 | `aws-multi-az-portfolio-alb` |
| ルーティングポリシー | シンプルルーティング |
| Aliasのevaluate_target_health | false |
| Hosted Zone ID | Z01357072PQWQ2VP8L9KP（既存を参照） |

### 5.2 ACM設計

| 項目 | 設定値 |
|---|---|
| サービス | AWS Certificate Manager |
| 証明書タイプ | パブリック証明書 |
| ドメイン名 | `portfolio.kamino-infra.com` |
| 検証方法 | 事前準備はDNS検証を前提とするが、現行コードでは検証方式を指定・確認しない |
| Terraformでの取得 | data aws_acm_certificate、statuses=[ISSUED]、most_recent=true |
| リージョン | `ap-northeast-1` |
| 使用先 | ALBのHTTPSリスナー（443） |


### 5.3 既存リソースの取り扱い

| リソース | 管理方針 |
|---|---|
| `kamino-infra.com` ドメイン | 既存のものを継続利用 |
| Public Hosted Zone | 既存のものを参照 |
| `portfolio` のA Aliasレコード | 今回の構築で作成 |
| ACM証明書 | 既存ISSUED証明書を参照（作成・削除しない） |
| ACM検証用CNAMEレコード | 現行Terraformの作成・管理対象外 |

## 6. WAF詳細設計

### 6.1 Web ACL設計

| 項目 | 設定値 |
|---|---|
| Web ACL名 | `aws-multi-az-portfolio-web-acl` |
| サービス | AWS WAF |
| スコープ | REGIONAL |
| リージョン | `ap-northeast-1` |
| 関連付け先 | `aws-multi-az-portfolio-alb` |
| デフォルトアクション | Allow |
| CloudWatchメトリクス | 有効 |
| サンプリングリクエスト | 有効 |

### 6.2 WAFルール設計

AWSマネージドルールと検証用カスタムヘッダ遮断ルールを使用し、
一般的なWeb攻撃への対策と明示的なブロック動作の確認を行う。

| 優先順位 | ルール名 | 種類 | アクション | 用途 |
|---|---|---|---|---|
| 0 | block-test-header | カスタムByte Match | Block | 検証用ヘッダの遮断 |
| 1 | AWSManagedRulesCommonRuleSet | AWSマネージドルール | ルールに従う（override_action=none） | 一般的なWeb攻撃への対策 |

#### 検証用ヘッダ遮断ルールの設定

| 項目 | 設定値 |
|---|---|
| 検査対象 | single_header: x-portfolio-test |
| 検索文字列 | block-me |
| 一致条件 | EXACTLY（完全一致） |
| 文字列変換 | NONE、優先順位0 |
| アクション | Block |

- Web ACLのデフォルトアクションはAllowとする。
- AWSマネージドルールは各ルールに定義されたアクションを適用する。
- ヘッダ遮断は検証用であり、レートベースルールは定義しない。
- WAFログは `aws-waf-logs-aws-multi-az-portfolio` へ14日保持とし、default_behavior=DROP、BLOCKのみKEEP（MEETS_ANY）とする。
- WAFログは過去のplan確認済みだが、applyとCloudWatch Logsへの配送確認は未実施である。

### 6.3 WAFの動作確認

| テスト項目 | 確認内容 |
|---|---|
| 通常アクセス | Webページが正常に表示される |
| マネージドルール | WAFのメトリクスでルールの動作を確認する |
| ヘッダ遮断 | `x-portfolio-test: block-me` を付与してHTTP 403を確認する |
| BLOCKログ | CloudWatch Logsへの配送を確認する（未検証） |
| ALBとの関連付け | Web ACLがALBに関連付けられていることを確認する |

## 7. CloudWatch・SNS詳細設計

### 7.1 CloudWatchアラーム設計

| アラーム名 | メトリクス | しきい値 | 評価期間 |
|---|---|---|---|
| `aws-multi-az-portfolio-ec2-high-cpu` | CPUUtilization（ASG単位・Average） | 80%以上 | 5分×2回 |
| `aws-multi-az-portfolio-alb-unhealthy-host` | UnHealthyHostCount（Maximum） | 1以上 | 1分×2回 |
| `aws-multi-az-portfolio-alb-5xx` | HTTPCode_ELB_5XX_Count（Sum） | 1件以上 | 1分×1回 |

CPUは `AWS/EC2`、ディメンションは `AutoScalingGroupName` とする。
ALBの2項目は `AWS/ApplicationELB` とし、5XXは `LoadBalancer`、
UnHealthyHostCountは `LoadBalancer` と `TargetGroup` を指定する。
欠損データの扱いはCPUで `missing`、ALBの2項目で `notBreaching` とする。
比較演算子は全て `GreaterThanOrEqualToThreshold` とする。
StatusCheckFailed、HealthyHostCount、HTTPCode_Target_5XX_Countのアラームは定義しない。

### 7.2 CloudWatch Logs設計

| 項目 | 設定値 |
|---|---|
| ロググループ名 | `/aws-multi-az-portfolio/dev/nginx` |
| ログ保存期間 | 14日 |
| ログ送信方法 | CloudWatch Agent |
| アクセスログ | `/var/log/nginx/access.log` |
| エラーログ | `/var/log/nginx/error.log` |
| ログストリーム | `{instance_id}/access`、`{instance_id}/error` |

| その他のログ項目 | 設定値 |
|---|---|
| ALBログ用S3バケット | `aws-multi-az-portfolio-alb-logs-<AWSアカウントID>` |
| ALBログ保存先 | `alb/AWSLogs/<AWSアカウントID>/` 配下 |
| ALBログ保持 | `alb/` 配下をライフサイクルで30日後に削除 |
| S3暗号化・所有権 | SSE-S3（AES256）、BucketOwnerEnforced |
| S3公開制御 | Public Access Blockの4項目全てtrue |
| ALB配送権限 | `logdelivery.elasticloadbalancing.amazonaws.com` に対象prefixへの `s3:PutObject` を許可、SourceArnは同一アカウント・リージョンのALBに制限 |
| WAFロググループ | `aws-waf-logs-aws-multi-az-portfolio` |
| WAFログ保持・対象 | 14日、BLOCKのみ保存 |
| WAFログ検証状況 | 過去のplan確認済み、apply・配送未検証 |

### 7.3 SNS通知設計

| 項目 | 設定値 |
|---|---|
| SNSトピック名 | `aws-multi-az-portfolio-alarms` |
| トピックタイプ | Standard |
| 通知プロトコル | Email |
| 通知先 | 変数alert_email（sensitive=true）、メール購読承認が必要 |
| 通知条件 | CloudWatchアラームがALARMまたはOKへ遷移したとき |

SNSトピックポリシーは同一アカウントrootによるトピック管理を許可する。
CloudWatchサービスのPublishは `aws:SourceAccount` と
`arn:aws:cloudwatch:ap-northeast-1:<AWSアカウントID>:alarm:aws-multi-az-portfolio-*` に制限する。

## 8. 運用・テスト設計

### 8.1 運用設計

| 項目 | 運用方針 |
|---|---|
| インフラ管理 | TerraformでAWSリソースを管理する（既存Hosted Zone・ACMは参照） |
| State管理 | S3 Backend。State用S3はterraform/bootstrapで別管理 |
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
| T01 | HTTPS接続 | `https://portfolio.kamino-infra.com` にアクセス | Webページが正常に表示される |
| T02 | HTTPリダイレクト | HTTPでアクセス | HTTPSへ301リダイレクトされる |
| T03 | ALB負荷分散 | ALBへ複数回アクセスし、NginxまたはALBのアクセスログから転送先を確認する | 異なるAZに配置された2台のEC2へのリクエスト転送を確認できる |
| T04 | 障害試験 | 片方のEC2でNginxを停止 | 異常なEC2が振り分け対象から外れ、正常なEC2でWebページを表示できる |
| T05 | 復旧試験 | ELBヘルスチェックによるASGの異常インスタンス置換を確認 | 新規EC2がUser Dataで初期化され、healthyへ復帰する |
| T06 | Session Manager | Private EC2へ接続 | SSHを使用せずに接続できる |
| T07 | CloudWatch Logs | Nginxログを確認 | アクセスログ・エラーログが記録される |
| T08 | CloudWatchアラーム | 片方のEC2でNginxを停止し、ALBのターゲット状態、CloudWatchメトリクス、ASGの置換動作を確認する | UnHealthyHostCountがアラーム条件を満たした場合にALARMへ遷移することを確認する |
| T09 | SNS通知 | CloudWatchアラームをALARM状態およびOK状態へ遷移させる | それぞれの状態遷移時に登録したメールアドレスへSNS通知が届く |
| T10 | WAF | `x-portfolio-test: block-me` を付与してアクセス | 遮断対象はHTTP 403、通常アクセスはHTTP 200 |
| T11 | セキュリティ | EC2のネットワーク設定を確認 | EC2にパブリックIPがなく、SSHポートも開放されていない |
| T12 | Terraform | `terraform apply` で環境を構築 | 設計したAWSリソースが正常に作成される |
| T13 | リソース削除 | dev環境で `terraform destroy` を実行 | dev環境のTerraform管理対象リソースが削除され、既存Hosted Zone・ACM証明書および別管理のState用S3バケットが維持される |
| T14 | WAFログ | apply後にヘッダ遮断を発生させてログを確認 | CloudWatch LogsにBLOCKログが配送される（未検証） |
| T15 | ALBログ | S3のalb/配下を確認 | アクセスログの保存を確認（今回の照合では配送未検証） |

上表はテスト設計・期待結果であり、一律の合格実績ではない。

検証状況はTerraform定義・過去のAWS実機確認・未検証を区別する。
過去にNginx停止、ALBのhealthy/unhealthy遷移、ASGによるインスタンス置換、
片系障害中に観測したHTTP 200の継続を確認している。AZ全体の障害試験は未実施である。
WAF BLOCKログは過去のTerraform planで確認済みだが、applyとCloudWatch Logsへの配送確認は未実施である。
今回の照合はコードと資料の静的確認であり、AWS実機試験やplanの再実行は行っていない。
その他の過去の確認内容と根拠、未検証事項は[照合結果](reconciliation.md)に記録する。

### 8.3 リソース削除・コスト管理

| 対象 | 方針 |
|---|---|
| EC2・ALB | ASG・Launch Templateを含め検証終了後に削除 |
| ALBログ用S3 | force_destroy=trueのため保存ログを含め削除可能（保持日数より先に削除され得る） |
| State用S3 | bootstrapで別管理、prevent_destroy=true、force_destroy=false、バージョニング・SSE-S3・公開禁止 |
| VPC Endpoint | 検証終了後に削除 |
| WAF | 検証終了後に削除 |
| CloudWatch・SNS | 今回作成したものを削除 |
| ACM証明書 | 既存の参照リソースのため維持 |
| Route 53のA Aliasレコード | 今回作成したものを削除 |
| 既存Hosted Zone | 維持 |
| 既存ドメイン | 維持 |
