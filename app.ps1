param([switch] $SelfTest, [switch] $SmokeTest, [switch] $InteractionTest, [switch] $LaunchTest)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$projectDir = $PSScriptRoot
$script:streamlinkPath = Join-Path $projectDir '.venv\Scripts\streamlink.exe'
$script:streamProcess = $null

function Get-TwitchChannel([string] $InputText) {
    $value = $InputText.Trim()
    if (-not $value) { throw "Entre le nom d'une chaîne ou son lien Twitch." }

    if ($value -match '^(www\.)?twitch\.tv/') { $value = "https://$value" }

    if ($value.Contains('://')) {
        $uri = $null
        if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref] $uri) -or
            $uri.Scheme -notin @('http', 'https') -or
            $uri.Host -notin @('twitch.tv', 'www.twitch.tv')) {
            throw 'Utilise seulement un lien twitch.tv.'
        }
        $parts = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ })
        if ($parts.Count -ne 1) { throw "Colle le lien d'une chaîne, pas celui d'une vidéo." }
        $value = $parts[0]
    }

    if ($value -cnotmatch '^[A-Za-z0-9_]{1,25}$') {
        throw 'Nom de chaîne Twitch invalide.'
    }
    return $value.ToLowerInvariant()
}

function Get-VlcPath {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'VideoLAN\VLC\vlc.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'VideoLAN\VLC\vlc.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    $command = Get-Command vlc.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'VLC est introuvable. Installe VLC puis réessaie.'
}

function Stop-TwitchStream {
    if ($script:streamProcess -and -not $script:streamProcess.HasExited) {
        try { $script:streamProcess.Kill($true) } catch { }
    }
    if ($script:streamProcess) { $script:streamProcess.Dispose() }
    $script:streamProcess = $null
}

if ($SelfTest) {
    if ((Get-TwitchChannel 'https://www.twitch.tv/ZeRaToR?ref=home') -cne 'zerator') {
        throw 'Échec du test de lecture du lien Twitch.'
    }
    if ((Get-TwitchChannel 'Zerator') -cne 'zerator') {
        throw 'Échec du test du nom de chaîne.'
    }
    if ((Get-TwitchChannel 'twitch.tv/ZeRaToR') -cne 'zerator') {
        throw 'Échec du test du lien sans protocole.'
    }
    try {
        [void] (Get-TwitchChannel 'https://twitch.tv.evil.example/zerator')
        throw 'Un lien externe a été accepté.'
    } catch {
        if ($_.Exception.Message -eq 'Un lien externe a été accepté.') { throw }
    }
    if (-not (Test-Path -LiteralPath (Get-VlcPath))) { throw 'VLC est introuvable.' }
    if (-not (Test-Path -LiteralPath $script:streamlinkPath)) { throw 'Streamlink est introuvable.' }
    Write-Output 'Tests locaux OK'
    exit 0
}

$script:mainForm = New-Object System.Windows.Forms.Form
$script:mainForm.Text = 'Twitch sans pubs'
$script:mainForm.Size = New-Object System.Drawing.Size(610, 280)
$script:mainForm.MinimumSize = New-Object System.Drawing.Size(560, 280)
$script:mainForm.StartPosition = 'CenterScreen'
$script:mainForm.BackColor = [System.Drawing.Color]::FromArgb(24, 21, 31)
$script:mainForm.ForeColor = [System.Drawing.Color]::White
$script:mainForm.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Twitch sans pubs'
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.Size = New-Object System.Drawing.Size(540, 35)
$title.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$script:mainForm.Controls.Add($title)

$description = New-Object System.Windows.Forms.Label
$description.Text = "Le direct s'ouvre dans VLC. Le chat s'ouvre dans ton navigateur."
$description.Location = New-Object System.Drawing.Point(26, 58)
$description.Size = New-Object System.Drawing.Size(550, 24)
$description.ForeColor = [System.Drawing.Color]::FromArgb(203, 197, 212)
$script:mainForm.Controls.Add($description)

$script:channelInput = New-Object System.Windows.Forms.TextBox
$script:channelInput.Location = New-Object System.Drawing.Point(26, 99)
$script:channelInput.Size = New-Object System.Drawing.Size(415, 27)
$script:channelInput.Anchor = 'Top, Left, Right'
$script:mainForm.Controls.Add($script:channelInput)

$script:watchButton = New-Object System.Windows.Forms.Button
$script:watchButton.Text = 'Regarder'
$script:watchButton.Location = New-Object System.Drawing.Point(455, 97)
$script:watchButton.Size = New-Object System.Drawing.Size(105, 32)
$script:watchButton.Anchor = 'Top, Right'
$script:watchButton.BackColor = [System.Drawing.Color]::FromArgb(145, 71, 255)
$script:watchButton.ForeColor = [System.Drawing.Color]::White
$script:watchButton.FlatStyle = 'Flat'
$script:mainForm.Controls.Add($script:watchButton)

$chat = New-Object System.Windows.Forms.Button
$chat.Text = 'Ouvrir le chat'
$chat.Location = New-Object System.Drawing.Point(26, 145)
$chat.Size = New-Object System.Drawing.Size(125, 32)
$script:mainForm.Controls.Add($chat)

$stop = New-Object System.Windows.Forms.Button
$stop.Text = 'Arrêter'
$stop.Location = New-Object System.Drawing.Point(162, 145)
$stop.Size = New-Object System.Drawing.Size(90, 32)
$script:mainForm.Controls.Add($stop)

$script:statusLabel = New-Object System.Windows.Forms.Label
$script:statusLabel.Text = 'Entre une chaîne, par exemple : twitch.tv/zerator'
$script:statusLabel.Location = New-Object System.Drawing.Point(26, 193)
$script:statusLabel.Size = New-Object System.Drawing.Size(545, 38)
$script:statusLabel.Anchor = 'Top, Left, Right'
$script:statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(189, 168, 239)
$script:mainForm.Controls.Add($script:statusLabel)

$script:streamTimer = New-Object System.Windows.Forms.Timer
$script:streamTimer.Interval = 600
$script:streamTimer.Add_Tick({
    if ($script:streamProcess -and $script:streamProcess.HasExited) {
        $exitCode = $script:streamProcess.ExitCode
        Stop-TwitchStream
        $script:streamTimer.Stop()
        if ($exitCode -eq 0) {
            $script:statusLabel.Text = 'Lecture terminée.'
        } else {
            $script:statusLabel.Text = "Lecture arrêtée. Vérifie que la chaîne est en direct (code $exitCode)."
        }
    }
})

$script:watchButton.Add_Click({
    try {
        $channel = Get-TwitchChannel $script:channelInput.Text
        $vlc = Get-VlcPath
        if (-not (Test-Path -LiteralPath $script:streamlinkPath)) {
            throw 'Streamlink manque. Lance Installer.cmd puis réessaie.'
        }
        Stop-TwitchStream

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $script:streamlinkPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        [void] $startInfo.ArgumentList.Add('--player')
        [void] $startInfo.ArgumentList.Add($vlc)
        [void] $startInfo.ArgumentList.Add('--player-http')
        [void] $startInfo.ArgumentList.Add("https://www.twitch.tv/$channel")
        [void] $startInfo.ArgumentList.Add('best')

        $script:streamProcess = [System.Diagnostics.Process]::Start($startInfo)
        $script:statusLabel.Text = "Connexion à $channel... VLC va s'ouvrir."
        $script:streamTimer.Start()
    } catch {
        $script:statusLabel.Text = $_.Exception.Message
    }
})

$script:channelInput.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $script:watchButton.PerformClick()
        $_.SuppressKeyPress = $true
    }
})

$chat.Add_Click({
    try {
        $channel = Get-TwitchChannel $script:channelInput.Text
        Start-Process "https://www.twitch.tv/popout/$channel/chat?popout="
    } catch {
        $script:statusLabel.Text = $_.Exception.Message
    }
})

$stop.Add_Click({
    Stop-TwitchStream
    $script:streamTimer.Stop()
    $script:statusLabel.Text = 'Lecture arrêtée.'
})

$script:mainForm.Add_FormClosed({ Stop-TwitchStream })
$script:mainForm.Add_Shown({
    if ($InteractionTest) {
        $script:channelInput.Text = ''
        $script:watchButton.PerformClick()
        if ($script:statusLabel.Text -ne "Entre le nom d'une chaîne ou son lien Twitch.") {
            throw 'Le bouton Regarder ne traite pas correctement la saisie.'
        }
        $script:mainForm.Close()
    } elseif ($LaunchTest) {
        $script:channelInput.Text = 'xqc'
        $script:watchButton.PerformClick()
        if (-not $script:streamProcess -or
            $script:statusLabel.Text -ne "Connexion à xqc... VLC va s'ouvrir.") {
            throw 'Le lancement de Streamlink a échoué.'
        }
        Stop-TwitchStream
        $script:streamTimer.Stop()
        $script:mainForm.Close()
    } elseif ($SmokeTest) {
        $script:mainForm.Close()
    } else {
        $script:channelInput.Focus()
    }
})
[void] $script:mainForm.ShowDialog()
$script:streamTimer.Dispose()
$script:mainForm.Dispose()
if ($InteractionTest) { Write-Output 'Interaction OK' }
if ($LaunchTest) { Write-Output 'Lancement OK' }
