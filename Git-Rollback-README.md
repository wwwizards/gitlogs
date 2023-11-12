# GIT ROLLBACK PROCEDURES
---

If you ever made a mistake in your code and want/need or have no other choice but to go back to a previous commit, THIS can guide you through the rollback process using Git. **Here's all you really need to do** (as long as you commit every few minutes - you will never loose a ton of work):

1. **Check the Commit History**: First, let's check the commit history to find the commit just before the changes were made. Open your terminal or command prompt in the directory where your PowerShell script is located and run:

   ```bash
   git log --oneline
   ```

   This command will show you a list of recent commits with their short commit hashes and messages.

2. **Identify the Commit**: Look for the commit message that indicates the state you want to revert to (i.e., before the changes that introduced the nulls). Note the commit hash of that particular commit.

3. **Revert to the Desired Commit**: To revert your script to the state of that commit, use the following command, replacing `commit_hash` with the actual hash you noted:

   ```bash
   git checkout commit_hash -- Report-HoursWorked-v03.ps1
   ```

   This command will revert the `Report-HoursWorked-v03.ps1` file to the state it was in at the specified commit, without altering your current branch or other files.

4. **Verify the Changes**: Open the `Report-HoursWorked-v03.ps1` file to make sure it has reverted to the desired state.

5. **Commit the Reversion (Optional)**: If you're satisfied with the reversion and want to make it part of your Git history, you can commit this change:

   ```bash
   git add Report-HoursWorked-v03.ps1
   git commit -m "Reverted Report-HoursWorked-v03.ps1 to previous state before null issue"
   ```

This process will only affect the `Report-HoursWorked-v03.ps1` file and leave your other files and Git history untouched. Once you have rolled back, we can work on adjusting the DateTime parsing to include the correct time.