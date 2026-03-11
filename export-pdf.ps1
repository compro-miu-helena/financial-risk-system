$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$markdownPath = Join-Path $repoRoot "architecture-analysis.md"
$htmlPath = Join-Path $repoRoot "architecture-analysis.html"
$pdfPath = Join-Path $repoRoot "architecture-analysis.pdf"
$browserProfilePath = Join-Path $repoRoot ".edge-pdf-profile"

if (-not (Test-Path $markdownPath)) {
    throw "Markdown file not found: $markdownPath"
}

function Convert-InlineMarkdown {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    $encoded = [System.Text.RegularExpressions.Regex]::Replace(
        $encoded,
        '`([^`]+)`',
        '<code>$1</code>'
    )
    return $encoded
}

function Flush-Paragraph {
    param(
        [ref]$Html,
        [ref]$ParagraphLines
    )

    if ($ParagraphLines.Value.Count -gt 0) {
        $text = ($ParagraphLines.Value -join " ").Trim()
        if ($text.Length -gt 0) {
            $Html.Value.Add("<p>$(Convert-InlineMarkdown $text)</p>")
        }
        $ParagraphLines.Value.Clear()
    }
}

$lines = Get-Content $markdownPath
$html = New-Object System.Collections.Generic.List[string]
$paragraphLines = New-Object System.Collections.Generic.List[string]
$inUl = $false
$inOl = $false

$style = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Financial Risk System Architecture Analysis</title>
<style>
body {
    font-family: "Segoe UI", Arial, sans-serif;
    color: #1c2430;
    margin: 40px 56px;
    line-height: 1.45;
    font-size: 12px;
}
h1, h2, h3 {
    color: #102a43;
    margin-top: 22px;
    margin-bottom: 10px;
}
h1 {
    font-size: 24px;
    border-bottom: 2px solid #bcccdc;
    padding-bottom: 8px;
}
h2 {
    font-size: 18px;
}
h3 {
    font-size: 14px;
}
p {
    margin: 8px 0;
}
ul, ol {
    margin: 6px 0 10px 20px;
}
li {
    margin: 4px 0;
}
code {
    font-family: Consolas, monospace;
    background: #f0f4f8;
    padding: 1px 4px;
    border-radius: 3px;
}
@page {
    size: A4;
    margin: 16mm;
}
</style>
</head>
<body>
"@

$html.Add($style)

foreach ($line in $lines) {
    $trimmed = $line.Trim()

    if ($trimmed -eq "") {
        Flush-Paragraph ([ref]$html) ([ref]$paragraphLines)
        if ($inUl) {
            $html.Add("</ul>")
            $inUl = $false
        }
        if ($inOl) {
            $html.Add("</ol>")
            $inOl = $false
        }
        continue
    }

    if ($trimmed -match '^(#{1,3})\s+(.*)$') {
        Flush-Paragraph ([ref]$html) ([ref]$paragraphLines)
        if ($inUl) {
            $html.Add("</ul>")
            $inUl = $false
        }
        if ($inOl) {
            $html.Add("</ol>")
            $inOl = $false
        }

        $level = $Matches[1].Length
        $content = Convert-InlineMarkdown $Matches[2]
        $html.Add("<h$level>$content</h$level>")
        continue
    }

    if ($trimmed -match '^\d+\.\s+(.*)$') {
        Flush-Paragraph ([ref]$html) ([ref]$paragraphLines)
        if ($inUl) {
            $html.Add("</ul>")
            $inUl = $false
        }
        if (-not $inOl) {
            $html.Add("<ol>")
            $inOl = $true
        }
        $html.Add("<li>$(Convert-InlineMarkdown $Matches[1])</li>")
        continue
    }

    if ($trimmed -match '^- (.*)$') {
        Flush-Paragraph ([ref]$html) ([ref]$paragraphLines)
        if ($inOl) {
            $html.Add("</ol>")
            $inOl = $false
        }
        if (-not $inUl) {
            $html.Add("<ul>")
            $inUl = $true
        }
        $html.Add("<li>$(Convert-InlineMarkdown $Matches[1])</li>")
        continue
    }

    if ($inUl) {
        $html.Add("</ul>")
        $inUl = $false
    }
    if ($inOl) {
        $html.Add("</ol>")
        $inOl = $false
    }
    $paragraphLines.Add($trimmed)
}

Flush-Paragraph ([ref]$html) ([ref]$paragraphLines)
if ($inUl) {
    $html.Add("</ul>")
}
if ($inOl) {
    $html.Add("</ol>")
}
$html.Add("</body>")
$html.Add("</html>")

[System.IO.File]::WriteAllLines($htmlPath, $html)

$edgePath = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $edgePath) {
    throw "Could not find Edge or Chrome to print the PDF."
}

$htmlUri = "file:///$($htmlPath -replace '\\','/')"

if (-not (Test-Path $browserProfilePath)) {
    New-Item -ItemType Directory -Path $browserProfilePath | Out-Null
}

& $edgePath `
    --headless `
    --disable-gpu `
    --no-first-run `
    --no-default-browser-check `
    --user-data-dir="$browserProfilePath" `
    --print-to-pdf="$pdfPath" `
    --print-to-pdf-no-header `
    $htmlUri | Out-Null

if (-not (Test-Path $pdfPath)) {
    throw "PDF export failed: $pdfPath was not created."
}

Write-Output "Created $pdfPath"
