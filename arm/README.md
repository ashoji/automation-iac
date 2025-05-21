# ARM テンプレートによる IaC 自動化 (Azure Automation)

このフォルダには、Azure Automation Runbook から PowerShell を利用して ARM JSON テンプレートをデプロイし、Azure Web Apps と Azure SQL Database をプロビジョニングするためのファイル一式が含まれています。

---
## 目次
- [ARM テンプレートによる IaC 自動化 (Azure Automation)](#arm-テンプレートによる-iac-自動化-azure-automation)
  - [目次](#目次)
  - [概要](#概要)
  - [前提条件](#前提条件)
  - [フォルダ構成](#フォルダ構成)
  - [パラメーター](#パラメーター)
  - [Azure Automation での実行方法](#azure-automation-での実行方法)
  - [運用・セキュリティ](#運用セキュリティ)

---
## 概要
- **ARM JSON テンプレート**で Web App (`webApp.json`) と SQL Database (`sqlDatabase.json`) を分離管理
- PowerShell スクリプト (`deploy.ps1`) から以下を実行
  1. Managed Identity で認証
  2. Blob Storage から ARM テンプレートをダウンロード
  3. ARM テンプレートの What-If 検証
  4. 本番デプロイ
  5. Web App URL／SQL FQDN の出力

---
## 前提条件
- Azure Automation アカウント（PowerShell 7 Runbook 推奨）
- Az モジュールインポート済み
  - `Az.Accounts`, `Az.Resources`, `Az.Storage`
- Runbook に割り当てた**マネージド ID**に Contributor 権限以上を付与
- Storage アカウントに ARM JSON テンプレート一式を保存済み

---
## フォルダ構成
```text
arm/
 ├─ main.json          # メインの ARM テンプレート 
 ├─ webApp.json        # Web App モジュール (ネステッド テンプレート)
 ├─ sqlDatabase.json   # SQL Database モジュール (ネステッド テンプレート)
 └─ deploy.ps1         # Runbook 用 PowerShell スクリプト
```

---
## パラメーター
| スクリプトパラメーター       | 説明                                    | 
|----------------------------|-----------------------------------------|
| `ResourceGroupName`         | デプロイ先のリソース グループ名            |
| `StorageAccountResourceGroupName` | ストレージ アカウントのリソース グループ名 |
| `StorageAccountName`        | テンプレートを保存しているストレージ アカウント名 |
| `StorageContainerName`      | テンプレートを保存しているコンテナ名        |
| `JsonTemplateFileName`      | メインテンプレートのファイル名（デフォルト: main.json） |

| テンプレートパラメーター    | 説明                            | 例            |
|----------------------------|---------------------------------|---------------|
| `webAppName`               | Web App 名                      | `myWebApp`    |
| `appServicePlanName`       | App Service Plan 名             | `myPlan`      |
| `sqlServerName`            | SQL Server 名                   | `mySqlServer` |
| `sqlDatabaseName`          | SQL Database 名                 | `myDatabase`  |
| `administratorLogin`       | SQL 管理者ユーザー名            | `sqlAdmin`    |
| `administratorLoginPassword` | SQL 管理者パスワード（Secure） | `P@ssw0rd...` |
| `location`                 | リソース配置リージョン          | `japaneast`   |

---
## Azure Automation での実行方法
1. ARM JSON テンプレートを Azure Blob Storage にアップロード
   ```powershell
   # ストレージ アカウントに接続
   $ctx = Get-AzStorageAccount -ResourceGroupName "ストレージRG名" -Name "ストレージ名" | Get-AzStorageContext
   
   # JSONファイルをアップロード
   Get-ChildItem -Path "arm\*.json" | ForEach-Object {
       Set-AzStorageBlobContent -File $_.FullName -Container "templates" -Blob $_.Name -Context $ctx -Force
   }
   ```

2. Automation アカウント → **Runbook** → `PowerShell 7` を新規作成
3. スクリプトとして `deploy.ps1` を貼り付け
4. Runbook の**パラメーター**に
   - `$ResourceGroupName`
   - `$StorageAccountResourceGroupName`
   - `$StorageAccountName`
   - `$StorageContainerName`
   - `$JsonTemplateFileName`（オプション）
5. **モジュール**ギャラリーから `Az.Accounts`, `Az.Resources`, `Az.Storage` をインポート
6. マネージド ID に適切な権限を付与
   - デプロイ先リソース グループに Contributor 権限
   - ストレージ アカウントに Storage Blob Data Reader 権限
7. テスト → 「公開」→ スケジュール実行

---
## 運用・セキュリティ
- **シークレット管理**: パスワードは Key Vault または Automation Asset で管理
- **RBAC**: 最小権限の原則を順守
- **ロギング**: Automation のログストリームを活用してトラブルシューティング
- **監視**: Web App Application Insights、SQL Azure モニタリング連携推奨
- **セキュリティ**: Web App と SQL Server の Public IP アクセスをブロック済み

---
*このドキュメントは 2025年5月21日作成*
