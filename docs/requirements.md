# AWS Multi-AZ Web Infrastructure

## 1. システムの目的

AWS上に、高可用性とセキュリティを考慮したWebサーバー環境を構築する。
Webサーバーの障害発生時にもサービスを継続できる構成とし、外部からの不要なアクセスを制限する。
また、監視機能を導入するとともに、Terraformを利用してインフラ環境の構築を自動化する。

## 2. 機能要件

- インターネットからWebページを閲覧できる
- HTMLで作成したWebページを配信できる
- 独自ドメインを使用してWebページを公開できる
- HTTPでアクセスした場合はHTTPSへリダイレクトする

## 3. 非機能要件

| 分類 | 要件 |
|---|---|
| 可用性 | Webサーバー1台が停止してもサービスを継続できる |
| セキュリティ | Webサーバーをインターネットに直接公開しない |
| ネットワーク | 外部公開部分とWebサーバーを分離する |
| 通信の暗号化 | ACM証明書を使用し、利用者とALB間の通信をHTTPSで暗号化する |
| 監視 | CloudWatchを利用し、ASG内EC2の平均CPU使用率、ALBの異常ターゲット数とALB生成5XXを監視し、SNS通知できる |
| Webセキュリティ | AWS WAFをALBに関連付け、マネージドルールによるWeb攻撃対策を実施する。また、検証用ヘッダ遮断ルールを設定し、リクエストの遮断動作を確認できるようにする |
| 保守性 | Terraformで構成を再構築できる（最新AMIの動的取得により、実行時点でAMIは変わり得る） |
| コスト | 検証終了後はリソースを削除する |

## 4. テスト・検証要件

| テスト項目 | 確認内容 |
|---|---|
| Web表示 | ALB経由でHTMLページが表示される |
| 負荷分散 | ASG管理の通常2台（min=2 / desired=2 / max=3）のEC2に通信が振り分けられる |
| 障害試験 | 片方のEC2でNginxを停止し、ALBが異常を検知した後、正常なEC2からWebページが提供され、ELBヘルスチェックを使うASGが異常インスタンスを自動置換することを確認する |
| HTTPS通信 | 独自ドメインでHTTPS接続でき、証明書エラーが発生しない |
| リダイレクト | HTTPでアクセスするとHTTPSへ301リダイレクトされる |
| セキュリティ | EC2へインターネットから直接アクセスできない |
| 監視 | CloudWatchで稼働状況を確認できる |
| WAF | `x-portfolio-test: block-me` を含むリクエストがブロックされることを確認する |
| WAFログ | BLOCKログがCloudWatch Logsへ配送され14日保持の設定になっていることを確認する（plan確認済み、apply・配送未検証） |
| Terraform | コードから構成を再構築できる（実行時のAMI IDを記録する） |


検証状況はTerraform定義・過去のAWS実機確認・未検証を区別する。
過去にNginx停止、ALBのhealthy/unhealthy遷移、ASGによるインスタンス置換、
片系障害中に観測したHTTP 200の継続を確認している。AZ全体の障害試験は未実施である。
WAF BLOCKログは過去のTerraform planで確認済みだが、applyとCloudWatch Logsへの配送確認は未実施である。
今回の照合はコードと資料の静的確認であり、AWS実機試験やplanの再実行は行っていない。
その他の過去の確認内容と根拠、未検証事項は[照合結果](reconciliation.md)に記録する。

## 5. 前提条件・制約事項

- AWSリージョンは東京（ap-northeast-1）を使用する
- WebサーバーはAmazon Linux 2023とNginxを使用する
- AMIはSSM Public Parameterから動的に取得し、Launch TemplateとUser Dataで起動する
- NAT Gatewayを使用せず、S3 Gateway EndpointとSSM・SSM Messages・CloudWatch Logs Interface Endpointを利用する
- 公開先は `https://portfolio.kamino-infra.com` とし、既存Hosted Zoneと既存ISSUED ACM証明書を参照する
- Webページは静的HTMLとし、データベースは使用しない
- 学習・検証用の環境とし、本番運用は想定しない
- コストを抑えるため、検証終了後はAWSリソースを削除する
  
