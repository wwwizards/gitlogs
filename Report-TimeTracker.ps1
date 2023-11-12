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

# Import the Active Directory module
Import-Module ActiveDirectory

function Get-UserData {

    # Get the current logged-in username
    $username = $env:USERNAME

    # Retrieve user details from AD
    $userDetails = Get-ADUser -Identity $username -Properties DisplayName, Mail

    # Output user details
    Write-Output " User: $username"
    Write-Output " Name: $($userDetails.DisplayName)"
    Write-Output " Mail: $($userDetails.Mail)"
}

function Put-ReportHeader {
    # Get the remote repository URL
    $repoUrl = git config --get remote.origin.url
    # Check if the URL contains 'https://' and '@'
    if ($repoUrl -like 'https://*' -and $repoUrl -like '*@*') {
        # Remove the substring between 'https://' and '@'
        $cleanRepoUrl = $repoUrl -replace 'https://.*@', 'https://'
    } else {
        # If the URL doesn't match the expected pattern, use it as is
        $cleanRepoUrl = $repoUrl
    }
    Write-Output "`n"
    Write-Dashes #--------------------------------------------------------------------------
    Write-Output "`t ###   FORDHAM IT - DEVOPS: AUTOMATION TEAM REPORT  ###"
    Write-Dashes #--------------------------------------------------------------------------
    Get-UserData
    Write-Output " Date: $(Get-Date -Format 'dddd, MMMM dd, yyyy')"
    Write-Output " Path: //$(HOSTNAME)/$(git rev-parse --show-toplevel)"
    Write-Output "  URL: $cleanRepoUrl ~Branch: $(git rev-parse --abbrev-ref HEAD)"
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
#--------------------------------------------------------------------------#>
function Get-GitLogs {
    [CmdletBinding()] # enable Debug & Verbose flag inheritance
    param (
        [DateTime]$FromDate,
        [DateTime]$ToDate
    )
    # fetch data from git log cli in the format that we need
    $gitCommits = git log --since="$FromDate" --until="$ToDate" --format="format:%cd|%s" --date=format:"%Y-%m-%d %H:%M:%S"
    # add some debuggin info if neeeded - triggered by the -Verbose & -Debug flags from the caller
    Write-Verbose "Fetching Git commits from $FromDate to $ToDate"
    Write-Debug "Preparing to fetch Git logs..."
    Write-Debug "`n$("-" *80)`nGIT-LOG-RAW: $gitCommits `nCOUNT:$gitCommits.count `n$("-" *80)"
    #format the array for processing
    $commits = $gitCommits -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        $dateparts = $parts[0] -split ' ', 2
        # add some error handling - just in case    
        try {
            $commitDate = [DateTime]::ParseExact($dateparts[0], 'yyyy-MM-dd', $null)
            $commitTime = [DateTime]::ParseExact($dateparts[1], 'HH:mm:ss', $null).TimeOfDay
        } catch {
            Write-Debug "Failed to parse date or time from commit log: $_"
            return $null
        }
        # format the return objects
        $commitObject = @{
            CommitDate = $commitDate
            CommitTime = $commitTime
            Message    = $parts[1]
        }
        # Debug line to check each commit object
        Write-Debug "Processed commit: $($commitObject.CommitDate) - $($commitObject.CommitTime) - $($commitObject.Message)"
        
        $commitObject
    # pipe the whole array through a grouper & filter any nulls 
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

        $hoursWorked = Update-Hours -CommitGroup $commitGroup

        $dailyHours[$commitDate] = $hoursWorked
        Update-WeeklyHours -Date $commitDate -Hours $hoursWorked -WeeklyHours ([ref]$weeklyHours)
        Update-MonthlyHours -Date $commitDate -Hours $hoursWorked -MonthlyHours ([ref]$monthlyHours)
    }

    return @{
        DailyHours = $dailyHours
        WeeklyHours = $weeklyHours
        MonthlyHours = $monthlyHours
    }
}

# function to feed stuff to other reports
function Update-Hours {
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
#  FUNCTION:  Update-WeeklyHours
#--------------------------------------------------------------------------
# PURPOSE: Updates the weekly hours worked based on a given date and hours.
# PARAMS:  -Date - The date of the commits being processed.
#          -Hours - The hours worked on the given date.
#          -WeeklyHours - A reference to the hashtable tracking weekly hours.
#--------------------------------------------------------------------------#>
function Update-WeeklyHours {
    [CmdletBinding()]
    param (
        [DateTime]$Date,
        [double]$Hours,
        [ref]$WeeklyHours
    )

    $weeklyHoursHashtable = $WeeklyHours.Value

    $weekOfYear = [Globalization.CultureInfo]::CurrentCulture.Calendar.GetWeekOfYear($Date, [Globalization.CalendarWeekRule]::FirstDay, [DayOfWeek]::Monday)
    $weekKey = "$($Date.Year)-Week$weekOfYear"

    # Calculate start and end of the week
    $dayOfWeek = [int]$Date.DayOfWeek
    $weekStart = $Date.AddDays(-$dayOfWeek + 1) # Assuming week starts on Monday
    $weekEnd = $weekStart.AddDays(6) # End of the week

    if (-not $weeklyHoursHashtable.ContainsKey($weekKey)) {
        $weeklyHoursHashtable[$weekKey] = @{
            'Hours' = 0
            'Start' = $weekStart
            'End'   = $weekEnd
        }
    }

    $weeklyHoursHashtable[$weekKey]['Hours'] += $Hours

    $WeeklyHours.Value = $weeklyHoursHashtable
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Update-MonthlyHours
#--------------------------------------------------------------------------
# PURPOSE: Updates the monthly hours worked based on a given date and hours.
# PARAMS:  -Date - The date of the commits being processed.
#          -Hours - The hours worked on the given date.
#          -MonthlyHours - A reference to the hashtable tracking monthly hours.
#--------------------------------------------------------------------------#>
function Update-MonthlyHours {
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
    Write-Output "`n"
    Write-Dashes #--------------------------------------------------------------------------
    Write-Output "`t ###   FORDHAM IT - DEVOPS: GIT-LOG DAILY DETAIL REPORT   ###"
    foreach ($date in $AccountingData.DailyHours.Keys | Sort-Object { [DateTime]::Parse($_) }) {
        $hoursWorked = $AccountingData.DailyHours[$date]
        $day = $(Get-Date $date).ToLongDateString()
        $commitGroup = $Commits | Where-Object { $_.Name -eq $date }
        Write-Verbose "Listing ALL git-log commits in Format-DailyDetails for $date"
        Write-Dashes #-------------------------------------------------------------- 
        Write-Output "  Count = $($CommitGroup.count)  |   ~ $($day) `t`t |  Hours Worked: $([math]::Round($($hoursWorked/1),1).ToString("F1"))"
        Write-Dashes #--------------------------------------------------------------
        if ($hoursWorked -eq 1) { Write-Output "`t     | *** ONLY ONE RECORD FOUND - ASSUMING AT LEAST 1-HOUR ***" }        
        if (-not $commitGroup) {Write-Debug "No commit data found for date: $date"; continue }
        foreach ($commit in $commitGroup.Group) {
            $truncatedMessage = $commit.Message.Substring(0, [Math]::Min(65, $commit.Message.Length))
            Write-Output " ~ $($commit.CommitTime)  | $truncatedMessage"
        }
    }
    Write-Dashes "`n`n" #-------------------------------------------------------------------
}

<#--------------------------------------------------------------------------
#  FUNCTION:  Format-Summaries
#--------------------------------------------------------------------------
# PURPOSE: Generates a summary report of Git commit data, providing weekly
#          and monthly aggregates of hours worked. It displays a formatted
#          summary for each week and month within the specified date range,
#          along with the total hours worked for each period.
# PARAMS:  -AccountingData (Object): The calculated hours for each day,
#          week, and month.
# USAGE:   This function is called within the main script to display
#          summary information of Git commits. It should be used after
#          collecting and processing commit data with other functions.
#--------------------------------------------------------------------------#>
function Format-Summaries {
    param (
        [Object]$AccountingData
    )

    # Output Monthly Summary
    Write-Output "" 
    Write-Dashes #-------------------------------------------------------------------------- 
    Write-Output "`t ###   GIT-CODE CHECK-IN MONTHLY HOURS SUMMARY REPORT   ###"
    Write-Dashes #--------------------------------------------------------------------------
    foreach ($month in $AccountingData.MonthlyHours.Keys | Sort-Object) {
        $monthNumber = [int]$month.Split('-')[1]
        $monthName = [CultureInfo]::CurrentCulture.DateTimeFormat.GetMonthName($monthNumber)
        $formattedMonth = "   {0}    |  Date Range: {1}  `t  `t`t |  Hours Worked: {2:N1} " -f $month, $monthName, $AccountingData.MonthlyHours[$month]
        Write-Output "$formattedMonth"
    }
    Write-Dashes "`n" #-------------------------------------------------------------------

    # Output Weekly Summary
    Write-Output ""
    Write-Dashes #-------------------------------------------------------------------------- 
    Write-Output "`t ###   GIT-CODE CHECK-IN WEEKLY HOURS SUMMARY REPORT   ###"
    Write-Dashes #--------------------------------------------------------------------------
    foreach ($week in $AccountingData.WeeklyHours.Keys | Sort-Object) {
        $weekData = $AccountingData.WeeklyHours[$week]

        # Null check for 'Start' and 'End'
        $weekStart = if ($weekData['Start']) { $weekData['Start'].ToShortDateString() } else { "N/A" }
        $weekEnd = if ($weekData['End']) { $weekData['End'].ToShortDateString() } else { "N/A" }

        $formattedWeek = " {0}  |  Date Range: {1} to {2}`t |  Hours Worked: {3:N1}" -f $week, $weekStart, $weekEnd, $weekData['Hours']
        Write-Output "$formattedWeek"
    }
    Write-Dashes "`n" #-------------------------------------------------------------------
}

####  Main Script Logic ###
$startDate = Get-StartDateFromParam -TimeParam $lookback
$endDate = [DateTime]::Now

Put-ReportHeader
Write-Verbose "Start Date: $startDate, End Date: $endDate"

$commitData = Get-GitLogs -FromDate $startDate -ToDate $endDate
if (-not $commitData) {
    Write-Error "No commit data found for the given date range."
    exit
}

$accountingData = Get-Totals -Commits $commitData
Format-Summaries -AccountingData $accountingData

if (-not $SummaryOnly -or $lookback -match '^(\d+)(d|m)$') {
    Format-DailyDetails -AccountingData $accountingData -Commits $commitData
}

