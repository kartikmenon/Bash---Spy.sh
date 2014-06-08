#!/bin/bash
#
# Description: Given a user specified as input, spy.sh will see if that user is
# online or not on the linux machines in Sudikoff and continue to track that user's
# login and logout activity until spy.sh is killed. If the user is still logged in
# when the spy script is killed, the time between the user's most recent login and
# the time of the script being killed is counted as the user's last session.
#
# Input: Name(s) of people whose information will be found in the /etc/passwd file.
#
# Output: A report consisting of the login and logout times of everybody searched
# for and provides statistics on who spent the most time logged in total and who
# had the longest and shortest individual sessions.
#
# Special considerations: If the user is still logged on while the script is killed
# the user is still online, the last session will be counted in the statistics. If
# the user never logs in the entire time spy.sh is running, no files are outputted.
#
# Pseudocode:
# 1. Set up initializer arrays and variables to hold user info (userArray), name info (nameArray), whether or not the person is online (onArray, holding 0s or 1s to substitute for Booleans), keeping the current session times (sessionArray) and keeping the total online time for each user (totalOnlineTimeArray), which is basically a sum of each individual session. Also some variables for the trivia at the end.
# 2. Loop through each user and initialize all of the arrays. Everyone is counted as offline to begin with, so when spy.sh starts up, even if the user was online before, it counts the login time as the time when the script started. Each array element is tied to each user. So userArray[1]'s information is contained in onArray[1] and nameArray[1] and sessionArray[1], etc.
# 3. Continuously loop through variables. Everyone is offline the first time around, so spy.sh will create temp files for each person that will house their login and logoff times. As the loop goes, if spy.sh notices that you are still logged in from the last time the loop went around, nothing happens.
# 4. The other case is if the user logged out, and I check if they were logged in before, in which case I store their session info and increment the total time they were logged on. I then check to see if that current session compares to the shortest or longest sessions, and update the appropriate trivia variables.
# 5. Then I trap the signal from kill -10, using a method called trappingSignal(). In the trapping method I record the final session and update the trivia variables, along with printing out the nicely formatted spy.log

#


# Give a message if the user doesn't give names
if [ $# -eq 0 ]; then
    printf "Please give me more arguments. I need at least one name to run. \n"
1>&2; exit 1
fi

# This is for the beginning of the spy.sh report. Need the time/date at start of program
runtime=`date +"%T"`
rundate=`date +"%m/%d/%y"`

# Create three arrays, one to store usernames and the other to store login status. See README for more details.
userArray=() # for usernames
nameArray=() # for names
onArray=() # booleans (0 or 1) are they on or not?
sessionArray=() # keep track of session times
totalOnlineTimeArray=() # total login time for each user

# Need variables for the statistics at the end

shortestSession=999999999
longestPerson="not yet"
shortestPerson="not yet"
longestSession=0
maxPerson="not yet"
maxTime=0


i=0
for arg; do

# Get the usernames associated with supplied arguments
    username=`cat /etc/passwd | grep "$arg"`

    if [ $? -ne 0 ]; then
        printf "\"$arg\" is not a valid user. \n"
        break
    fi

    nameArray+=("`cat /etc/passwd | grep "$arg" | cut -d ":" -f5`")
    userArray+=("`cat /etc/passwd | grep "$arg" | cut -d ":" -f1`")
    sessionArray+=0
    totalOnlineTimeArray+=0

    printf "'${nameArray[$i]}', with username '${userArray[$i]}' has been added to the spy list. \n"

# Initially everyone counted as offline and not having logged in.
    onArray+=("1")

    (( i++ ))

done


# This while loop will be the rest of the program. Keep going until kill sent
while true; do

    i=0
# Continuously loop over the users to see if they are logged on.
    for person in "${userArray[@]}"; do

        who | grep -q "$person"
# If they are online, the return code for the above pipe should be 0.
        if [ $? -eq 0 ]; then

# See if they were on before (1 = offline, 0 = online)
            if [ "${onArray[$i]}" == "1" ]; then

# This file will contain info on when the user logs in and out
                if [ ! -w "${person}_t.txt" ]; then
                    touch ${person}_t.txt
                fi

                onArray[$i]="0" # they are now online!

# Time logged in (this is for anytime they log in or out)
                newTime=`date +"%T"`
                newCalc=`date +"%s"`

                printf "Logged in on "$newTime" \n" >> ${person}_t.txt

# User logged in and still logged in. Put this in more for completeness, taking it out makes no difference.
            else
            printf "hi" > /dev/null

            fi


# User logged out
        elif [ $? -ne 0 ];then


# If they were logged in before
            if [ "${onArray[$i]}" == "0" ];then

# Record the logout time
                logoutTime=`date +"%T"`
                logoutCalc=`date +"%s"`
                printf "Logged off on "$logoutTime" \n" >> ${person}_t.txt

# Since they were on before and logged out, this counts as a session. Record the time.
                difference=$(($logoutCalc-$newCalc))

                sessionArray[$i]=$(($difference / 60)) # minutes

                totalOnlineTimeArray[$i]=$((${totalOnlineTimeArray[$i]}+${sessionArray[$i]}))


# If the session is shorter than the previous
                if (( ${sessionArray[$i]} < $shortestSession )); then
                    shortestSession=${sessionArray[$i]}
                    shortestPerson=${userArray[$i]}
                fi

# If longer.
                if (( ${sessionArray[$i]} > $longestSession )); then
                    longestSession=${sessionArray[$i]}
                    longestPerson=${userArray[$i]}
                fi

# Look at max users.
                if (( ${totalOnlineTimeArray[$i]} > $maxTime )); then
                    maxTime=${totalOnlineTimeArray[$i]}
                    maxPerson=${userArray[$i]}
                fi

            fi

# Set user offline
            onArray[$i]="1"

        fi

    (( i++ ))

# End for loop
    done


# Method to be called when trapping
trappingSignal() {

# Start printing out spy report
    printf "Spy Report \n" > spy.log
    printf "Started at $runtime on $rundate " >> spy.log
    printf "and terminated at $(date +"%T"). \n \n" >> spy.log

    printf "The people spied on were: " >> spy.log


    for name in "${nameArray[@]}"; do
        printf "$name " >> spy.log
    done

    printf "\n \n" >> spy.log
    k=0
    for person in "${userArray[@]}"; do
        if [ -e ${person}_t.txt ]; then

# When spy is killed, everyone counted as logged out.
            printf "Program terminated on `date +"%T"` \n" >> ${person}_t.txt


# Need to account for the last session.

# If they were still logged in (i.e., online status = 0) when script killed:
            if [ "${onArray[$k]}" == "0" ]; then
                killTime=`date +"%s"`
                killDifference=$(($killTime-$newCalc))

                sessionArray[$k]=$(($killDifference / 60)) # minutes

# Add the last session to the total time.
                totalOnlineTimeArray[$k]=$((${totalOnlineTimeArray[$k]}+${sessionArray[$k]}))

                if (( ${sessionArray[$k]} < $shortestSession )); then
                    shortestSession=${sessionArray[$k]}
                    shortestPerson=${userArray[$k]}
                fi

# If longer.
                if (( ${sessionArray[$k]} > $longestSession )); then
                    longestSession=${sessionArray[$k]}
                    longestPerson=${userArray[$k]}
                fi

# Look at max users.
                if (( ${totalOnlineTimeArray[$k]} > $maxTime )); then
                    maxTime=${totalOnlineTimeArray[$k]}
                    maxPerson=${userArray[$k]}
                fi

            fi



# The number of times someone logged in can be found from temp file
            loginCount=`cat ${person}_t.txt | grep -o "Logged in" | wc -l`

            printf "$person logged on $loginCount times for a total of ${totalOnlineTimeArray[$k]} minutes.  Here is the breakdown: \n" >> spy.log

# Put in the individual log in/off times into spy report.
            cat ${person}_t.txt >> spy.log

            printf "\n" >> spy.log

# If there's no temp file for the person, then they were never online.
        else
            printf "\n $person was not online at any time spy.sh was running. \n" >> spy.log
        fi
        (( k++ ))

    done

    printf "\n" >> spy.log

    printf "$maxPerson spent the most time online today, $maxTime minutes total. \n" >> spy.log
    printf "$shortestPerson was on for the shortest session of $shortestSession minutes. \n" >> spy.log
    printf "$longestPerson was on for the longest session of $longestSession minutes. \n" >> spy.log

    exit 0

}


# Trap the signal and call function to get spy report/stats.
    trap trappingSignal 10


    sleep 60

done



