# Ko-fi webhook test sender
# based off unofficial documentation:
# {
#   "verification_token": "your-actual-verification-token",
#   "message_id": "some-uuid",
#   "timestamp": "2026-07-27T16:27:32Z",
#   "type": "Donation", # Donation | Subscription | Commission | Shop Order
#   "is_public": true,
#   "from_name": "Jo Example",
#   "message": "Good luck with the integration!",
#   "amount": "3.00",
#   "url": "https://ko-fi.com/...",
#   "email": "jo@example.com",
#   "currency": "USD",
#   "is_subscription_payment": false,
#   "is_first_subscription_payment": false,
#   "kofi_transaction_id": "some-uuid",
#   "shop_items": null,
#   "tier_name": null, # needs tiers to be configured on Ko-fi for the profile
#   "shipping": null
# }
# Usage:
# Test-KofiWebhook -Type "Donation" -FromName "TestUser" -Message "hi" -Amount "3" -Currency "USD"

function Test-KofiWebhook {
  param(
    [string]$Type = "Donation",
    [string]$FromName = "TestUser",
    [string]$Message = "This is a custom test message",
    [string]$Amount = "5.00",
    [string]$Currency = "USD",
    [bool]$IsFirstSubscriptionPayment = $false,
    [bool]$IsPublic = $true
  )

  Import-Module "$env:STREAMING_REPO_PATH\src\scripts\CredentialHelpers.psm1" -Force
  $WebhookUrl = Get-CmdkeySecret -Target "HardscopeKofiWebhookUrl"
  $VerificationToken = Get-CmdkeySecret -Target "HardscopeKofiVerificationToken"
  # $WebhookUrl = Get-CmdkeySecret -Target "NoscopeKofiWebhookUrl"
  # $VerificationToken = Get-CmdkeySecret -Target "NoscopeKofiVerificationToken"

  $payload = @{
    verification_token              = $VerificationToken
    message_id                      = [guid]::NewGuid().ToString()
    timestamp                       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    type                            = $Type
    is_public                       = $IsPublic
    from_name                       = $FromName
    message                         = $Message
    amount                          = $Amount
    url                             = "https://ko-fi.com/Home/CoffeeShop?txid=$([guid]::NewGuid())"
    email                           = "test@example.com"
    currency                        = $Currency
    is_subscription_payment         = ($Type -eq "Subscription")
    is_first_subscription_payment   = $IsFirstSubscriptionPayment
    kofi_transaction_id             = [guid]::NewGuid().ToString()
    shop_items                      = $null
    tier_name                       = $null
    shipping                        = $null
  }

  $jsonPayload = $payload | ConvertTo-Json -Compress

  $displayPayload = $payload.Clone()
  $displayPayload.verification_token = "***REDACTED***"
  $displayJson = $displayPayload | ConvertTo-Json -Compress

  $body = @{
    data = $jsonPayload
  }

  Write-Host "Sending payload:" -ForegroundColor Cyan
  Write-Host $displayJson

  $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"

  Write-Host "Response:" -ForegroundColor Green
  $response
}

Export-ModuleMember -Function Test-KofiWebhook
