# IntuneEnrollmentRestrictionReport

## Ce que fait l'outil

`Get-IntuneEnrollmentRestrictionReport.ps1` est un script PowerShell en lecture seule qui interroge Microsoft Graph pour sortir la liste des configurations d'inscription Intune de votre locataire. Il couvre les restrictions de plateforme et les limites d'appareils ainsi que les autres types exposés par la même ressource. Il trie les configurations par priorité puis liste leurs affectations. Le script ne modifie rien dans le locataire. Les seules écritures possibles sont des fichiers locaux si vous fournissez `-OutputPath` ou `-HtmlPath`.

## Pourquoi maintenant

L'infolettre Intune du 23 octobre 2026 signale plusieurs sujets qui touchent l'inscription des appareils : de nouveaux profils d'inscription iOS, la possibilité d'exiger des comptes Google gérés sur Android Enterprise et des outils communautaires pour Autopilot. Chacune de ces pistes suppose que vous savez déjà qui a le droit d'inscrire quoi. Avant d'adopter l'une d'elles il est utile de dresser l'inventaire de vos restrictions d'inscription et de leurs affectations. C'est le contrôle le plus facile à auditer en lecture seule avec Microsoft Graph.

## Prérequis

### Modules

- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.DeviceManagement.Enrollment`
- `Microsoft.Graph.Groups` seulement si vous utilisez `-ResolveGroupNames`

Le script vise Microsoft Graph PowerShell 2.x. Ce module interroge le point de terminaison v1.0.

### Rôle Intune

Un compte qui possède un rôle Intune en lecture sur la configuration d'inscription suffit. Le script ne fait aucune modification donc un rôle en lecture couvre le besoin.

### Permissions Microsoft Graph déléguées

- `DeviceManagementServiceConfig.Read.All` pour lire les configurations et leurs affectations
- `Group.Read.All` seulement avec `-ResolveGroupNames` pour obtenir le nom des groupes

Le premier usage de Microsoft Graph PowerShell dans un locataire peut demander le consentement d'un administrateur si la permission n'a jamais été accordée.

## Installation

Installez les modules requis depuis la PowerShell Gallery puis récupérez le script.

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement.Enrollment -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
```

Copiez ensuite `Get-IntuneEnrollmentRestrictionReport.ps1` dans un dossier de votre choix.

## Utilisation

```powershell
# Inventaire affiché dans la console
.\Get-IntuneEnrollmentRestrictionReport.ps1

# Résolution des noms de groupes puis export CSV
.\Get-IntuneEnrollmentRestrictionReport.ps1 -ResolveGroupNames -OutputPath .\inscription.csv

# Rapport HTML simple
.\Get-IntuneEnrollmentRestrictionReport.ps1 -HtmlPath .\inscription.html

# Détails de progression
.\Get-IntuneEnrollmentRestrictionReport.ps1 -Verbose
```

Le script ouvre une fenêtre de connexion Microsoft Graph au premier appel. Il se déconnecte à la fin. Chaque ligne du rapport est un objet PowerShell que vous pouvez trier ou filtrer ou exporter avec les cmdlets habituelles.

## Exemple de sortie

L'exemple ci-dessous est fictif. Il sert uniquement à montrer la forme du résultat.

```text
Priorite      : 0
Nom           : Toutes les plateformes (défaut)
Type          : deviceEnrollmentPlatformRestrictionsConfiguration
Details       : iosRestriction [bloquée=False; personnels bloqués=True; min=; max=]
Affectations  : aucune
DerniereModif : 2026-09-14T10:22:00Z

Priorite      : 1
Nom           : Bloquer les appareils personnels Android
Type          : deviceEnrollmentPlatformRestrictionConfiguration
Details       : plateforme=android; bloquée=False; personnels bloqués=True; min=; max=
Affectations  : groupAssignmentTarget : Appareils entreprise
DerniereModif : 2026-10-01T08:05:00Z
```

## Limites connues

- Le script n'a pas été exécuté lors de la préparation de ce dépôt. Validez la sortie dans un locataire de test et comparez-la avec le centre d'administration Intune avant de vous y fier.
- Les propriétés propres à chaque type de restriction sont lues dans `AdditionalProperties`. Selon la version du module et de l'API, certains types ou certaines propriétés peuvent être absents ou structurés autrement auquel cas la colonne Details reste vide.
- Le script couvre les configurations d'inscription exposées par la ressource `deviceEnrollmentConfiguration`. Il ne couvre pas les profils d'inscription ADE d'Apple ni les profils Android Enterprise ni les politiques Autopilot ni le regroupement au moment de l'inscription.
- Le script montre ce qui est configuré et à qui c'est affecté. Il ne juge pas si une restriction est bien réglée. C'est à vous de décider si une plateforme ou les appareils personnels devraient être bloqués.

## Lien vers l'article

https://trivium365.com/blog/inscription-intune-controles-veille-23-octobre-2026/

## Sources

- Andrew Taylor, infolettre Intune du 23 octobre 2026 : https://andrewstaylor.com/2026/10/23/intune-newsletter-23rd-october-2026/
- Samuel Vara et Mayur Jadhav, billet du blogue Intune Customer Success sur l'authentification Google Workspace exigée sur les appareils Android Enterprise : https://techcommunity.microsoft.com/blog/IntuneCustomerSuccess/require-google-workspace-authentication-on-android-enterprise-devices-with-micro/4565954


## Démonstration en vidéo

https://www.youtube.com/watch?v=JY1DEmZUyfU
