# Chromium Portable-Style Updater for Windows

<img width="866" height="505" alt="image" src="https://github.com/user-attachments/assets/abfd775e-181a-411c-93b9-bbecedf3fbf3" />

## English

### Overview

This PowerShell script downloads the latest Chromium archive published by the `Hibbiki/chromium-win64` GitHub repository, extracts it with 7-Zip, locates the archive's `Chrome-bin` directory, and copies its contents into a local `bin` directory.

By default, Chromium is deployed to:

```text
C:\Program Files\Chromium\bin
```

The script checks the currently installed `chrome.exe` product version and retrieves the latest GitHub release tag for display. It does not terminate `chrome.exe`. If Chrome or Chromium is running, the script asks the user to close all related windows and press Enter before it checks again.

> **Important:** The version comparison is informational only. The script downloads and deploys the archive every time it runs, even when the displayed versions appear to match.

### What the Script Does

1. Validates that the configured 7-Zip executable exists.
2. Determines the installed Chromium version from `bin\chrome.exe`, if present.
3. Queries the GitHub Releases API for the latest release tag.
4. Creates a uniquely named temporary working directory.
5. Downloads `chrome.7z` to the temporary directory.
6. Extracts the archive with 7-Zip.
7. Searches recursively for the first directory named `Chrome-bin`.
8. Waits until the user has closed every running `chrome.exe` process.
9. Creates the destination `bin` directory when necessary.
10. Copies the contents of `Chrome-bin` into the destination and overwrites matching files.
11. Removes the temporary directory in a `finally` block, whether the update succeeds or fails.

### Requirements

- Windows
- Windows PowerShell 5.1 or PowerShell 7+
- Permission to write to the selected installation directory
- 7-Zip installed, or the full path to `7z.exe`
- Network access to GitHub and the configured download location
- TLS and proxy settings that allow `Invoke-WebRequest` and `Invoke-RestMethod` to reach the configured URLs

The default installation path is under `C:\Program Files`, so an elevated PowerShell session is normally required unless permissions have been changed or `-InstallRoot` points to a user-writable directory.

### Important Correction to the Pasted Script

The script shown in the request contains HTML `<a>` elements around the two URLs. Those elements are formatting artifacts and are not valid inside a PowerShell string. Replace the affected defaults with plain quoted strings:

```powershell
[string]$DownloadUrl = 'https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z',
[string]$LatestReleaseApiUrl = 'https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest'
```

Do not include `<a href=...>`, `target=...`, or `</a>` in the `.ps1` file.

### Recommended File Layout

Save the script with a descriptive name such as:

```text
Update-Chromium.ps1
```

After a successful default installation, the relevant layout is:

```text
C:\Program Files\Chromium\
└── bin\
    ├── chrome.exe
    ├── chrome.dll
    ├── locales\
    └── other Chromium runtime files
```

The exact archive contents can vary by release.

### Parameters

#### `-DownloadUrl`

URL of the Chromium `.7z` archive.

Default:

```text
https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z
```

Use this parameter to select another compatible archive. The downloaded archive must contain a directory named `Chrome-bin` because the script searches for that exact name.

#### `-InstallRoot`

Root directory for the Chromium installation.

Default:

```text
C:\Program Files\Chromium
```

The script deploys files to the `bin` child directory under this root.

#### `-SevenZipPath`

Full path to the 7-Zip command-line executable.

Default:

```text
C:\Program Files\7-Zip\7z.exe
```

If the file does not exist, the script stops before downloading anything.

#### `-LatestReleaseApiUrl`

GitHub Releases API endpoint used to obtain the latest release tag.

Default:

```text
https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest
```

The JSON response must contain a non-empty `tag_name` property.

### Usage

#### 1. Open PowerShell

For the default installation directory, open PowerShell with administrative privileges.

#### 2. Review the execution policy

If local script execution is blocked, use an execution policy approved by your organization. A process-scoped example is:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

This changes the policy only for the current PowerShell process. Follow your organization's security policy rather than weakening a managed policy.

#### 3. Run with default settings

```powershell
.\Update-Chromium.ps1
```

#### 4. Run with a custom installation directory

```powershell
.\Update-Chromium.ps1 -InstallRoot 'D:\Apps\Chromium'
```

#### 5. Run with a custom 7-Zip location

```powershell
.\Update-Chromium.ps1 -SevenZipPath 'D:\Tools\7-Zip\7z.exe'
```

#### 6. Supply all parameters explicitly

```powershell
.\Update-Chromium.ps1 `
    -DownloadUrl 'https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z' `
    -InstallRoot 'D:\Apps\Chromium' `
    -SevenZipPath 'C:\Program Files\7-Zip\7z.exe' `
    -LatestReleaseApiUrl 'https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest'
```

### Example Console Flow

```text
Installed Chromium version: 123.0.0000.0
Latest Chromium version:    123.0.0000.0-r1
Downloading Chromium from ...
Extracting archive to a temporary directory
WARNING: chrome.exe is currently running. Close every Chromium/Chrome window before continuing.
After chrome.exe has exited, press Enter to check again:
Copying Chromium files to C:\Program Files\Chromium\bin
Chromium update completed successfully.
```

The displayed values are examples only. Actual versions depend on the installed executable and the latest API response.

### Function Reference

#### `Wait-ForChromeToExit`

Repeatedly checks for processes named `chrome` by using `Get-Process`. When at least one process exists, the function:

- Displays a warning.
- Asks the user to close all Chromium or Chrome windows.
- Waits for Enter.
- Checks again.

The function does not call `Stop-Process`, so it does not forcibly terminate browsers or discard active sessions.

Because both Google Chrome and Chromium commonly use the process name `chrome.exe`, any running process with that name can block deployment.

#### `Get-InstalledChromiumVersion`

Accepts the expected path to `chrome.exe`.

- Returns `Not installed` when the file does not exist.
- Reads `VersionInfo.ProductVersion` when the file exists.
- Returns `Unknown` when the product version is empty.
- Otherwise returns the product version string.

#### `Get-LatestChromiumRelease`

Calls the supplied release API URL with `Invoke-RestMethod` and returns `tag_name` from the response. It throws an error when `tag_name` is missing or blank.

### Deployment and Replacement Behavior

The copy operation is:

```powershell
Copy-Item -LiteralPath (Join-Path $ChromeBinDirectory.FullName '*') -Destination $BinPath -Recurse -Force
```

There is a PowerShell wildcard issue in the supplied command. `-LiteralPath` treats `*` as a literal character, so it does not expand the archive contents as intended. Use `-Path` for this source expression instead:

```powershell
Copy-Item -Path (Join-Path $ChromeBinDirectory.FullName '*') -Destination $BinPath -Recurse -Force
```

With that correction, the command copies archive content recursively and overwrites matching destination files. It still does not remove files that exist in the destination but no longer exist in the new archive. Consequently, obsolete files may remain after repeated updates.

For a tightly controlled deployment, test whether the destination should be backed up or cleared before copying. Do not add automatic deletion without considering rollback, permissions, browser profiles, and organization policy.

### Temporary Files and Cleanup

A unique working directory is created below the current user's temporary directory with a name similar to:

```text
ChromiumUpdate-<GUID>
```

The archive and extracted files are stored there. The `finally` block removes that directory after success or failure. If cleanup itself fails, PowerShell can surface that error because `$ErrorActionPreference` is set to `Stop`.

### Error Handling

The script sets:

```powershell
$ErrorActionPreference = 'Stop'
```

This converts many non-terminating PowerShell errors into terminating errors. The script can stop in these situations:

- `7z.exe` is missing.
- The GitHub API request fails.
- The API response does not contain `tag_name`.
- The archive download fails.
- 7-Zip returns a nonzero exit code.
- No `Chrome-bin` directory is found.
- The destination cannot be created or written.
- File copying fails.
- Temporary cleanup fails.

No `catch` block is defined, so the terminating error is shown to the caller after the `finally` cleanup runs.

### Exit Codes

The script explicitly checks the 7-Zip process exit code through `$LASTEXITCODE`. A nonzero value causes a terminating error.

For other failures, PowerShell determines the host process exit behavior. When using the script in automation, invoke it from a wrapper that captures PowerShell's exit code and logs error details.

### Security Considerations

- The script downloads and executes no installer, but it deploys browser binaries obtained from a remote release archive.
- It does not validate a checksum or digital signature before deployment.
- The default source is a third-party GitHub repository, not an official Chromium distribution endpoint.
- `-Force` overwrites matching files in the destination.
- Administrative execution increases impact if the downloaded archive is compromised.
- A custom URL should be trusted and should serve the expected archive structure.
- Enterprise environments should consider release pinning, checksum verification, code signing, proxy controls, endpoint protection, and a tested rollback procedure.

### Limitations

- The script displays installed and latest versions but does not compare them to decide whether an update is required.
- It always downloads and copies the archive when earlier steps succeed.
- It is interactive while `chrome.exe` is running, so unattended execution can stall.
- It finds the first recursively discovered directory named `Chrome-bin`.
- It does not verify archive integrity or publisher authenticity.
- It does not create a backup or rollback point.
- It does not remove obsolete destination files.
- It does not create shortcuts, register Chromium, or modify the system `PATH`.
- It does not preserve a separate log file.

### Troubleshooting

#### `7-Zip was not found`

Confirm the path to `7z.exe` and pass it explicitly:

```powershell
.\Update-Chromium.ps1 -SevenZipPath 'D:\Utilities\7-Zip\7z.exe'
```

#### `Access to the path is denied`

Run PowerShell with appropriate permissions or choose a writable installation root:

```powershell
.\Update-Chromium.ps1 -InstallRoot "$env:LOCALAPPDATA\Chromium"
```

#### `The archive did not contain a Chrome-bin directory`

The archive structure is incompatible with the script, the download is not the expected file, or extraction did not produce the expected layout. Inspect the archive manually and confirm that it contains `Chrome-bin`.

#### The script repeatedly reports that `chrome.exe` is running

Close all Chrome and Chromium windows, including background applications. To inspect matching processes without terminating them:

```powershell
Get-Process -Name chrome -ErrorAction SilentlyContinue
```

#### API or download request fails

Check internet access, proxy configuration, TLS inspection, GitHub availability, and whether the configured URLs are allowed by organizational controls.

#### Files remain from an older release

The script overwrites matching files but does not remove destination-only files. Compare the deployed directory with a clean extraction before deciding on a cleanup procedure.

### Automation Notes

The current script is best suited to attended execution because it waits for user input when Chrome is open. For scheduled or unattended deployment, redesign the browser-running behavior to fail safely instead of prompting. Also add integrity verification, structured logging, explicit exit codes, and rollback handling before enterprise use.

### Suggested Validation Checklist

After the script completes:

1. Confirm that `bin\chrome.exe` exists.
2. Check its product version:

```powershell
(Get-Item 'C:\Program Files\Chromium\bin\chrome.exe').VersionInfo.ProductVersion
```

3. Start Chromium and verify that it opens normally.
4. Review the destination for unexpected stale files.
5. Confirm that no `ChromiumUpdate-*` working directory remains in the current user's temporary directory.

### License and Attribution

This README documents the supplied script. Chromium, GitHub, 7-Zip, and the referenced repository are governed by their respective licenses and terms. Review those terms before redistribution or enterprise deployment.

---

## 한국어

### 개요

이 PowerShell 스크립트는 `Hibbiki/chromium-win64` GitHub 저장소에서 최신 Chromium 압축 파일을 내려받고, 7-Zip으로 압축을 푼 다음, 압축 파일 안의 `Chrome-bin` 디렉터리를 찾아 로컬 `bin` 디렉터리에 복사합니다.

기본 배포 위치는 다음과 같습니다.

```text
C:\Program Files\Chromium\bin
```

스크립트는 기존 `chrome.exe`의 제품 버전과 GitHub 최신 릴리스 태그를 조회해 화면에 표시합니다. 단, `chrome.exe`를 강제로 종료하지 않습니다. Chrome 또는 Chromium이 실행 중이면 사용자가 모든 관련 창을 닫고 Enter 키를 누를 때까지 반복해서 확인합니다.

> **중요:** 버전 정보는 화면 표시용입니다. 설치 버전과 최신 버전이 같아 보여도 스크립트는 실행할 때마다 압축 파일을 다운로드하고 배포합니다.

### 주요 동작

1. 설정된 7-Zip 실행 파일이 존재하는지 확인합니다.
2. `bin\chrome.exe`가 있으면 설치된 Chromium 버전을 읽습니다.
3. GitHub Releases API에서 최신 릴리스 태그를 조회합니다.
4. 고유한 이름의 임시 작업 디렉터리를 만듭니다.
5. `chrome.7z`를 임시 디렉터리에 다운로드합니다.
6. 7-Zip으로 압축 파일을 풉니다.
7. 이름이 `Chrome-bin`인 첫 번째 디렉터리를 재귀적으로 찾습니다.
8. 사용자가 실행 중인 모든 `chrome.exe` 프로세스를 닫을 때까지 기다립니다.
9. 필요하면 대상 `bin` 디렉터리를 만듭니다.
10. `Chrome-bin`의 내용을 대상 디렉터리에 복사하고 같은 이름의 파일을 덮어씁니다.
11. 성공 여부와 관계없이 `finally` 블록에서 임시 디렉터리를 삭제합니다.

### 요구 사항

- Windows
- Windows PowerShell 5.1 또는 PowerShell 7 이상
- 선택한 설치 디렉터리에 대한 쓰기 권한
- 7-Zip 또는 `7z.exe`의 전체 경로
- GitHub와 설정된 다운로드 주소에 접근할 수 있는 네트워크
- `Invoke-WebRequest`와 `Invoke-RestMethod` 요청을 허용하는 TLS 및 프록시 설정

기본 경로가 `C:\Program Files` 아래이므로 일반적으로 관리자 권한 PowerShell이 필요합니다. 권한을 별도로 변경했거나 `-InstallRoot`를 사용자 쓰기 가능 경로로 지정한 경우에는 예외가 될 수 있습니다.

### 붙여넣은 스크립트에서 반드시 수정할 부분

요청에 포함된 스크립트의 URL 두 곳에는 HTML `<a>` 요소가 섞여 있습니다. 이는 복사 과정에서 생긴 서식이며 정상적인 PowerShell 문자열이 아닙니다. 다음처럼 순수한 문자열로 바꾸어야 합니다.

```powershell
[string]$DownloadUrl = 'https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z',
[string]$LatestReleaseApiUrl = 'https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest'
```

`.ps1` 파일에는 `<a href=...>`, `target=...`, `</a>`를 넣지 마십시오.

### 권장 파일 이름과 구조

스크립트는 다음과 같이 저장하는 것을 권장합니다.

```text
Update-Chromium.ps1
```

기본 경로에 정상 배포되면 주요 구조는 다음과 같습니다.

```text
C:\Program Files\Chromium\
└── bin\
    ├── chrome.exe
    ├── chrome.dll
    ├── locales\
    └── 기타 Chromium 실행 파일
```

정확한 파일 구성은 릴리스마다 달라질 수 있습니다.

### 매개변수

#### `-DownloadUrl`

Chromium `.7z` 압축 파일의 URL입니다.

기본값:

```text
https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z
```

다른 호환 압축 파일을 선택할 때 사용합니다. 스크립트가 정확히 `Chrome-bin`이라는 이름을 찾으므로 압축 파일에 해당 디렉터리가 있어야 합니다.

#### `-InstallRoot`

Chromium 설치 루트 디렉터리입니다.

기본값:

```text
C:\Program Files\Chromium
```

실제 파일은 이 경로 아래의 `bin` 디렉터리에 배포됩니다.

#### `-SevenZipPath`

7-Zip 명령줄 실행 파일의 전체 경로입니다.

기본값:

```text
C:\Program Files\7-Zip\7z.exe
```

파일이 없으면 다운로드 전에 스크립트가 중단됩니다.

#### `-LatestReleaseApiUrl`

최신 릴리스 태그를 조회하는 GitHub Releases API 주소입니다.

기본값:

```text
https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest
```

JSON 응답에 비어 있지 않은 `tag_name` 속성이 있어야 합니다.

### 실행 방법

#### 1. PowerShell 열기

기본 설치 경로를 사용한다면 관리자 권한으로 PowerShell을 엽니다.

#### 2. 실행 정책 확인

로컬 스크립트 실행이 차단된 경우 조직에서 승인한 실행 정책을 사용하십시오. 현재 프로세스에만 적용하는 예시는 다음과 같습니다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

이 설정은 현재 PowerShell 프로세스에만 적용됩니다. 관리 중인 보안 정책을 약화시키지 말고 조직 정책을 우선하십시오.

#### 3. 기본값으로 실행

```powershell
.\Update-Chromium.ps1
```

#### 4. 사용자 지정 설치 경로 사용

```powershell
.\Update-Chromium.ps1 -InstallRoot 'D:\Apps\Chromium'
```

#### 5. 사용자 지정 7-Zip 경로 사용

```powershell
.\Update-Chromium.ps1 -SevenZipPath 'D:\Tools\7-Zip\7z.exe'
```

#### 6. 모든 매개변수 지정

```powershell
.\Update-Chromium.ps1 `
    -DownloadUrl 'https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z' `
    -InstallRoot 'D:\Apps\Chromium' `
    -SevenZipPath 'C:\Program Files\7-Zip\7z.exe' `
    -LatestReleaseApiUrl 'https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest'
```

### 함수 설명

#### `Wait-ForChromeToExit`

`Get-Process`로 이름이 `chrome`인 프로세스를 반복 확인합니다. 하나라도 실행 중이면 경고를 표시하고, 사용자가 창을 닫은 뒤 Enter 키를 누르게 한 다음 다시 확인합니다.

`Stop-Process`를 호출하지 않으므로 브라우저를 강제 종료하거나 활성 세션을 임의로 폐기하지 않습니다. Google Chrome과 Chromium이 모두 `chrome.exe`라는 프로세스 이름을 사용할 수 있으므로, 어느 쪽이든 실행 중이면 배포가 대기할 수 있습니다.

#### `Get-InstalledChromiumVersion`

예상되는 `chrome.exe` 경로를 받습니다.

- 파일이 없으면 `Not installed`를 반환합니다.
- 파일이 있으면 `VersionInfo.ProductVersion`을 읽습니다.
- 제품 버전이 비어 있으면 `Unknown`을 반환합니다.
- 그렇지 않으면 제품 버전 문자열을 반환합니다.

#### `Get-LatestChromiumRelease`

`Invoke-RestMethod`로 지정된 릴리스 API를 호출하고 응답의 `tag_name`을 반환합니다. `tag_name`이 없거나 비어 있으면 오류를 발생시킵니다.

### 복사 및 덮어쓰기 동작

제공된 복사 명령에는 PowerShell 와일드카드 문제가 있습니다. `-LiteralPath`는 `*`를 와일드카드가 아닌 문자 그대로 처리하므로 의도한 파일 목록이 확장되지 않습니다. 소스 경로에는 다음처럼 `-Path`를 사용해야 합니다.

```powershell
Copy-Item -Path (Join-Path $ChromeBinDirectory.FullName '*') -Destination $BinPath -Recurse -Force
```

이렇게 수정하면 압축 파일 내용을 재귀적으로 복사하고 같은 이름의 대상 파일을 덮어씁니다. 다만 새 압축 파일에는 없지만 기존 대상 디렉터리에는 남아 있는 파일을 명시적으로 삭제하지 않습니다. 따라서 여러 번 업데이트하면 오래된 파일이 남을 수 있습니다.

엄격한 배포가 필요하면 복사 전에 백업 또는 대상 초기화가 필요한지 테스트하십시오. 자동 삭제를 추가하기 전에는 롤백, 권한, 브라우저 프로필, 조직 정책을 검토해야 합니다.

### 임시 파일과 정리

현재 사용자의 임시 디렉터리 아래에 다음과 유사한 고유 작업 경로를 만듭니다.

```text
ChromiumUpdate-<GUID>
```

다운로드한 압축 파일과 해제된 파일은 이곳에 저장됩니다. 성공 또는 실패 후 `finally` 블록이 이 디렉터리를 삭제합니다. `$ErrorActionPreference`가 `Stop`이므로 정리 작업 자체가 실패하면 해당 오류가 표시될 수 있습니다.

### 오류 처리

스크립트는 다음을 설정합니다.

```powershell
$ErrorActionPreference = 'Stop'
```

많은 비종료 오류를 종료 오류로 처리합니다. 대표적인 중단 조건은 다음과 같습니다.

- `7z.exe`가 없음
- GitHub API 요청 실패
- API 응답에 `tag_name`이 없음
- 압축 파일 다운로드 실패
- 7-Zip이 0이 아닌 종료 코드를 반환함
- `Chrome-bin`을 찾지 못함
- 대상 경로를 만들거나 쓸 수 없음
- 파일 복사 실패
- 임시 디렉터리 정리 실패

`catch` 블록은 없습니다. 따라서 `finally` 정리가 실행된 후 종료 오류가 호출자에게 표시됩니다.

### 보안 고려 사항

- 설치 프로그램을 직접 실행하지는 않지만 원격 릴리스 압축 파일에서 받은 브라우저 바이너리를 배포합니다.
- 배포 전 체크섬 또는 디지털 서명을 검증하지 않습니다.
- 기본 다운로드 소스는 공식 Chromium 배포 주소가 아니라 제3자 GitHub 저장소입니다.
- `-Force`가 같은 이름의 대상 파일을 덮어씁니다.
- 관리자 권한 실행 중 다운로드 파일이 손상되거나 변조되면 영향 범위가 커질 수 있습니다.
- 사용자 지정 URL은 신뢰할 수 있어야 하며 예상 압축 구조를 제공해야 합니다.
- 기업 환경에서는 릴리스 고정, 체크섬 검증, 코드 서명, 프록시 통제, 엔드포인트 보호와 검증된 롤백 절차를 고려하십시오.

### 제한 사항

- 설치 버전과 최신 버전을 표시하지만 실제 업데이트 필요 여부를 비교하지 않습니다.
- 앞 단계가 성공하면 항상 다운로드하고 복사합니다.
- `chrome.exe` 실행 중에는 사용자 입력을 기다리므로 무인 실행이 멈출 수 있습니다.
- 재귀 검색에서 처음 발견한 `Chrome-bin`을 사용합니다.
- 압축 파일 무결성이나 게시자 진위를 확인하지 않습니다.
- 백업 또는 롤백 지점을 만들지 않습니다.
- 대상 디렉터리의 오래된 파일을 삭제하지 않습니다.
- 바로 가기 생성, Chromium 등록, 시스템 `PATH` 변경을 하지 않습니다.
- 별도 로그 파일을 만들지 않습니다.

### 문제 해결

#### `7-Zip was not found`

`7z.exe`의 실제 경로를 확인해 직접 지정합니다.

```powershell
.\Update-Chromium.ps1 -SevenZipPath 'D:\Utilities\7-Zip\7z.exe'
```

#### `Access to the path is denied`

적절한 권한으로 PowerShell을 실행하거나 쓰기 가능한 설치 경로를 선택합니다.

```powershell
.\Update-Chromium.ps1 -InstallRoot "$env:LOCALAPPDATA\Chromium"
```

#### `The archive did not contain a Chrome-bin directory`

압축 구조가 호환되지 않거나, 예상한 파일이 다운로드되지 않았거나, 압축 해제 결과가 예상과 다를 수 있습니다. 압축 파일을 직접 확인해 `Chrome-bin`이 있는지 점검하십시오.

#### `chrome.exe` 실행 경고가 반복됨

백그라운드 앱을 포함해 Chrome과 Chromium 창을 모두 닫습니다. 강제 종료 없이 관련 프로세스를 확인하려면 다음을 실행합니다.

```powershell
Get-Process -Name chrome -ErrorAction SilentlyContinue
```

#### API 또는 다운로드 요청 실패

인터넷 연결, 프록시, TLS 검사, GitHub 접근 가능 여부, 조직의 URL 허용 정책을 확인합니다.

#### 이전 릴리스 파일이 계속 남아 있음

이 스크립트는 같은 이름의 파일을 덮어쓰지만 대상에만 있는 파일을 삭제하지 않습니다. 정리 절차를 정하기 전에 새 압축 해제 디렉터리와 배포 디렉터리를 비교하십시오.

### 자동화 시 참고 사항

현재 형태는 Chrome 실행 중 사용자 입력을 기다리므로 대화형 실행에 적합합니다. 예약 작업이나 무인 배포에 사용하려면 브라우저 실행 시 프롬프트 대신 안전하게 실패하도록 다시 설계하는 것이 좋습니다. 기업 배포 전에는 무결성 검증, 구조화된 로깅, 명확한 종료 코드, 롤백 처리도 추가로 검토하십시오.

### 실행 후 점검 목록

1. `bin\chrome.exe`가 생성되었는지 확인합니다.
2. 제품 버전을 확인합니다.

```powershell
(Get-Item 'C:\Program Files\Chromium\bin\chrome.exe').VersionInfo.ProductVersion
```

3. Chromium을 실행해 정상적으로 열리는지 확인합니다.
4. 대상 경로에 예상하지 않은 오래된 파일이 남았는지 검토합니다.
5. 현재 사용자 임시 경로에 `ChromiumUpdate-*` 작업 디렉터리가 남아 있지 않은지 확인합니다.

### 라이선스와 저작권 표시

이 README는 사용자가 제공한 스크립트를 설명합니다. Chromium, GitHub, 7-Zip 및 참조된 저장소에는 각각의 라이선스와 이용 조건이 적용됩니다. 재배포 또는 기업 배포 전에 해당 조건을 검토하십시오.
