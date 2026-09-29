# Runs elevated. Installs Docker Desktop (WSL2 backend) and adds the user to docker-users.
$log = "$env:PUBLIC\velocity-docker-install.log"
Start-Transcript -Path $log -Force | Out-Null
try {
    Write-Output "== wsl kernel update =="
    wsl --update 2>&1 | Out-String -Width 200
    Write-Output "== installing Docker Desktop =="
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1 | Out-String -Width 200
    Write-Output "== docker-users group =="
    $user = "$env:USERDOMAIN\albauham"
    try { Add-LocalGroupMember -Group "docker-users" -Member $user -ErrorAction Stop; Write-Output "added $user" } catch { Write-Output "group: $($_.Exception.Message)" }
    Write-Output "SETUP_DONE"
} catch {
    Write-Output "SETUP_ERROR: $($_.Exception.Message)"
} finally {
    Stop-Transcript | Out-Null
}
