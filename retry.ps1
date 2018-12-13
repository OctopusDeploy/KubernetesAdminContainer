function Retry-Command
{
    param (
        [Parameter(Mandatory=$true)][string]$command,
        [Parameter(Mandatory=$true)][hashtable]$args,
        [Parameter(Mandatory=$false)][int]$retries = 5,
        [Parameter(Mandatory=$false)][int]$secondsDelay = 2
    )

    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are
    # treated as terminating errors, and will be caught by the catch block.
    $args.ErrorAction = "Stop"

    $retrycount = 0
    $completed = $false

    while (-not $completed) {
        try {
            & $command @args
            Write-Verbose ("Command [{0}] succeeded." -f $command)
            $completed = $true
        } catch {
            if ($retrycount -ge $retries) {
                Write-Verbose ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount)
                throw
            } else {
                Write-Verbose ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay)
                Start-Sleep $secondsDelay
                $retrycount++
            }
        }
    }
}

<#
.SYNOPSIS
Calls a shell (cmd) command with retries

.DESCRIPTION
The Call-CommandWithRetries function calls shell (cmd) commands using the provided parameters, with optional retries in configurable intervals upon failures.

.PARAMETER Command
The command to call.

.PARAMETER Arguments
Arguments to pass when invoking the comand.

.PARAMETER TrustExitCode
Trust the command's exit code for the purpose of determining whether it was successful or not.
If this parameter is $False, a non-empty stderr will also be considered a failure.

.PARAMETER RetrySleepSeconds
Time in seconds to sleep between retry attempts in case of command failure.

.PARAMETER MaxAttempts
Maximum number of retry attempts in case of command failure.

.PARAMETER PrintCommand
Determines whether or not to print the full command to the host before execution.

.INPUTS
None. You cannot pipe objects to Call-CommandWithRetries.

.OUTPUTS
The output of the last command execution.

.EXAMPLE
Use cURL for Windows to download the latest NuGet command-line client
C:\PS> Call-CommandWithRetries "curl.exe" @("--fail", "-O", "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe")

#>
function Call-CommandWithRetries
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$Command,
        [Array]$Arguments,
        [bool]$TrustExitCode = $True,
        [int]$RetrySleepSeconds = 10,
        [int]$MaxAttempts = 10,
        [bool]$PrintCommand = $True,
        [bool]$PrintOutput = $False
    )

    Process
    {
        $attempt = 0
        while ($true)
        {
            Write-Host $(if ($PrintCommand) {"Executing: $Command $Arguments"} else {"Executing command..."})
            & $Command $Arguments 2>&1 | Tee-Object -Variable output
            if ($PrintOutput) {Write-Host $output}

            $stderr = $output | where { $_ -is [System.Management.Automation.ErrorRecord] }
            if ( ($LASTEXITCODE -eq 0) -and ($TrustExitCode -or !($stderr)) )
            {
                Write-Host "Command executed successfully"
                return $output
            }

            Write-Host "Command failed with exit code ($LASTEXITCODE) and stderr: $stderr" -ForegroundColor Yellow
            if ($attempt -eq $MaxAttempts)
            {
                $ex = new-object System.Management.Automation.CmdletInvocationException "All retry attempts exhausted"
                $category = [System.Management.Automation.ErrorCategory]::LimitsExceeded
                $errRecord = new-object System.Management.Automation.ErrorRecord $ex, "CommandFailed", $category, $Command
                $psCmdlet.WriteError($errRecord)
                return $output
            }

            $attempt++;
            Write-Host "Retrying test execution [#$attempt/$MaxAttempts] in $RetrySleepSeconds seconds..."
            Start-Sleep -s $RetrySleepSeconds
        }
    }
}
