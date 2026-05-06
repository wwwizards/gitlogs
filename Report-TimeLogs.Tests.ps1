#Requires -Module Pester
<#--------------------------------------------------------------------------
#  FILE:    Report-TimeLogs.Tests.ps1
#--------------------------------------------------------------------------
# PURPOSE: Pester test suite for Report-TimeLogs.ps1
# USAGE:   Invoke-Pester .\Report-TimeLogs.Tests.ps1 -Output Detailed
# CREATED: 2026-0506 - wwwizards
#--------------------------------------------------------------------------#>

BeforeAll {
    # Dot-source the script to load all functions into scope without executing main body
    . "$PSScriptRoot\Report-TimeLogs.ps1" -WhatIf -ErrorAction SilentlyContinue
    # Re-dot-source without params to just load functions
    $scriptContent = Get-Content "$PSScriptRoot\Report-TimeLogs.ps1" -Raw
    # Load only function definitions by stripping the param block execution
    $functions = [scriptblock]::Create(
        ($scriptContent -replace '(?ms)^(\[CmdletBinding.*?^param\s*\(.*?\))', '')
    )
    . $functions
}

Describe "Get-StartDateFromParam" {

    Context "Relative time periods" {
        It "parses '1d' as yesterday" {
            $result = Get-StartDateFromParam -TimeParam '1d'
            $result.Date | Should -Be ([DateTime]::Today.AddDays(-1))
        }

        It "parses '1w' as 7 days ago" {
            $result = Get-StartDateFromParam -TimeParam '1w'
            $result.Date | Should -Be ([DateTime]::Today.AddDays(-7))
        }

        It "parses '1m' as 1 month ago" {
            $result = Get-StartDateFromParam -TimeParam '1m'
            $result.Date | Should -Be ([DateTime]::Today.AddMonths(-1))
        }

        It "parses '1y' as 1 year ago" {
            $result = Get-StartDateFromParam -TimeParam '1y'
            $result.Date | Should -Be ([DateTime]::Today.AddYears(-1))
        }

        It "parses '14d' as 14 days ago" {
            $result = Get-StartDateFromParam -TimeParam '14d'
            $result.Date | Should -Be ([DateTime]::Today.AddDays(-14))
        }

        It "parses '2w' as 14 days ago" {
            $result = Get-StartDateFromParam -TimeParam '2w'
            $result.Date | Should -Be ([DateTime]::Today.AddDays(-14))
        }
    }

    Context "Specific date format MM/DD/YYYY" {
        It "parses a specific date correctly" {
            $result = Get-StartDateFromParam -TimeParam '11/01/2023'
            $result | Should -Be ([DateTime]::ParseExact('11/01/2023', 'MM/dd/yyyy', $null))
        }
    }

    Context "Date range format" {
        It "parses the start date from a range" {
            $result = Get-StartDateFromParam -TimeParam '10/01/2023 to 10/31/2023'
            $result | Should -Be ([DateTime]::ParseExact('10/01/2023', 'MM/dd/yyyy', $null))
        }
    }

    Context "Invalid / unrecognized input" {
        It "returns approximately now for garbage input" {
            $before = [DateTime]::Now.AddSeconds(-2)
            $result = Get-StartDateFromParam -TimeParam 'notadate'
            $result | Should -BeGreaterThan $before
        }
    }
}

Describe "Update-Hours" {

    Context "Single commit" {
        It "returns 1.0 for a single commit" {
            $mockGroup = [PSCustomObject]@{
                Group = @(
                    @{ CommitTime = [TimeSpan]::FromHours(10) }
                )
            }
            $result = Update-Hours -CommitGroup $mockGroup
            $result | Should -Be 1.0
        }
    }

    Context "Multiple commits" {
        It "calculates span between first and last commit" {
            $mockGroup = [PSCustomObject]@{
                Group = @(
                    @{ CommitTime = [TimeSpan]::FromHours(9) },
                    @{ CommitTime = [TimeSpan]::FromHours(11) },
                    @{ CommitTime = [TimeSpan]::FromHours(13) }
                )
            }
            $result = Update-Hours -CommitGroup $mockGroup
            $result | Should -Be 4.0
        }

        It "rounds to 1 decimal place" {
            $mockGroup = [PSCustomObject]@{
                Group = @(
                    @{ CommitTime = [TimeSpan]::Parse('09:00:00') },
                    @{ CommitTime = [TimeSpan]::Parse('10:30:45') }
                )
            }
            $result = Update-Hours -CommitGroup $mockGroup
            $result | Should -Be 1.5
        }
    }
}

Describe "Update-WeeklyHours" {

    It "creates a new week key if it does not exist" {
        $weeklyHours = @{}
        $date = [DateTime]::ParseExact('2023-11-06', 'yyyy-MM-dd', $null)
        Update-WeeklyHours -Date $date -Hours 4.0 -WeeklyHours ([ref]$weeklyHours)
        $weeklyHours.Keys | Should -HaveCount 1
    }

    It "accumulates hours for the same week" {
        $weeklyHours = @{}
        $date = [DateTime]::ParseExact('2023-11-06', 'yyyy-MM-dd', $null)
        Update-WeeklyHours -Date $date -Hours 4.0 -WeeklyHours ([ref]$weeklyHours)
        Update-WeeklyHours -Date $date.AddDays(1) -Hours 3.0 -WeeklyHours ([ref]$weeklyHours)
        $key = $weeklyHours.Keys | Select-Object -First 1
        $weeklyHours[$key]['Hours'] | Should -Be 7.0
    }
}

Describe "Update-MonthlyHours" {

    It "creates a yyyy-MM key" {
        $monthlyHours = @{}
        $date = [DateTime]::ParseExact('2023-11-06', 'yyyy-MM-dd', $null)
        Update-MonthlyHours -Date $date -Hours 5.0 -MonthlyHours ([ref]$monthlyHours)
        $monthlyHours.ContainsKey('2023-11') | Should -BeTrue
    }

    It "accumulates hours across days in same month" {
        $monthlyHours = @{}
        $d1 = [DateTime]::ParseExact('2023-11-01', 'yyyy-MM-dd', $null)
        $d2 = [DateTime]::ParseExact('2023-11-15', 'yyyy-MM-dd', $null)
        Update-MonthlyHours -Date $d1 -Hours 8.0 -MonthlyHours ([ref]$monthlyHours)
        Update-MonthlyHours -Date $d2 -Hours 6.5 -MonthlyHours ([ref]$monthlyHours)
        $monthlyHours['2023-11'] | Should -Be 14.5
    }

    It "keeps separate keys for different months" {
        $monthlyHours = @{}
        $nov = [DateTime]::ParseExact('2023-11-01', 'yyyy-MM-dd', $null)
        $dec = [DateTime]::ParseExact('2023-12-01', 'yyyy-MM-dd', $null)
        Update-MonthlyHours -Date $nov -Hours 10.0 -MonthlyHours ([ref]$monthlyHours)
        Update-MonthlyHours -Date $dec -Hours 5.0 -MonthlyHours ([ref]$monthlyHours)
        $monthlyHours.Keys | Should -HaveCount 2
    }
}
