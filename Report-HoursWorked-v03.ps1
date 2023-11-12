<#--------------------------------------------------------------------------
#  SCRIPT:  Report-HoursWorked-v03.ps1
#--------------------------------------------------------------------------
# PURPOSE: Generates a report of Git commits for a specified date range, 
#          providing daily details (with a minimum of 1-hour work assumption)
#          and weekly & monthly summaries in chronological order.
# CREATED: 2023-NOV-10 - BY: Joe Negron <jnegron9@fordham.edu>
# USAGE:   .\Report-HoursWorked-v03.ps1 -lookback '1m' -SummaryOnly
#--------------------------------------------------------------------------#>
[CmdletBinding()] #ensure that this scope inherits -Verbose & -Debug flags 

param (
    [string]$lookback = '14d', # Default to 2 weeks
    [switch]$SummaryOnly
)

# Function to create a string of dashes for visual separation in output
function Write-Dashes {
    return '-' * 80
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Get-StartDateFromParam
#--------------------------------------------------------------------------
# PURPOSE: Calculates the start date based on the provided time parameter.
# PARAMS:  $TimeParam - A string representing the time parameter, which can be
#          a specific date, a date range, or a relative time period (e.g., '1w', '2m').
# RETURNS: A DateTime object representing the calculated start date.
#--------------------------------------------------------------------------#>

function Get-StartDateFromParam {
    param (
        [string]$TimeParam
    )

    # Default to now
    $startDate = [DateTime]::Now

    # Match specific date formats (e.g., 'MM/DD/YYYY')
    if ($TimeParam -match '^\d{2}/\d{2}/\d{4}$') {
        return [DateTime]::ParseExact($TimeParam, 'MM/dd/yyyy', $null)
    }
    # Match date range formats (e.g., 'MM/DD/YYYY to MM/DD/YYYY')
    elseif ($TimeParam -match '^\d{2}/\d{2}/\d{4} to \d{2}/\d{2}/\d{4}$') {
        $dates = $TimeParam -split ' to ', 2
        return [DateTime]::ParseExact($dates[0], 'MM/dd/yyyy', $null)
    }
    # Handle relative time periods (e.g., '1d', '1w', '1m', '1y')
    elseif ($TimeParam -match '^(\d+)([dwmy])$') {
        $quantity = $matches[1]
        $unit = $matches[2]
        switch ($unit) {
            'd' { return $startDate.AddDays(-$quantity) }
            'w' { return $startDate.AddDays(-7 * $quantity) }
            'm' { return $startDate.AddMonths(-$quantity) }
            'y' { return $startDate.AddYears(-$quantity) }
        }
    }
    # If no match, return current date
    return $startDate
}


<#--------------------------------------------------------------------------
#  FUNCTION:  Get-GitLogs
#--------------------------------------------------------------------------
# PURPOSE: Fetches and processes Git commit data for a given date range.
# PARAMS:  $FromDate - The starting date for fetching commits.
#          $ToDate - The ending date for fetching commits.
# RETURNS: An array of objects representing grouped Git commits by date.
#--------------------------------------------------------------------------#>
function Get-GitLogs {
    param (
        [DateTime]$FromDate,
        [DateTime]$ToDate
    )
    Write-Host "Fetching Git commits from $FromDate to $ToDate"

    # Define the format for the date in git log
    $dateFormat = "yyyy-MM-dd HH:mm:ss"
    $gitCommits = git log --since="$FromDate" --until="$ToDate" --format="format:%cd|%s" --date=format:"%Y-%m-%d %H:%M:%S"

    # Parse the git log output
    $commits = $gitCommits -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        @{
            DateTime = [DateTime]::ParseExact($parts[0], $dateFormat, $null)
            Message  = $parts[1]
        }
    } | Group-Object { $_.DateTime.Date }

    return $commits
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Get-Totals
#--------------------------------------------------------------------------
# PURPOSE: Calculates daily, weekly, and monthly work hours based on Git commits.
# PARAMS:  $Commits - An object containing grouped Git commit data.
# RETURNS: A hashtable with keys 'DailyHours', 'WeeklyHours', and 'MonthlyHours',
#          each containing corresponding calculated hours.
#--------------------------------------------------------------------------#>

function Get-Totals {
    param (
        [Object]$Commits
    )
    $dailyHours = @{}
    $weeklyHours = @{}
    $monthlyHours = @{}

    foreach ($commitGroup in $Commits) {
        # Debugging: Print out types and values
        Write-Debug "Commit group date (Name): $($commitGroup.Name)"
        Write-Debug "Date variable type: $([date].GetType().FullName)"
        Write-Debug "Date variable value: $date"
    
        if (-not $commitGroup.Name) {
            Write-Verbose "Skipping commit group with null date."
            continue
        }
    
        $date = [DateTime]$commitGroup.Name.Date
        Write-Debug "Processing date: $date"

        $firstCommit = ($commitGroup.Group | Sort-Object DateTime)[0].DateTime
        $lastCommit = ($commitGroup.Group | Sort-Object DateTime)[-1].DateTime
        $hoursWorked = if ($commitGroup.Group.Count -eq 1) { 1 } 
                       else { [Math]::Round(($lastCommit - $firstCommit).TotalHours, 1) }
        Write-Debug "Hours worked on ${date}: $hoursWorked"

        $dailyHours[$date] = $hoursWorked

        $weekOfYear = [Globalization.CultureInfo]::CurrentCulture.Calendar.GetWeekOfYear($date, [Globalization.CalendarWeekRule]::FirstDay, [DayOfWeek]::Monday)
        $weekKey = "$($date.Year)-Week$weekOfYear"
        Write-Debug "Week key: $weekKey"

        if (-not $weeklyHours.ContainsKey($weekKey)) {
            $weeklyHours[$weekKey] = @{ 'Hours' = 0 }
        }
        $weeklyHours[$weekKey]['Hours'] += $hoursWorked

        $monthKey = $date.ToString('yyyy-MM')
        Write-Debug "Month key: $monthKey"

        if (-not $monthlyHours.ContainsKey($monthKey)) {
            $monthlyHours[$monthKey] = 0
        }
        $monthlyHours[$monthKey] += $hoursWorked
    }

    return @{
        DailyHours = $dailyHours
        WeeklyHours = $weeklyHours
        MonthlyHours = $monthlyHours
    }
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Format-DailyDetails
#--------------------------------------------------------------------------
# PURPOSE: Formats and outputs the detailed daily information of Git commits,
#          including the commit time and message.
# PARAMS:  -AccountingData (Object): The calculated hours for each day.
#          -Commits (Object): Grouped Git commit data with dates and messages.
# RETURNS: Outputs the formatted details of daily Git commits.
# USAGE:   Called within the main script to display detailed commit information.
#--------------------------------------------------------------------------#>

function Format-DailyDetails {
    param (
        [Object]$AccountingData,
        [Object]$Commits
    )
    foreach ($date in $AccountingData.DailyHours.Keys | Sort-Object) {
        $hoursWorked = $AccountingData.DailyHours[$date]
        Write-Output "`t`tDate: $($date.ToShortDateString())`t`tHours Worked: $hoursWorked"
        
        if ($hoursWorked -eq 1) { Write-Output " *** ASSUMING AT LEAST 1-HOUR ***" }
        
        Write-Output "Commits:"
        $commitGroup = $Commits | Where-Object { $_.Name -eq $date }
        foreach ($commit in $commitGroup.Group) {
            $truncatedMessage = $commit.Message.Substring(0, [Math]::Min(65, $commit.Message.Length))
            Write-Output "- $($commit.DateTime.ToShortTimeString()) | $truncatedMessage"
        }
    }
}





# Generates weekly and monthly summaries of Git commit data
function Format-Summaries {
    param (
        [Object]$AccountingData
    )
    # Output Weekly and Monthly Summaries
    # ...
}

# Main Script Logic
$startDate = Get-StartDateFromParam -TimeParam $lookback
$endDate = [DateTime]::Now

$commitData = Get-GitLogs -FromDate $startDate -ToDate $endDate
$accountingData = Get-Totals -Commits $commitData

if (-not $SummaryOnly -or $lookback -match '^(\d+)(d|m)$') {
    Format-DailyDetails -AccountingData $accountingData -Commits $commitData
}

Format-Summaries -AccountingData $accountingData
