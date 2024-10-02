
<!-- BEGIN Joe's headers2md AutoGen -->
<div style="float:left; width:100%; padding:5px">

# Documentation for Report-TimeLogs.ps1
- ### FUNCTION : GetUserDetails
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Generates a report of Git commits for a specified date range, providing daily details (with a minimum of 1-hour work assumption) and weekly & monthly summaries in chronological order. |
  | CREATED | 2023-NOV-10 - BY: Joe Negron <jnegron9@fordham.edu> |
  | USAGE | .\Report-HoursWorked-v03.ps1 -lookback '1m' -SummaryOnly |
  | PURPOSE | Retrieves the user's full name and email address. If AD information is not available, prompts the user for their details and saves them as environment variables for subsequent use. |
  | RETURNS | Outputs the user's full name and email address. |
- ### FUNCTION : Set-ReportHeader (self-explanatory)
- ### FUNCTION : Get-StartDateFromParam
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Calculates the start date based on the provided time parameter. |
  | PARAMS | $TimeParam - A string representing the time parameter, which can be a specific date, a date range, or a relative time period (e.g., '1w', '2m'). |
  | RETURNS | A DateTime object representing the calculated start date. |
- ### FUNCTION : Get-GitLogs
- ### FUNCTION : Get-Totals
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Calculates daily, weekly, and monthly work hours based on Git commits. |
  | PARAMS | $Commits - An object containing grouped Git commit data. |
  | RETURNS | A hashtable with keys 'DailyHours', 'WeeklyHours', and 'MonthlyHours', each containing corresponding calculated hours. |
- ### FUNCTION : Update-WeeklyHours
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Updates the weekly hours worked based on a given date and hours. |
  | PARAMS | -Date - The date of the commits being processed. -Hours - The hours worked on the given date. -WeeklyHours - A reference to the hashtable tracking weekly hours. |
- ### FUNCTION : Update-MonthlyHours
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Updates the monthly hours worked based on a given date and hours. |
  | PARAMS | -Date - The date of the commits being processed. -Hours - The hours worked on the given date. -MonthlyHours - A reference to the hashtable tracking monthly hours. |
- ### FUNCTION : Format-DailyDetails
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Formats and outputs the detailed daily information of Git commits, including the commit time and message. |
  | PARAMS | -AccountingData (Object): The calculated hours for each day. -Commits (Object): Grouped Git commit data with dates, times, and messages. |
  | RETURNS | Outputs the formatted details of daily Git commits. |
  | USAGE | Called within the main script to display detailed commit information. |
- ### FUNCTION : Format-DailySummary
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Formats and outputs the detailed daily information of Git commits, including the commit time and message. |
  | PARAMS | -AccountingData (Object): The calculated hours for each day. -Commits (Object): Grouped Git commit data with dates, times, and messages. |
  | RETURNS | Outputs the formatted details of daily Git commits. |
  | USAGE | Called within the main script to display detailed commit information. |
- ### FUNCTION : Format-Summaries
  |   TAG   | Description  |
  | ------- | :----------- |
  | PURPOSE | Generates a summary report of Git commit data, providing weekly and monthly aggregates of hours worked. It displays a formatted summary for each week and month within the specified date range, along with the total hours worked for each period. |
  | PARAMS | -AccountingData (Object): The calculated hours for each day, week, and month. |
  | USAGE | This function is called within the main script to display summary information of Git commits. It should be used after collecting and processing commit data with other functions. |

  <div>UPDATED: 2024-10-02 09:19:58 EDT (New York)</div>
  <div>BY: Automation > tools/scripts/python/headers2md.py</div>
</div>

