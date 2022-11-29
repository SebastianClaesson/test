$GitUrls = @('https://github.com/Azure/azure-policy','https://github.com/Azure/Community-Policy')

$GitUrls | % {
    $Path = $($_.Split('/')[-1])
    if (!(Test-Path -Path .\$Path)) {
        git clone $_
    } else {
        cd .\$Path 
        git pull
        cd ..
    }
}

# Excluding Monitoring
$ResourceType = @('Azure Active Directory', 'Backup','Compute','General','Guest Configuration','Key Vault','Managed Identity','Network','Security Center','Site Recovery','Storage','Authorization','General','HybridUseBenefits','KeyVault','LoadBalancer')

$BuiltinPolicies = $ResourceType | % {
    [PSCustomObject]@{
        ResourceType = $_
        PolicyDefinition = $(
            Get-childitem -Path ".\azure-policy\built-in-policies\policyDefinitions\$_" -File -Recurse -Filter '*.json' | Where-Object {$_.FullName -notlike '*audit*' -and $_.FullName -notlike '*.rules.json' -and $_.FullName -notlike '*.parameters.json' -and $_.Name -notlike '*Deprecated*'} | Select -ExpandProperty FullName
            Get-childitem -Path ".\Community-Policy\Policies\$_" -File -Recurse -Filter '*.json' | Where-Object {$_.FullName -notlike '*audit*' -and $_.FullName -notlike '*.rules.json' -and $_.FullName -notlike '*.parameters.json' -and $_.Name -notlike '*Deprecated*'} | Select -ExpandProperty FullName
        )
    }
}

$Content = $BuiltinPolicies | % {
    $Defs = $($_.PolicyDefinition | ForEach-Object {
        $FullPath = $_
        Write-verbose "Processing $FullPath" -Verbose
        $PolicyDef = Get-Content -LiteralPath $FullPath -Raw | ConvertFrom-Json -Depth 100
        $UrlLink = $('https://github.com/Azure/' + $($FullPath.Split('\')[3]) + '/tree/master/' + $($FullPath.Split('\')[4..$($FullPath.Split('\').Length)] -join '/'))
        if ($PolicyDef.Properties.DisplayName) {
            if ($PolicyDef.Properties.DisplayName -like '*Deprecated*') {
                Write-verbose "This policy $($PolicyDef.Properties.DisplayName) is deprecated." -verbose
            } else {
                [PSCustomObject]@{
                    DisplayName = $PolicyDef.Properties.DisplayName
                    Description = $PolicyDef.Properties.description
                    Path = $UrlLink
                }
            }
        } else {
            Write-Verbose "$FullPath does not contain displayName." -Verbose
            [PSCustomObject]@{
                DisplayName = $FullPath.Split('\')[-2]
                Description = $FullPath.Split('\')[-2]
                Path = $UrlLink
            }
        }
    })
    [PSCustomObject]@{
        ResourceType = $_.ResourceType
        PolicyDefinitions = $Defs
    }
}

$Content | %{
    $Name = $_.ResourceType
    $_.PolicyDefinitions | Export-Csv -Path .\$Name.csv -Delimiter ';' -Encoding utf8
}
