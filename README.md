# infrastructure-as-code (Azure Automation)

このリポジトリは、Azure Automation Runbook から PowerShell を利用して Bicep テンプレートをデプロイし、Azure Web Apps と Azure SQL Database を自動化するサンプルです。

---
## 目次
1. [概要](#概要)
2. [前提条件](#前提条件)
3. [プロジェクト構成](#プロジェクト構成)
4. [パラメーター](#パラメーター)
5. [ローカルでの実行方法](#ローカルでの実行方法)
6. [Azure Automation へのデプロイ方法](#azure-automation-へのデプロイ方法)
7. [運用・セキュリティ](#運用・セキュリティ)

---
## 概要
- **Bicep モジュール**で Web App (`webApp.bicep`) と SQL Database (`sqlDatabase.bicep`) を分離管理
- PowerShell スクリプト (`deploy.ps1`) から以下を実行
  1. Managed Identity で認証
  2. リソースグループ作成
  3. Bicep テンプレートの What-If 検証
  4. 本番デプロイ
  5. Web App URL／SQL FQDN の出力

---
## 前提条件
- Azure Automation アカウント（PowerShell 7 Runbook 推奨）
- Az モジュールインポート済み
  - `Az.Accounts`, `Az.Resources`, `Az.Websites`, `Az.Sql`
- Runbook に割り当てた**マネージド ID**に Contributor 権限以上を付与
- Bicep CLI 非必須（Az.Resources モジュール v2.22+ が自動コンパイル対応）

---
## プロジェクト構成
```text
infra/
 ├─ main.bicep          # モジュール呼び出し元
 ├─ webApp.bicep        # App Service Plan + Web App
 ├─ sqlDatabase.bicep   # SQL Server + Database + Firewall
 └─ deploy.ps1          # Runbook 用 PowerShell スクリプト
.gitignore              # ビルド／環境ファイル除外設定
```

---
## パラメーター
| パラメーター               | 説明                            | 例            |
|----------------------------|---------------------------------|---------------|
| `webAppName`               | Web App 名                      | `myWebApp`    |
| `appServicePlanName`       | App Service Plan 名             | `myPlan`      |
| `sqlServerName`            | SQL Server 名                   | `mySqlServer` |
| `sqlDatabaseName`          | SQL Database 名                 | `myDatabase`  |
| `administratorLogin`       | SQL 管理者ユーザー名            | `sqlAdmin`    |
| `administratorLoginPassword` | SQL 管理者パスワード（Secure） | `P@ssw0rd...` |
| `location`                 | リソース配置リージョン          | `japanwest`   |

---
## ローカルでの実行方法
```bash
git clone <repo-url>
cd automation-iac/infra
# リソースグループ作成
az group create -n my-rg -l japanwest
# What-If で検証
az deployment group what-if \
  --resource-group my-rg \
  --template-file main.bicep \
  --parameters \
    webAppName=myWebApp \
    appServicePlanName=myPlan \
    sqlServerName=mySqlServer \
    sqlDatabaseName=myDatabase \
    administratorLogin=sqlAdmin \
    administratorLoginPassword=P@ssw0rd1234 \
    location=japanwest
# 本番デプロイ
az deployment group create \
  --resource-group my-rg \
  --template-file main.bicep \
  --parameters @params.json
```

---
## Azure Automation へのデプロイ方法
1. Automation アカウント → **Runbook** → `PowerShell 7` を新規作成
2. スクリプトとして `deploy.ps1` を貼り付け
3. Runbook の**パラメーター**に
   - `$ResourceGroupName`, `$TemplateFilePath`, `$Location`
   - `$administratorLoginPassword` は Automation Asset（資格情報ストア／変数）経由で渡す
4. **モジュール**ギャラリーから `Az.Accounts`, `Az.Resources`, `Az.Websites`, `Az.Sql` をインポート
5. マネージド ID に Contributor 付与
6. テスト → 「公開」→ スケジュール実行

---
## 運用・セキュリティ
- **シークレット管理**: パスワードは Key Vault または Automation Asset で管理
- **RBAC**: 最小権限の原則を順守
- **ロギング**: Automation のログストリームを活用してトラブルシューティング
- **監視**: Web App Application Insights、SQL Azure モニタリング連携推奨

---
*このドキュメントは 2025/05 作成*
