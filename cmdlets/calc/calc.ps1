<#
  .SYNOPSIS
  CLI calculator made with mathlib.
#>
param(
  [Parameter(ValueFromPipeline=$true)]
  [string]$expression,
  
  [switch]$mathlibinfo,
  [Alias("t")]
  [Alias("s")]
  [Alias("tui")]
  [Alias("app")]
  [Alias("cli")]
  [switch]$uiMode,
  [Alias("p")]
  [string]$printSheet,
  [Alias("o")]
  [string]$printOut
)
if ($printSheet -ne "") {$printSheet = $false}
if ($printOut) {$script:printOut = $printOut}

#Load Libs
. $psscriptroot\.lib\LibaryReader.ps1
ReadLibary "$psscriptroot\.lib\mathlib.lib"

#bufferScript
function buffer {
  param([switch]$save,[switch]$load)
  if ($save) {
    $w = $host.ui.rawui.buffersize.width
    $h = $host.ui.rawui.buffersize.height
    $Source = New-Object System.Management.Automation.Host.Rectangle 0, 0, $w, $h
    $script:ScreenBuffer = $host.UI.RawUI.GetBufferContents($Source)
  } elseif ($load) {
    $w = $host.ui.rawui.buffersize.width
    $h = $host.ui.rawui.buffersize.height
    $Source = New-Object System.Management.Automation.Host.Rectangle 0, 0, $w, $h
    $host.UI.RawUI.SetBufferContents((New-Object System.Management.Automation.Host.Coordinates $Source.Left, $Source.Top), $script:ScreenBuffer)
    $c = 'echo "`e[' + ($h-4) + 'B"'
    iex($c)
  }
}
buffer -save

#Code
if ($mathlibinfo) {
  write-host "Version : $mathlib_version"
  write-host "Author  : $mathlib_author"
  write-host "isCombi : $mathlib_iscombi"
  pause
  exit
}

function ValidateMathInput() {
  param($toValidate)

  [array]$nonAllowedIncludes = ".exe","function"

  #Get list of al avaliable commands and aliases in the session
  [array]$commands = (Get-Command -CommandType Cmdlet,alias).name
  #Check if input contains a command
  foreach ($c in $commands) {
    if ($c.length -gt "1") {
      if ($c -like "*$toValidate*") {
        return "invalid.includesCommand"
      }
    }
  }

  #check if expression includes a non allowed part.
  foreach ($n in $nonAllowedIncludes) {
    if ($toValidate -like "*$n*") {
      return "invalid.includesNonAllowedParts"
    }
  }

  #check if single length expressions are numeral
  if ($toValidate.length -lt "2") {
    if ($toValidate -ne "e") {
      if ($toValidate -match "[0-9]") {} else {
        return "invalid.nonNumeralSingleLengthExpression"
      }
    }
  }

  return "valid"
}

function calculate() {
  param($expression)
  $validation = ValidateMathInput "$expression"
  if ($validation -eq "valid") {
    $old_ErrorActionPreference = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    $result = iex($expression)
    $ErrorActionPreference = $old_ErrorActionPreference
    return $result
  } else {return "$validation"}
}

function write-result {
  param($res,$offset,[switch]$compact)
  if ($offset) {} else {$offset = 0}
  if ($res) {
    #calculate result
    $script:result = calculate($res)
    #write-out result
    if ($result -like "invalid*") {
      [int]$l = $res.length + 1 + $offset
      $ec = "🞪"
      $errorLine = "echo " + '`e[' + $l + 'C`e[1A' + '`e[31m' + $ec + '`e[0m'
      iex($errorLine)
    } else {
      if ($compact) {
        [int]$l = $res.length + 1 + $offset
        $ec = "✓"
        $errorLine = "echo " + '`e[' + $l + 'C`e[1A' + '`e[32m' + $ec + '`e[0m'
        iex($errorLine)
      } else {
        [int]$l = $res.length + 1 + $offset
        $ec = "✓"
        $errorLine = "echo " + '`e[' + $l + 'C`e[1A' + '`e[32m' + $ec + '`e[0m'
        iex($errorLine)
        write-host -nonewline "↳" -f darkmagenta
        write-host $result
      }
    }
  }
}

function write-head {
    write-host "                   Write expression bellow:" -f green
    write-host "==================================================================" -f darkgreen
    write-host "Write 'exit' to quit, 'clear' to clear and 'print' to print sheet.'" -f darkgray
}

#calculator
if ($expression) {
  return calculate($expression)
} else {
  if ($uiMode) {
    [string]$buffer = $null
    $old_windowtitle = $host.ui.rawui.windowtitle
    $host.ui.rawui.windowtitle = "Calculator: SheetMode"
    $loop = $true
    cls
    write-head
    while ($loop) {
      $res = read-host
      if ($res -eq "exit") {buffer -load; exit} elseif ($res -eq "clear") {$buffer = $null; cls; write-head} elseif ($res -like "print*") {
        $file = $res.trimstart("print ")
        if ($script:printOut) {$file = $script:printOut}
        $buffer = $buffer.trimStart("`n")
        $buffer | out-file -file $file
        $buffer = $null; cls; write-head
      } else {write-result($res); $buffer += "`n$res = $script:result"}
   }
    
  } else {
    write-host -nonewline "Expression: " -f green
    $res = read-host
    write-result $res 12 -compact
    return calculate($res)
  }
}


