# Runs elevated. Enables the virtualization features Docker Desktop needs and installs Docker Desktop.
$log = "$env:PUBLIC\velocity-docker-setup.log"
Start-Transcript -Path $log -Force | Out-Null
function Show-Features {
    foreach ($f in 'VirtualMachinePlatform','Microsoft-Windows-Subsystem-Linux') {
        $s = Get-WindowsOptionalFeature -Online -FeatureName $f
        Write-Output ("{0}: {1}" -f $f, $s.State)
    }
}
try {
    Write-Output "== features before =="
    Show-Features

    Write-Output "== enabling VirtualMachinePlatform + WSL =="
    $r1 = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All
    $r2 = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All
    Write-Output ("RestartNeeded: {0}" -f ($r1.RestartNeeded -or $r2.RestartNeeded))

    Write-Output "== wsl --install (kernel only, no distro) =="
    wsl --install --no-distribution 2>&1 | Out-String -Width 200

    Write-Output "== installing Docker Desktop =="
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String -Width 200

    Write-Output "== features after =="
    Show-Features
    Write-Output "SETUP_DONE"
} catch {
    Write-Output "SETUP_ERROR: $($_.Exception.Message)"
} finally {
    Stop-Transcript | Out-Null
}
