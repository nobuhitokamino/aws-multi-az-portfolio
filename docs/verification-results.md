# AWS Multi-AZ Web基盤 — 構築・動作検証結果

## 1. 検証概要

| 項目 | 内容 |
|---|---|
| プロジェクト | aws-multi-az-portfolio |
| 対象環境 | Terraform `terraform/environments/dev` |
| リージョン | AWS 東京リージョン（`ap-northeast-1`） |
| 検証期間 | 2026年10月20日〜21日（日本時間） |
| 検証方法 | Terraform実行結果、AWS CLI、HTTPSリクエスト、ALBアクセスログ、CloudWatch Logs／メトリクス、Auto Scalingアクティビティの照合 |
| 検証後の状態 | Terraformで作成した55リソースを削除済み。Terraform Stateの管理対象は0件 |

本検証の目的は、Terraformで構築したWeb基盤について、基本通信、Multi-AZ負荷分散、インスタンスの自動補充・自動交換、WAFによる遮断、ログ収集・通知・保存設定を確認することである。結果は実行時の記録に基づく。実施していない試験については、実施済みと扱わない。

## 2. 検証結果一覧

| ID | 試験項目 | 実測結果・確認事項 | 判定 |
|---|---|---|---|
| V-01 | Terraformによる構築 | `terraform apply`：55 added、0 changed、0 destroyed | PASS |
| V-02 | Multi-AZ配置・正常性 | EC2が `ap-northeast-1a` と `1c` に各1台。ASGが2台とも `InService`／`Healthy`、ALBターゲットも2台 `healthy` | PASS |
| V-03 | HTTPS／HTTPリダイレクト | HTTPSは `HTTP/2 200`、HTTPは `301` でHTTPSへリダイレクト | PASS |
| V-04 | ALB負荷分散 | HTTPSリクエスト30件すべて200。ALBアクセスログ上の処理先は1aが14件、1cが16件 | PASS |
| V-05 | EC2手動終了時の自動補充 | ASGの希望容量2のまま1台を終了。代替インスタンスを自動起動し、復旧後2台 `healthy`、HTTPS 200 | PASS |
| V-06 | Webサーバー停止による自動交換 | Nginx停止試験後、ASG履歴に `ELB system health check failure` による終了と代替インスタンスの起動成功を確認。復旧後ALBターゲット2台 `healthy`、HTTPS 200 | PASS |
| V-07 | 実障害時の異常メトリクス | `UnHealthyHostCount` の1分間の最大値が01:49、01:51（JST）にそれぞれ1。その他の確認した期間は0 | PASS（メトリクス記録） |
| V-08 | WAFカスタムルール | 通常リクエスト200、テストヘッダー付きリクエスト403。WAFログに `action=BLOCK`、`terminatingRuleId=block-test-header` を確認 | PASS |
| V-09 | CloudWatch／SNS通知経路 | SNSへ直接Publishしたメールを受信。`set-alarm-state` による模擬 `OK → ALARM` 遷移、SNSアクション成功、通知メール受信を確認 | PASS（模擬試験） |
| V-10 | Nginxログ収集 | CloudWatch Logsでアクセス／エラーログ用ストリームを確認。交換後の新EC2からアクセスログ（HTTP 200）を取得 | PASS（アクセスログ） |
| V-11 | ALBログ保存 | S3へ配送されたALBアクセスログから、負荷分散先を集計できた | PASS |
| V-12 | ログ保持・S3セキュリティ設定 | Nginx／WAFログ保持14日、ALBログは `alb/` を対象に30日で期限切れ。公開アクセスブロック4項目 `true`、SSE-S3（AES256）、`BucketOwnerEnforced`、バケットポリシー公開判定 `false` | PASS（設定確認） |
| V-13 | CPU／ALB 5xxアラーム設定 | CPUはASG名をディメンションとして平均CPU使用率を監視。ALB 5xxは `HTTPCode_ELB_5XX_Count` を監視。確認時はいずれも `OK` | PASS（設定確認のみ） |
| V-14 | Terraformによる削除 | `terraform destroy`：55 destroyed。実行後の `terraform state list` は出力なし | PASS |

※「PASS（設定確認）」は、設定内容を確認したことを意味し、アラームや保持期限の実動作まで検証したことを意味しない。

## 3. 主要な検証内容

### 3.1 Multi-AZと負荷分散

ALBのターゲットグループに登録された2台のEC2が、異なるAZ（`ap-northeast-1a`／`ap-northeast-1c`）で `healthy` となることを確認した。識別用クエリパラメータを付けてHTTPSリクエストを30回送信し、すべてHTTP 200を取得した。ALBアクセスログの処理先とEC2の配置AZを照合したところ、1a側14件（46.7%）、1c側16件（53.3%）だった。

これは**テストしたリクエストが2つのAZのターゲットに振り分けられた**ことを示す。常に均等に分散されること、任意の障害時にも通信が途切れないことまでは証明していない。

### 3.2 ASGによる自動補充と障害時の自動交換

**試験A：EC2の手動終了**

希望容量2を変更せずに1台を終了すると、ASGが代替インスタンスを起動した。交換後は2つのAZに各1台が稼働し、ALBターゲット2台が `healthy`、HTTPS応答は200だった。

**試験B：Nginx停止**

Webサーバー停止試験後のASGアクティビティに、`ELB system health check failure` を原因とするインスタンス終了と、異常インスタンスの置き換えを目的とした新インスタンスの起動が `Successful` と記録された。交換後は2台 `healthy`、HTTPS応答200を確認した。

試験Bでは `UnHealthyHostCount` の値が一時的に1となった。ただし、この実障害でCloudWatchアラームが `ALARM` へ遷移した履歴は確認できない。アラームは60秒間隔・2評価期間の設定であり、実測値は01:49が1、01:50が0、01:51が1、01:52が0と連続していなかった。したがって、**実障害でのSNS通知成功とは記載しない**。

なお、障害発生中の全リクエストを継続計測したわけではないため、無停止であったことや復旧所要時間の実測値は示していない。

### 3.3 WAFによるアクセス制御とログ

カスタムルール `block-test-header` に対し、通常のHTTPSリクエストは200、`x-portfolio-test: block-me` ヘッダーを付与したリクエストは403だった。同じテスト識別子に対応するWAFログに `BLOCK` と該当ルール名が記録された。これにより**設定したカスタムルールによる遮断とログ記録**を確認した。

AWSマネージドルール `AWSManagedRulesCommonRuleSet` の個別ルールについては、検知・遮断の実動作試験を行っていない。

### 3.4 監視・通知・ログ保持

CloudWatchのアラーム3種類（ALB 5xx、異常ターゲット数、EC2 CPU）について、設定と確認時点の状態を調査した。CPUアラームのディメンションは `AutoScalingGroupName` であり、特定EC2のインスタンスIDには固定されていない。これはASG内の複数インスタンスを対象とする平均CPU使用率の監視であり、個別インスタンスのCPU高騰を必ず検出できるものではない。

SNS単独の送信試験に加え、CloudWatchの `set-alarm-state` を使った**模擬アラーム試験**でSNSアクション成功とメール受信を確認した。CPU高負荷、ALB自身の5xx発生については実際の閾値超過試験を実施していない。

CloudWatch LogsではNginxアクセスログの実イベントを取得でき、ASGによる交換後のEC2からもログが到着した。Nginxのエラーログはストリームの存在を確認したが、実際のエラーイベント生成・到着は未検証。Nginx・WAFログの保持期間は各14日だった。

S3ではALBアクセスログの配送と30日後に期限切れとするライフサイクルルールの有効化を確認した。S3パブリックアクセスブロック4項目、デフォルト暗号化（SSE-S3）、ACL無効化（`BucketOwnerEnforced`）、バケットポリシーの非公開判定も確認した。14日・30日経過後の実削除は未検証。

## 4. 実施範囲と制約

- CloudWatchの実障害メトリクスは記録されたが、**実障害による `ALARM` 遷移・SNSメール通知は未達成**。模擬アラームによる通知とは区別する。
- CPU高負荷とALB 5xxアラームは、設定確認のみで実際の閾値超過・通知試験は未実施。
- Nginxエラーログはストリームの存在まで確認。エラーイベントの配送確認は未実施。
- Multi-AZでの障害復旧後の正常状態は確認したが、通信の完全な無停止性・RTO／RPOを計測したものではない。
- `terraform destroy` による55件の削除とTerraform Stateの空状態を確認したが、**既存のHosted Zone・ACM証明書・Terraformバックエンドなど、今回のState管理外のリソースはこの結果に含まれない**。

## 5. 証跡の管理

検証時のCLI出力はローカルの `docs/evidence/logs/` に保存した（例：`alb-load-test.txt`、`asg-nginx-failure.json`、`unhealthy-metric.txt`、`nginx-new-instance-access.txt`、`alb-s3-lifecycle.json`）。スクリーンショットの原本は別途Mac上に保管している。

**公開方針：** 生ログ・スクリーンショットにはAWSアカウントID、インスタンスID、IPアドレス、アクセス元情報などが含まれる可能性がある。内容を確認・マスキングするまではGitHubに追加せず、本レポートでは必要な検証結果のみ要約する。

## 6. 結論

TerraformによってWeb基盤の55リソースを構築し、Multi-AZの負荷分散、EC2の自動補充、ELBヘルスチェック失敗を契機とするASGの自動交換、WAFのカスタム遮断、各種ログの収集・保持設定、および模擬アラームによるメール通知を確認した。検証後は55リソースを削除した。未検証のアラーム動作や無停止性については、今後の改善課題として区別している。
