Function Get-RedactedPassword{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)][string]$Password,
        [Parameter(Position=1)][decimal]$Factor=0.733
    )
    $passwordLength = $Password.Length
    $redactionLength = [math]::Floor([decimal]$($passwordLength * $factor))
    $showLength = $passwordLength - $redactionLength
    $showLeftLength = [math]::Ceiling($showLength/2)
    $showRightLength = [math]::Floor($showLength/2)
    $showLeftString = $Password.Substring(0,$showLeftLength)
    $redactionString = [string]('·' * $redactionLength)
    $showRightString = $Password.Substring($passwordLength - $showRightLength, $showRightLength)
    $showLeftString + $redactionString + $showRightString
}

Function New-Password{
<#
    .SYNOPSIS
    Generates a number of pseudorandom passwords with options to push passwords through pwpush.com.

    .DESCRIPTION
    Specify the length and number of passwords you want to generate.
    Passwords can be automatically sent to pwpush.com and a unique link generated for each.
    Once the passwords are generated, you have the opportunity to copy the passwords and URLs to the clipboard.

    .PARAMETER Length
    Specifies the length of the generated passwords.
    Default: 15

    .PARAMETER Count
    Specifies the number of passwords to generate.
    Default: 1

    .PARAMETER ShowPassword
    By default, about 70% of the password is redacted when displayed.
    If this switch is used, the entire password will be displayed in the console.

    .PARAMETER Push
    If this siwtch is used, the passwords will be sent to pwpush.com and URLs will be retrieved for each.

    .PARAMETER ExpireAfterDays
    If -Push is used, specifies the number of days after which the URL will no longer be valid.

    .PARAMETER ExpireAfterViews
    If -Push is used, specifies the number of times the password can be viewed before the URL will no longer be valid.

    .INPUTS
    This function does not accept pipeline input.

    .LINK
    https://pwpush.com

#>
    Param(
    [Parameter(Position=0)][int]$Length=15,
    [Parameter(Position=1,HelpMessage='Number of passwords to generate')][int]$Count=1,
    [Parameter()][switch]$ShowPassword,
    [Parameter(ParameterSetName='push')][switch]$Push,
    [Parameter(ParameterSetName='push')][int]$ExpireAfterDays=10,
    [Parameter(ParameterSetName='push')][int]$ExpireAfterViews=5
    )

    #Initialize list of characters.
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
    For ($pwNumber=1; $pwNumber -le $Count;$pwNumber++){
        [string]$TempPassword = $null
        For ($loop=1; $loop –le $Length; $loop++) {
                $TempPassword+=($ascii | GET-RANDOM)
        }
        $redactedPassword = Get-RedactedPassword $TempPassword

        If ($Push){
            $payload = @{
                "password" = @{
	                "payload" = "$TempPassword"
	                "expire_after_days" = "$ExpireAfterDays"
	                "expire_after_views" = "$ExpireAfterViews"
                }
            }

            $createPwLink = Invoke-WebRequest -Body (ConvertTo-Json -InputObject $payload) -Method Post -Uri "https://pwpush.com/p.json" -ContentType "application/json"

            $pwLinkContent = ConvertFrom-Json $createPwLink.Content
            $pwUrlToken = $pwLinkContent.url_token
            $pushURL = "https://pwpush.com/p/$pwUrlToken"
            $pwArray+=[PSCustomObject]@{Index=$pwNumber-1;Password=$TempPassword;RedactedPassword=$redactedPassword;Url=$pushURL}
        }
        Else{
            $pwArray+=[PSCustomObject]@{Index=$pwNumber-1;Password=$TempPassword;RedactedPassword=$redactedPassword}
        }


        #$pwNumber++
    }
    Switch ($ShowPassword){
        $true {$pwArray | Select-Object Index, Password, Url | FT}
        $false {$pwArray | Select-Object Index, RedactedPassword, Url | FT}
    }
    If ($Push){
        Write-Host "URLs will be valid for $ExpireAfterDays days or $ExpireAfterViews views, whichever occurs first." -ForegroundColor DarkYellow
    }
    $prompt = "Copy [P]assword $(If($Push){'or [U]rl '})to clipboard? (default: none)"

    Do{
        If($pwArray.Count -eq 1){
            $selectedIndex = 0
        }
        Else{
            $selectedIndex = Read-Host Select an index number to copy, or press enter for none.
        }
        If([string]$selectedIndex -ne ''){
            $selectedPassword = $pwArray[$selectedIndex].Password
            $selectedUrl = $pwArray[$selectedIndex].Url
            Do{
                $copyResponse = Read-Host $prompt
                Switch ($copyResponse){
                    "P" {Set-Clipboard -Value $selectedPassword;Write-Host "Password copied to clipboard."}
                    "U" {Set-Clipboard -Value $selectedUrl;Write-Host "URL copied to clipboard."}
                }
            } While ($copyResponse)
        }
        If($pwArray.Count -eq 1){break}
    } While ($selectedIndex)
}

Export-ModuleMember -Function New-Password