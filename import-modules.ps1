# import all useful modules used in the repo for testing and development purposes

$repoRoot = Find-RepoRoot # the build cmd is in package.json

$modules = @(
  'src\scripts\CredentialHelpers.psm1'
  'external\common\streaming-software\version-control\load-stream-modules.psm1'
  'external\streamerbot\tests\Test-KofiWebhook.psm1'
)

foreach ($m in $modules) {
  Import-Module (Join-Path $repoRoot $m) -Force
}
