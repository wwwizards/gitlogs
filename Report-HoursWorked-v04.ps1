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
    [CmdletBinding()]
    param (
        [string]$TimeParam
    )

    Write-Debug "Processing time parameter: $TimeParam"

    # Default to now
    $startDate = [DateTime]::Now

    # Match specific date formats (e.g., 'MM/DD/YYYY')
    if ($TimeParam -match '^\d{2}/\d{2}/\d{4}$') {
        $parsedDate = [DateTime]::ParseExact($TimeParam, 'MM/dd/yyyy', $null)
        Write-Verbose "Parsed specific date format: $parsedDate"
        return $parsedDate
    }
    # Match date range formats (e.g., 'MM/DD/YYYY to MM/DD/YYYY')
    elseif ($TimeParam -match '^\d{2}/\d{2}/\d{4} to \d{2}/\d{2}/\d{4}$') {
        $dates = $TimeParam -split ' to ', 2
        $parsedDate = [DateTime]::ParseExact($dates[0], 'MM/dd/yyyy', $null)
        Write-Verbose "Parsed date range format, start date: $parsedDate"
        return $parsedDate
    }
    # Handle relative time periods (e.g., '1d', '1w', '1m', '1y')
    elseif ($TimeParam -match '^(\d+)([dwmy])$') {
        $quantity = $matches[1]
        $unit = $matches[2]
        switch ($unit) {
            'd' { $calculatedDate = $startDate.AddDays(-$quantity) }
            'w' { $calculatedDate = $startDate.AddDays(-7 * $quantity) }
            'm' { $calculatedDate = $startDate.AddMonths(-$quantity) }
            'y' { $calculatedDate = $startDate.AddYears(-$quantity) }
            default { $calculatedDate = $startDate }
        }
        Write-Verbose "Parsed relative time period, calculated date: $calculatedDate"
        return $calculatedDate
    }
    # If no match, return current date
    Write-Debug "No matching format found, returning current date: $startDate"
    return $startDate
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Get-GitLogs
#--------------------------------------------------------------------------#>function Get-GitLogs {
    [CmdletBinding()]
    param (
        [DateTime]$FromDate,
        [DateTime]$ToDate
    )

    Write-Verbose "Fetching Git commits from $FromDate to $ToDate"
    Write-Debug "Preparing to fetch Git logs..."

    $dateFormat = "yyyy-MM-dd HH:mm:ss"
    $gitCommits = git log --since="$FromDate" --until="$ToDate" --format="format:%cd|%s" --date=format:"%Y-%m-%d %H:%M:%S"

    Write-Debug "`n$("-" *80)`nGIT-LOG-RAW: $gitCommits `nCOUNT:$gitCommits.count `n$("-" *80)"

    $commits = $gitCommits -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        $dateparts = $parts[0] -split ' ', 2

        try {
            $commitDate = [DateTime]::ParseExact($dateparts[0], 'yyyy-MM-dd', $null)
            $commitTime = [DateTime]::ParseExact($dateparts[1], 'HH:mm:ss', $null).TimeOfDay
        } catch {
            Write-Debug "Failed to parse date or time from commit log: $_"
            return $null
        }

        $commitObject = @{
            CommitDate = $commitDate
            CommitTime = $commitTime
            Message    = $parts[1]
        }

        # Debug line to check each commit object
        Write-Debug "Processed commit: $($commitObject.CommitDate) - $($commitObject.CommitTime) - $($commitObject.Message)"
        
        $commitObject
    } | Where-Object { $_ -ne $null } | Group-Object { $_.CommitDate }

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
    [CmdletBinding()]
    param ( [Object]$Commits )

    $dailyHours = @{}
    $weeklyHours = @{}
    $monthlyHours = @{}

    foreach ($commitGroup in $Commits) {
        $commitDate = $commitGroup.Name

        if (-not $commitDate) {
            Write-Verbose "Skipping commit group with null date."
            continue
        }

        $hoursWorked = CalculateHours -CommitGroup $commitGroup

        $dailyHours[$commitDate] = $hoursWorked
        UpdateWeeklyHours -Date $commitDate -Hours $hoursWorked -WeeklyHours ([ref]$weeklyHours)
        UpdateMonthlyHours -Date $commitDate -Hours $hoursWorked -MonthlyHours ([ref]$monthlyHours)
    }

    return @{
        DailyHours = $dailyHours
        WeeklyHours = $weeklyHours
        MonthlyHours = $monthlyHours
    }
}


function CalculateHours {
    param (
        [Object]$CommitGroup
    )

    if ($CommitGroup.Group.Count -eq 1) {
        return 1
    } else {
        $sortedCommits = $CommitGroup.Group | Sort-Object CommitTime
        $startTime = $sortedCommits[0].CommitTime
        $endTime = $sortedCommits[-1].CommitTime
        return [Math]::Round(($endTime - $startTime).TotalHours, 1)
    }
}

<#--------------------------------------------------------------------------
#  FUNCTION:  UpdateWeeklyHours
#--------------------------------------------------------------------------
# PURPOSE: Updates the weekly hours worked based on a given date and hours.
# PARAMS:  -Date - The date of the commits being processed.
#          -Hours - The hours worked on the given date.
#          -WeeklyHours - A reference to the hashtable tracking weekly hours.
#--------------------------------------------------------------------------#>
function UpdateWeeklyHours {
    [CmdletBinding()]
    param (
        [DateTime]$Date,
        [double]$Hours,
        [ref]$WeeklyHours
    )

    # Extract the hashtable from the reference
    $weeklyHoursHashtable = $WeeklyHours.Value

    $weekOfYear = [Globalization.CultureInfo]::CurrentCulture.Calendar.GetWeekOfYear($Date, [Globalization.CalendarWeekRule]::FirstDay, [DayOfWeek]::Monday)
    $weekKey = "$($Date.Year)-Week$weekOfYear"
    
    if (-not $weeklyHoursHashtable.ContainsKey($weekKey)) {
        $weeklyHoursHashtable[$weekKey] = @{ 'Hours' = 0 }
    }

    $weeklyHoursHashtable[$weekKey]['Hours'] += $Hours

    # Update the reference with the modified hashtable
    $WeeklyHours.Value = $weeklyHoursHashtable
}

<#--------------------------------------------------------------------------
#  FUNCTION:  UpdateMonthlyHours
#--------------------------------------------------------------------------
# PURPOSE: Updates the monthly hours worked based on a given date and hours.
# PARAMS:  -Date - The date of the commits being processed.
#          -Hours - The hours worked on the given date.
#          -MonthlyHours - A reference to the hashtable tracking monthly hours.
#--------------------------------------------------------------------------#>
function UpdateMonthlyHours {
    [CmdletBinding()]
    param (
        [DateTime]$Date,
        [double]$Hours,
        [ref]$MonthlyHours
    )

    # Extract the hashtable from the reference
    $monthlyHoursHashtable = $MonthlyHours.Value

    $monthKey = $Date.ToString('yyyy-MM')

    if (-not $monthlyHoursHashtable.ContainsKey($monthKey)) {
        $monthlyHoursHashtable[$monthKey] = 0
    }

    $monthlyHoursHashtable[$monthKey] += $Hours

    # Update the reference with the modified hashtable
    $MonthlyHours.Value = $monthlyHoursHashtable
}




<#--------------------------------------------------------------------------
#  FUNCTION:  Format-DailyDetails
#--------------------------------------------------------------------------
# PURPOSE: Formats and outputs the detailed daily information of Git commits,
#          including the commit time and message.
# PARAMS:  -AccountingData (Object): The calculated hours for each day.
#          -Commits (Object): Grouped Git commit data with dates, times, and messages.
# RETURNS: Outputs the formatted details of daily Git commits.
# USAGE:   Called within the main script to display detailed commit information.
#--------------------------------------------------------------------------#>
function Format-DailyDetails {
    [CmdletBinding()]
    param (
        [Object]$AccountingData,
        [Object]$Commits
    )

    foreach ($date in $AccountingData.DailyHours.Keys | Sort-Object) {
        $hoursWorked = $AccountingData.DailyHours[$date]
        $day = $(Get-Date $date).ToLongDateString()
        $dayOfWeek = (Get-Date $date).DayOfWeek
        $commitGroup = $Commits | Where-Object { $_.Name -eq $date }
        Write-Verbose "Listing ALL git-log commits in Format-DailyDetails for $date"
        Write-Dashes #--------------------------------------------------------------
        Write-Output "  Count = $($CommitGroup.count)  | $($day) `t  `t |  Hours Worked: $hoursWorked"
        Write-Dashes #--------------------------------------------------------------
        if ($hoursWorked -eq 1) { Write-Output "`t     | *** ONLY ONE RECORD FOUND - ASSUMING AT LEAST 1-HOUR ***" }        
        if (-not $commitGroup) {Write-Debug "No commit data found for date: $date"; continue }
        foreach ($commit in $commitGroup.Group) {
            $truncatedMessage = $commit.Message.Substring(0, [Math]::Min(65, $commit.Message.Length))
            Write-Output " ~ $($commit.CommitTime)  | $truncatedMessage"
        }
    }
}




# Function to generate weekly and monthly summaries of Git commit data
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
Write-Verbose "Start Date: $startDate, End Date: $endDate"

$commitData = Get-GitLogs -FromDate $startDate -ToDate $endDate
if (-not $commitData) {
    Write-Error "No commit data found for the given date range."
    exit
}

$accountingData = Get-Totals -Commits $commitData

if (-not $SummaryOnly -or $lookback -match '^(\d+)(d|m)$') {
    Format-DailyDetails -AccountingData $accountingData -Commits $commitData
}

Format-Summaries -AccountingData $accountingData
