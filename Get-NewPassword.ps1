Param(
[int]$maxLength=0,
[int]$minLength=0
)

If ($minLength -gt $maxLength){$maxLength = $minLength}
If ($maxLength -le 0 -and $minLength -le 0){
    $minLength = 12
    $maxLength = 15
    Write-Host "maxLength and minLength parameters not specified or out of bounds; Defaulting to minLength = $minLength and maxLength = $maxLength." -ForegroundColor DarkYellow
}
[string[]]$ascii = $null
$ascii+="!"
For ($a=35;$a –le 38;$a++) {$ascii+=,[char][byte]$a } ##-&
For ($a=40;$a –le 43;$a++) {$ascii+=,[char][byte]$a } #(-+
For ($a=45;$a –le 46;$a++) {$ascii+=,[char][byte]$a } #--.
For ($a=48;$a –le 58;$a++) {$ascii+=,[char][byte]$a } #0-:
$ascii+="="
For ($a=63;$a –le 90;$a++) {$ascii+=,[char][byte]$a } #?-Z
For ($a=97;$a –le 122;$a++) {$ascii+=,[char][byte]$a } #a-z

[string[]]$passwordList = $null
$pwIndex = 0
$pwArray = @()
For ($myLength=$minLength; $myLength -le $maxLength;$myLength++){
    $TempPassword = $null
    For ($loop=1; $loop –le $myLength; $loop++) {
            $TempPassword+=($ascii | GET-RANDOM)
    }
    #Write-Host $TempPassword
    $passwordList+=$TempPassword
    $pwArray+=[PSCustomObject]@{Index=$pwIndex;Length=$myLength;Password=$TempPassword}
    $pwIndex++
}
$pwArray | FT

$pushIndex = Read-Host Select an index number to push, or press enter for none.
If ($pushIndex){
    $pwToPush = $passwordList[$pushIndex]
    $expireAfterDays = Read-Host "Expire after number of DAYS (default = 10)";If(-Not $expireAfterDays){$expireAfterDays = "10"}
    $expireAfterViews = Read-Host "Expire after number of VIEWS (default = 5)";If(-Not $expireAfterViews){$expireAfterViews = "5"}
    $payload = @{
        "password" = @{
	        "payload" = "$pwToPush"
	        "expire_after_days" = "$expireAfterDays"
	        "expire_after_views" = "$expireAfterViews"
        }
    }

    $createPwLink = Invoke-WebRequest `
	    -Body (ConvertTo-Json -InputObject $payload) `
	    -Method Post `
        -Uri "https://pwpush.com/p.json" `
        -ContentType "application/json"

    $pwLinkContent = ConvertFrom-Json $createPwLink.Content
    $pwUrlToken = $pwLinkContent.url_token
    $pushURL = "https://pwpush.com/p/$pwUrlToken"
    $selectedPassword = $pwArray[$pushIndex].Password
    Write-Host "Password = $selectedPassword" -ForegroundColor Green -BackgroundColor Black
    Write-Host "Password Access URL (This url will expire after $expireAfterDays days or $expireAfterViews views):"
    Write-Host $pushURL -ForegroundColor Black -BackgroundColor White
    $copyResponse = $null
    do {
        $copyResponse = Read-Host "Copy [P]assword or [U]rl to clipboard? (default: none)"
        Switch ($copyResponse){
            "P" {Set-Clipboard -Value $selectedPassword;Write-Host "Password copied to clipboard."}
            "U" {Set-Clipboard -Value $pushURL;Write-Host "URL copied to clipboard."}
        }
    }while($copyResponse)
}