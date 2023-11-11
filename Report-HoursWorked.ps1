param (
    [string]$lookback = '1w' # Default to 1 week
)

# Function to make a line across the screen 
function Write-Dashes { Write-Host ('-' * 80) }

function Get-StartDateFromParam {
    param (
        [string]$TimeParam
    )

    # Default start date
    $startDate = [DateTime]::Now

    # Check if input is a range
    if ($TimeParam -match 'to') {
        $dates = $TimeParam -split ' to ', 2
        $startDate = [DateTime]::ParseExact($dates[0], 'yyyy-MM-dd', $null)
        return $startDate
    }

    # Check for single time unit (e.g., '1d', '2w', '6m', '1y')
    if ($TimeParam -match '^(\d+)([dwmy])$') {
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

function Get-WeekStartEnd([DateTime]$date) {
    $dayOfWeek = [System.DayOfWeek]::Monday
    $diff = ($date.DayOfWeek.value__ - $dayOfWeek.value__)
    $diff += $diff -lt 0 ? 7 : 0
    $startOfWeek = $date.AddDays(-$diff).Date
    $endOfWeek = $startOfWeek.AddDays(6)
    return @($startOfWeek, $endOfWeek)
}

function Get-GitCommitReport {
    param (
        [string]$Since
    )

    $startDate = Get-StartDateFromParam -TimeParam $Since

    # Get commit data from Git
    $gitCommits = git log --since="$Since" --format="%ci|%s"

    # Process commit data
    $commits = $gitCommits -split '\r?\n' | Where-Object { $_ -ne '' } | ForEach-Object {
        $parts = $_ -split '\|', 2
        @{
            DateTime = [DateTime]::ParseExact($parts[0], 'yyyy-MM-dd HH:mm:ss K', $null)
            Message  = $parts[1]
        }
    } | Group-Object { $_.DateTime.Date }

    # Initialize counters
    $dailyHours = @{}
    $weeklyHours = @{}
    $monthlyHours = @{}

    # Process each day's commits
    foreach ($group in $commits) {
        $date = [DateTime]$group.Name  # Ensure it's treated as a DateTime object
        $firstCommit = ($group.Group | Sort-Object DateTime)[0].DateTime
        $lastCommit = ($group.Group | Sort-Object DateTime)[-1].DateTime
        $hoursWorked = [Math]::Round(($lastCommit - $firstCommit).TotalHours, 1)

        # Accumulate daily hours
        $dailyHours[$date] = $hoursWorked

        # Accumulate weekly and monthly hours
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

        # Output daily commit messages
        Write-Dashes
        Write-Host "`t`tDate: $($date.ToShortDateString())`t`tHours Worked: $($dailyHours[$date])"
        Write-Dashes
        Write-Host "Commits:"
        $group.Group | ForEach-Object { Write-Host "- $($_.Message)" }
        Write-Host
    }

    # Output weekly and monthly summaries
    Write-Host; Write-Dashes; Write-Host "Weekly Hours Summary:"; Write-Dashes
    foreach ($week in $weeklyHours.Keys | Sort-Object) {
        $weekData = $weeklyHours[$week]
        $formattedWeek = "{0} ({1:MM/dd} - {2:MM/dd}): {3:N1} hours" -f $week, $weekData['Start'], $weekData['End'], $weekData['Hours']
        Write-Host "`t$formattedWeek"
    }

    Write-Host; Write-Dashes; Write-Host "Monthly Hours Summary:"; Write-Dashes
    foreach ($month in $monthlyHours.Keys | Sort-Object) {
        $monthName = [CultureInfo]::CurrentCulture.DateTimeFormat.GetMonthName([int]$month.Split('-')[1])
        $formattedMonth = "{0} ({1}): {2:N1} hours" -f $month, $monthName.ToUpper(), $monthlyHours[$month]
        Write-Host "`t$formattedMonth"
    }
}

# Invoke the report function
Get-GitCommitReport -Since $lookback
