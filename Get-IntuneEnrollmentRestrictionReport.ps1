<#
.SYNOPSIS
    Inventaire en lecture seule des configurations d'inscription Intune et de leurs affectations.

.DESCRIPTION
    Lit les configurations d'inscription Intune (restrictions de plateforme, limites d'appareils
    et autres types exposés par la même ressource) à l'aide de Microsoft Graph PowerShell, les
    trie par priorité puis liste leurs affectations. Le script ne modifie rien dans le locataire.
    Les seules écritures possibles sont des fichiers locaux, si vous fournissez -OutputPath ou
    -HtmlPath. Le module Microsoft Graph PowerShell 2.x interroge le point de terminaison v1.0.

.PARAMETER OutputPath
    Chemin facultatif d'un fichier CSV. Sans ce paramètre, le résultat reste dans le pipeline et
    s'affiche à l'écran.

.PARAMETER HtmlPath
    Chemin facultatif d'un fichier HTML simple produit avec ConvertTo-Html.

.PARAMETER ResolveGroupNames
    Résout le nom d'affichage des groupes ciblés par les affectations. Demande en plus la
    permission déléguée Group.Read.All.

.EXAMPLE
    .\Get-IntuneEnrollmentRestrictionReport.ps1
    Affiche l'inventaire dans la console sous forme d'objets PowerShell.

.EXAMPLE
    .\Get-IntuneEnrollmentRestrictionReport.ps1 -ResolveGroupNames -OutputPath .\inscription.csv
    Résout le nom des groupes puis exporte le rapport en CSV.

.EXAMPLE
    .\Get-IntuneEnrollmentRestrictionReport.ps1 -HtmlPath .\inscription.html
    Produit un rapport HTML simple en plus de la sortie console.

.NOTES
    Permissions Microsoft Graph déléguées : DeviceManagementServiceConfig.Read.All et, avec
    -ResolveGroupNames, Group.Read.All. Le script n'a pas été exécuté lors de la préparation de
    ce dépôt. Validez la sortie dans un locataire de test avant de vous y fier.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [string]$OutputPath,
    [string]$HtmlPath,
    [switch]$ResolveGroupNames
)

$ErrorActionPreference = 'Stop'

$modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.DeviceManagement.Enrollment')
if ($ResolveGroupNames) {
    $modules += 'Microsoft.Graph.Groups'
}
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Module $module introuvable. Installez-le avec Install-Module $module -Scope CurrentUser."
    }
    Import-Module -Name $module
}

$scopes = @('DeviceManagementServiceConfig.Read.All')
if ($ResolveGroupNames) {
    $scopes += 'Group.Read.All'
}
Connect-MgGraph -Scopes $scopes -NoWelcome

$groupCache = @{}

function Get-TargetLabel {
    param($Target)

    $props = $Target.AdditionalProperties
    $label = ([string]$props['@odata.type']) -replace '^#microsoft\.graph\.', ''
    $groupId = [string]$props['groupId']
    if ($groupId) {
        $name = $groupId
        if ($ResolveGroupNames) {
            if (-not $groupCache.ContainsKey($groupId)) {
                try {
                    $groupCache[$groupId] = (Get-MgGroup -GroupId $groupId -Property DisplayName).DisplayName
                }
                catch {
                    $groupCache[$groupId] = "$groupId (introuvable)"
                }
            }
            $name = $groupCache[$groupId]
        }
        $label = "$label : $name"
    }
    return $label
}

function Format-PlatformRestriction {
    param($Restriction)

    if (-not $Restriction) {
        return ''
    }
    return ('bloquée={0}; personnels bloqués={1}; min={2}; max={3}' -f $Restriction['platformBlocked'], $Restriction['personalDeviceEnrollmentBlocked'], $Restriction['osMinimumVersion'], $Restriction['osMaximumVersion'])
}

$legacyKeys = @('windowsRestriction', 'windowsMobileRestriction', 'iosRestriction', 'macOSRestriction', 'androidRestriction', 'androidForWorkRestriction')

try {
    $configurations = Get-MgDeviceManagementDeviceEnrollmentConfiguration -All

    $report = foreach ($config in ($configurations | Sort-Object -Property Priority)) {
        $props = $config.AdditionalProperties
        $type = ([string]$props['@odata.type']) -replace '^#microsoft\.graph\.', ''

        switch ($type) {
            'deviceEnrollmentPlatformRestrictionConfiguration' {
                $details = "plateforme=$($props['platformType']); " + (Format-PlatformRestriction $props['platformRestriction'])
            }
            'deviceEnrollmentLimitConfiguration' {
                $details = "limite=$($props['limit'])"
            }
            'deviceEnrollmentPlatformRestrictionsConfiguration' {
                $parts = foreach ($key in $legacyKeys) {
                    if ($props[$key]) {
                        "$key [" + (Format-PlatformRestriction $props[$key]) + ']'
                    }
                }
                $details = $parts -join ' | '
            }
            default {
                $details = ''
            }
        }

        $assignments = Get-MgDeviceManagementDeviceEnrollmentConfigurationAssignment -DeviceEnrollmentConfigurationId $config.Id -All
        $targets = @($assignments | ForEach-Object { Get-TargetLabel -Target $_.Target })
        $assignmentText = 'aucune'
        if ($targets.Count -gt 0) {
            $assignmentText = $targets -join ' ; '
        }

        [pscustomobject]@{
            Priorite = $config.Priority
            Nom = $config.DisplayName
            Type = $type
            Details = $details
            Affectations = $assignmentText
            DerniereModif = $config.LastModifiedDateTime
        }
    }

    $unassigned = @($report | Where-Object { $_.Affectations -eq 'aucune' })
    if ($unassigned.Count -gt 0) {
        Write-Warning "$($unassigned.Count) configuration(s) sans affectation. Vérifiez si elles sont encore utiles."
    }

    if ($OutputPath) {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Verbose "Rapport CSV exporté : $OutputPath"
    }

    if ($HtmlPath) {
        $html = $report | ConvertTo-Html -Title 'Inventaire des restrictions d''inscription Intune' -PreContent '<h1>Inventaire des restrictions d''inscription Intune</h1>'
        $html | Out-File -FilePath $HtmlPath -Encoding UTF8
        Write-Verbose "Rapport HTML exporté : $HtmlPath"
    }

    $report
}
finally {
    Disconnect-MgGraph | Out-Null
}
