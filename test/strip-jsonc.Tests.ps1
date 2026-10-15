$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSScriptRoot
$mergeScript = Get-Content -LiteralPath (Join-Path $scriptDir 'merge-settings.ps1') -Raw
if ($mergeScript -notmatch '(?ms)(function Strip-Jsonc \{.*?\r?\n\})') {
    throw 'Could not extract Strip-Jsonc from merge-settings.ps1'
}
Invoke-Expression $Matches[1]

# 1. Parse repo settings.json (contains https:// and /* */ inside string literals + comments)
$repoSettingsRaw = Get-Content -LiteralPath (Join-Path $scriptDir 'settings.json') -Raw
$repoParsed = (Strip-Jsonc $repoSettingsRaw) | ConvertFrom-Json
if ($null -eq $repoParsed.'custom-ui-style.stylesheet') {
    throw 'Expected custom-ui-style.stylesheet to be parsed from settings.json'
}

# 2. Verify URLs, CSS comments, and ', }' / ', ]' inside JSON string literals are preserved
$sampleJsonc = @'
{
  // Line comment with https://example.com
  /* Block comment */
  "url": "https://cdn.jsdelivr.net/npm/pkg@1.0.0/file.js",
  "cssComment": "/* keep this comment inside string */",
  "commaBeforeBraceInString": "selector { content: \", }\"; }",
  "commaBeforeBracketInString": "attr[data=\", ]\"]",
  "list": [
    "a",
    "b", // trailing comma after array element
  ],
}
'@

$parsed = (Strip-Jsonc $sampleJsonc) | ConvertFrom-Json
if ($parsed.url -ne 'https://cdn.jsdelivr.net/npm/pkg@1.0.0/file.js') {
    throw "URL corrupted: $($parsed.url)"
}
if ($parsed.cssComment -ne '/* keep this comment inside string */') {
    throw "CSS comment inside string corrupted: $($parsed.cssComment)"
}
if ($parsed.commaBeforeBraceInString -ne 'selector { content: ", }"; }') {
    throw "Comma before brace inside string corrupted: $($parsed.commaBeforeBraceInString)"
}
if ($parsed.commaBeforeBracketInString -ne 'attr[data=", ]"]') {
    throw "Comma before bracket inside string corrupted: $($parsed.commaBeforeBracketInString)"
}
if ($parsed.list.Count -ne 2 -or $parsed.list[0] -ne 'a' -or $parsed.list[1] -ne 'b') {
    throw "Trailing comma in array failed to parse"
}

Write-Host 'PASS: strip-jsonc.Tests.ps1 (all assertions passed)'
