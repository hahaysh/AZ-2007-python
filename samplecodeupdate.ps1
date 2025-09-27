<#
.SYNOPSIS
  GitHub 경로에서 'python' (대소문자 구분 없음)을 포함한 모든 ZIP 파일을 다운로드하고, 
  "samples" 하위 폴더에 압축을 해제한 후 ZIP 파일을 삭제합니다.

.PARAMETER OutDir
  "samples" 폴더가 생성될 로컬 기본 경로 (기본값: 현재 디렉터리).

.PARAMETER Owner
  GitHub 조직/소유자 (기본값: MicrosoftLearning).

.PARAMETER Repo
  GitHub 리포지토리 이름 (기본값: mslearn-github-copilot-dev).

.PARAMETER RepoPath
  리포지토리 내부 경로 (기본값: DownloadableCodeProjects/Downloads).
#>

[CmdletBinding()]
param(
  [string]$OutDir   = (Get-Location).Path,
  [string]$Owner    = "MicrosoftLearning",
  [string]$Repo     = "mslearn-github-copilot-dev",
  [string]$RepoPath = "DownloadableCodeProjects/Downloads"
)

# 호환성을 위해 TLS 1.2 강제 적용
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

# GitHub API 엔드포인트
$apiUrl  = "https://api.github.com/repos/$Owner/$Repo/contents/$RepoPath"
$headers = @{
  "User-Agent" = "PowerShell"
  "Accept"     = "application/vnd.github+json"
}

Write-Host "Fetching file list from GitHub... ($apiUrl)"
try {
  $items = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
} catch {
  Write-Error "Failed to call GitHub API: $($_.Exception.Message)"
  exit 1
}

if (-not $items) {
  Write-Warning "No items found at path: $RepoPath"
  exit 0
}

# 파일명에 "python"이 포함된 ZIP 파일만 필터링
$pythonZips = $items | Where-Object {
  $_.type -eq 'file' -and $_.name -match '\.zip$' -and $_.name -imatch 'python'
}

if (-not $pythonZips) {
  Write-Warning "No ZIP files containing 'python' were found."
  exit 0
}

# 출력 경로에 "samples" 폴더 생성
$samplesDir = Join-Path $OutDir "samples"
$null = New-Item -ItemType Directory -Path $samplesDir -Force -ErrorAction SilentlyContinue

foreach ($file in $pythonZips) {
  $zipName     = $file.name
  $downloadUrl = $file.download_url
  if (-not $downloadUrl) {
    $downloadUrl = "https://raw.githubusercontent.com/$Owner/$Repo/main/$RepoPath/$zipName"
  }

  $localZip   = Join-Path $samplesDir $zipName
  $destFolder = Join-Path $samplesDir ([IO.Path]::GetFileNameWithoutExtension($zipName))

  Write-Host "`nDownloading: $zipName"
  try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $localZip -Headers $headers -UseBasicParsing -ErrorAction Stop
  } catch {
    Write-Warning "Failed to download $zipName - $($_.Exception.Message)"
    continue
  }

  Write-Host "Extracting to: $destFolder"
  try {
    $null = New-Item -ItemType Directory -Path $destFolder -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $localZip -DestinationPath $destFolder -Force
  } catch {
    Write-Warning "Failed to extract $zipName - $($_.Exception.Message)"
    continue
  }

  Write-Host "Removing ZIP file: $zipName"
  try {
    Remove-Item -LiteralPath $localZip -Force -ErrorAction SilentlyContinue
  } catch {
    Write-Warning "Failed to delete $zipName - $($_.Exception.Message)"
  }
}

Write-Host "`nAll tasks completed! Extracted projects are under: $samplesDir"
