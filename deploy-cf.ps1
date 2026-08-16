# LP1 を Cloudflare Workers へ 1 コマンドでデプロイ + 検証する
# 使い方: powershell -ExecutionPolicy Bypass -File .\deploy-cf.ps1
# 正本: memory/project-cloudflare.md（本体を更新したら必ずこれを叩く＝Workers側の取り残し防止）
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 1) dist/ を毎回作り直し（公開ホワイトリストのみ。フォルダ直デプロイは内部ファイル混入するので禁止）
if (Test-Path "$root\dist") { Remove-Item -Recurse -Force "$root\dist" }
New-Item -ItemType Directory -Force "$root\dist\assets" | Out-Null
Copy-Item "$root\index.html", "$root\script.js", "$root\style.css" "$root\dist\"
Copy-Item "$root\assets\*.png" "$root\dist\assets\"

# 2) workers.dev 限定の noindex（試験公開ガード。段階②=URL張り替え時にこのブロックの削除を判断）
#    canonical は Vercel を指しとる（index.html）＝並行公開の正。二重防御としてヘッダでも検索除外。
@'
https://lp-excel-automation.hirobuilds7.workers.dev/*
  X-Robots-Tag: noindex
https://:version.lp-excel-automation.hirobuilds7.workers.dev/*
  X-Robots-Tag: noindex
'@ | Out-File -Encoding ascii "$root\dist\_headers"

# 3) デプロイ
npx --yes wrangler deploy
if ($LASTEXITCODE -ne 0) { Write-Error "wrangler deploy failed (exit $LASTEXITCODE)" }

# 4) 検証＝「出荷される値そのもの」を見る（本文MD5をdistと突合 + ヘッダ実測）
$base = "https://lp-excel-automation.hirobuilds7.workers.dev"
$files = @("index.html", "script.js", "style.css", "assets/kintone-arari.png", "assets/process-manager.png", "assets/sales-report.png")
$fail = 0
foreach ($f in $files) {
  $localPath = Join-Path "$root\dist" ($f -replace '/', '\')
  $local = (Get-FileHash -Algorithm MD5 $localPath).Hash
  $tmp = [System.IO.Path]::GetTempFileName()
  curl.exe -sL --max-time 30 -o $tmp "$base/$f"
  $remote = (Get-FileHash -Algorithm MD5 $tmp).Hash
  Remove-Item $tmp -Force
  if ($local -eq $remote) { Write-Output ("OK  {0}  {1}" -f $f, $remote) }
  else { Write-Output ("NG  {0}  local={1} remote={2}" -f $f, $local, $remote); $fail++ }
}
Write-Output "--- headers (X-Robots-Tag が出とるか目視) ---"
curl.exe -sI "$base/"
Write-Output "--- _headers 自体が配信されてへんか (404 が正) ---"
curl.exe -s -o NUL -w "GET /_headers -> HTTP %{http_code}`n" "$base/_headers"
if ($fail -gt 0) { Write-Error ("VERIFY FAILED: {0} file(s) mismatch" -f $fail) }
Write-Output "VERIFY OK: 6/6 hash match"
