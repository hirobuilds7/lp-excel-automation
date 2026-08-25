# LP1（Excel自動化LP）を Cloudflare Workers へ 1 コマンドでデプロイ + 検証する
# 使い方: powershell -ExecutionPolicy Bypass -File .\deploy-cf.ps1
# 正本: memory/project-cloudflare.md（本体を更新したら必ずこれを叩く＝Workers側の取り残し防止）
#
# 🔴 2026-08-25 段階② で書き換えた点3つ
#   (1) 配るファイルが変わった＝新版は assets/shots/*.webp を7枚使う（旧版の assets/*.png 3枚は未参照）
#   (2) noindex ブロックを削除＝★LP1は本物の営業面（架空ブランドやない）＝検索に出す側。
#       同時に index.html の canonical / og:url / og:image を Workers URL へ寄せた＝Workers が正。
#   (3) 検証を dist の実体走査に変えた＝ファイルを足しても検証リストの更新漏れが起きん
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# 1) dist/ を毎回作り直し（公開ホワイトリストのみ。フォルダ直デプロイは内部ファイル混入するので禁止）
if (Test-Path "$root\dist") { Remove-Item -Recurse -Force "$root\dist" }
New-Item -ItemType Directory -Force "$root\dist\assets\shots" | Out-Null
Copy-Item "$root\index.html", "$root\script.js", "$root\style.css" "$root\dist\"
Copy-Item "$root\assets\shots\*.webp" "$root\dist\assets\shots\"
# og:image だけは png を配る（webp は OGP 側の対応が媒体でまちまち）
Copy-Item "$root\assets\shots\ui-01-sales-dashboard.png" "$root\dist\assets\shots\"

# 混入チェック＝LP2 で踏んだ「生成元の重い原本が同居しとる」型の再発防止
$distSize = (Get-ChildItem -Recurse -File "$root\dist" | Measure-Object -Property Length -Sum).Sum
Write-Output ("dist = {0:N2} MB / {1} files" -f ($distSize / 1MB), (Get-ChildItem -Recurse -File "$root\dist").Count)
if ($distSize -gt 5MB) { Write-Error "dist が 5MB 超＝原本の混入を疑う" }

# 2) 参照切れチェック＝index.html が指しとる相対アセットが dist に居るか（デプロイ前に落とす）
$refs = [regex]::Matches((Get-Content -Raw "$root\dist\index.html"), '(?:src|href)="(?!https?:|data:|#)([^"]+)"') |
  ForEach-Object { $_.Groups[1].Value }
$missing = 0
foreach ($r in ($refs | Sort-Object -Unique)) {
  $p = Join-Path "$root\dist" ($r -replace '/', '\')
  if (-not (Test-Path $p)) { Write-Output ("MISSING {0}" -f $r); $missing++ }
}
if ($missing -gt 0) { Write-Error ("index.html が参照する {0} 件が dist に無い" -f $missing) }

# 3) デプロイ
npx --yes wrangler deploy
if ($LASTEXITCODE -ne 0) { Write-Error "wrangler deploy failed (exit $LASTEXITCODE)" }

# 4) 検証＝「出荷される値そのもの」を見る（本文MD5をdistと突合 + ヘッダ実測）
$base = "https://lp-excel-automation.hirobuilds7.workers.dev"

# ★伝播待ち＝デプロイ直後は数十秒ほど 404 を返す（2026-08-25 に LP2 側で実測：
#   直後に検証して19/22がNG、remote の MD5 が全部同一＝同じ404本文を掴んどった）。
#   待たずに鳴らすと「毎回失敗するゲート」になって誰も見んようになる＝先に200を待つ。
Write-Output "伝播待ち..."
# 🔴🔴 2026-08-25 追記＝「200が返る」だけでは足りんかった。
#   PFサイトで favicon を足して再デプロイした直後、**1回目の取得だけ旧版の index.html が返った**
#   （CF-Cache-Status: HIT・十数秒で新版に入れ替わる）。200待ちのゲートはこれを素通しして
#   検証段で「NG index.html」と鳴る＝★待つべきは200やなく「中身が新版になること」。
$localIndex = (Get-FileHash -Algorithm MD5 "$root\dist\index.html").Hash
$ready = $false
for ($i = 1; $i -le 30; $i++) {
  $tmp = [System.IO.Path]::GetTempFileName()
  curl.exe -sL --max-time 10 -o $tmp "$base/"
  $remoteIndex = (Get-FileHash -Algorithm MD5 $tmp).Hash
  Remove-Item $tmp -Force
  if ($remoteIndex -eq $localIndex) { Write-Output ("  {0}回目で新版の index.html が返った" -f $i); $ready = $true; break }
  Start-Sleep -Seconds 3
}
if (-not $ready) { Write-Error "90秒待っても新版の index.html が返らん＝デプロイを疑う" }

$prefix = "$root\dist\"
$files = Get-ChildItem -Recurse -File "$root\dist" |
  ForEach-Object { $_.FullName.Substring($prefix.Length) -replace '\\', '/' }
$fail = 0
foreach ($f in $files) {
  $localPath = Join-Path "$root\dist" ($f -replace '/', '\')
  $local = (Get-FileHash -Algorithm MD5 $localPath).Hash
  $tmp = [System.IO.Path]::GetTempFileName()
  curl.exe -sL --max-time 30 -o $tmp "$base/$f"
  $remote = (Get-FileHash -Algorithm MD5 $tmp).Hash
  Remove-Item $tmp -Force
  if ($local -eq $remote) { Write-Output ("OK  {0}" -f $f) }
  else { Write-Output ("NG  {0}  local={1} remote={2}" -f $f, $local, $remote); $fail++ }
}
Write-Output "--- headers（★noindex が出てへんことを確認する側＝本物の面） ---"
curl.exe -sI "$base/"
if ($fail -gt 0) { Write-Error ("VERIFY FAILED: {0} file(s) mismatch" -f $fail) }
Write-Output ("VERIFY OK: {0}/{0} hash match" -f $files.Count)
