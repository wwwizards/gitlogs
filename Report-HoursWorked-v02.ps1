<#--------------------------------------------------------------------------
#  SCRIPT:  Report-HoursWorked-v02.ps1
#--------------------------------------------------------------------------
# PURPOSE: Generates a report of Git commits for a specified date range, 
#          providing daily details (with a minimum of 1-hour work assumption)
#          and weekly & monthly summaries in chronological order.
# USAGE:   .\Report-HoursWorked-v02.ps1 -lookback '1m' -SummaryOnly
#--------------------------------------------------------------------------#>

param (
    [string]$lookback = '1w', # Default to 1 week
    [switch]$SummaryOnly
)

# Function to create a string of dashes for visual separation in output
function Write-Dashes {
    return '-' * 80
}

# Calculates the start date based on the provided time parameter
function Get-StartDateFromParam {
    param (
        [string]$TimeParam
    )
    $startDate = [DateTime]::Now

    if ($TimeParam -match 'to') {
        $dates = $TimeParam -split ' to ', 2
        $startDate = [DateTime]::ParseExact($dates[0], 'yyyy-MM-dd', $null)
    } elseif ($TimeParam -match '^(\d+)([dwmy])$') {
        $quantity = $matches[1]
        $unit = $matches[2]
        switch ($unit) {
            'd' { $startDate = $startDate.AddDays(-$quantity) }
            'w' { $startDate = $startDate.AddDays(-7 * $quantity) }
            'm' { $startDate = $startDate.AddMonths(-$quantity) }
            'y' { $startDate = $startDate.AddYears(-$quantity) }
        }
    }

    return $startDate
}

# Determines the start and end dates of the week for a given date
function Get-WeekStartEnd {
    param (
        [DateTime]$date
    )
    $dayOfWeek = [System.DayOfWeek]::Monday
    $diff = ($date.DayOfWeek.value__ - $dayOfWeek.value__)
    $diff += $diff -lt 0 ? 7 : 0
    $startOfWeek = $date.AddDays(-$diff).Date
    $endOfWeek = $startOfWeek.AddDays(6)
    return @($startOfWeek, $endOfWeek)
}

# Fetches Git commit data for a specified date range
function Get-GitCommitData {
    param (
        [DateTime]$FromDate,
        [DateTime]$ToDate
    )
    $gitCommits = git log --since="$FromDate" --until="$ToDate" --format="%ci|%s"
    $commits = $gitCommits -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        @{
            DateTime = [DateTime]::ParseExact($parts[0], 'yyyy-MM-dd HH:mm:ss K', $null)
            Message  = $parts[1]
        }
    } | Group-Object { $_.DateTime.Date }
    return $commits
}

# Performs accounting of Git commit hours, including weekly and monthly tally
function Perform-Accounting {
    param (
        [Object]$Commits
    )
    $dailyHours = @{}
    $weeklyHours = @{}
    $monthlyHours = @{}

    foreach ($group in $Commits) {
        $date = [DateTime]$group.Name
        $firstCommit = ($group.Group | Sort-Object DateTime)[0].DateTime
        $lastCommit = ($group.Group | Sort-Object DateTime)[-1].DateTime
        $hoursWorked = if ($group.Group.Count -eq 1) { 1 } 
                       else { [Math]::Round(($lastCommit - $firstCommit).TotalHours, 1) }
        $dailyHours[$date] = $hoursWorked

        $weekOfYear = [Globalization.CultureInfo]::CurrentCulture.Calendar.GetWeekOfYear($date, [Globalization.CalendarWeekRule]::FirstDay, [DayOfWeek]::Monday)
        $weekKey = "$($date.Year)-Week$weekOfYear"
        $weekStartEnd = Get-WeekStartEnd $date
        if (-not $weeklyHours.ContainsKey($weekKey)) {
            $weeklyHours[$weekKey] = @{
                'Hours' = 0
                'Start' = $weekStartEnd[0]
                'End'   = $weekStartEnd[1]
            }
        }
        $weeklyHours[$weekKey]['Hours'] += $hoursWorked

        $monthKey = $date.ToString('yyyy-MM')
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

# Formats the daily details of Git commits for reporting
function Format-DailyDetails {
    param (
        [Object]$AccountingData
    )
    foreach ($date in $AccountingData.DailyHours.Keys | Sort-Object) {
        $hoursWorked = $AccountingData.DailyHours[$date]
        if ($hoursWorked -eq 1) { Write-Output " *** ASSUMING AT LEAST 1-HOUR ***" }
        Write-Output "`t`tDate: $($date.ToShortDateString())`t`tHours Worked: $hoursWorked"
        Write-Output "Commits:"
        # Output Commit Messages
        # ...
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

$commitData = Get-GitCommitData -FromDate $startDate -ToDate $endDate
$accountingData = Perform-Accounting -Commits $commitData

if (-not $SummaryOnly -or $lookback -match '^(\d+)(d|m)$') {
    Format-DailyDetails -AccountingData $accountingData
}

Format-Summaries -AccountingData $accountingData
