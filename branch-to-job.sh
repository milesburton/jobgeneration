!#/usr/bin/bash
#USER=YOUR_ADMIN_USER
#TOKEN=YOUR_TOKEN
GIT_REPOSITORY_PATH=`git rev-parse --show-toplevel` # Get the repository path
GIT_REPOSITORY_NAME=`basename $GIT_REPOSITORY_PATH` # Extract the repository name

# Get all branches from current repository
git branch -r \ # List all branches
| grep -v "origin/HEAD" \ # Remove HEAD (which *should* point at master)
| sed 's/^[ \t]*//;s/[ \t]*$//' \ # Remove white space
| sed 's/^origin\///' \ # Remove origin prefix
| grep -v '^$' > branches # Remove empty lines and create a temporary file. Each line represents a branch

# For each branch
while read -r line # Loop through all the lines in the branches file
do
    BRANCH=$line
    JOB_NAME=$GIT_REPOSITORY_NAME-$BRANCH # Create a job name for this branch
    
    # Curl the Job URL to see if it exists
    SHOULD_BE_404_IF_NEW_JOB=`curl -u $USER:$TOKEN -o /dev/null --head --silent --write-out '%{http_code}' ${JENKINS_URL}view/$JOB_NAME/job/api/JSON`

    # Only create a job if it doesn't already exist. No point doing it twice
    if [ $SHOULD_BE_404_IF_NEW_JOB = "404" ]; then

        # Get the job template type from the branch
        JOB_GENERATOR_NAME=`git show origin/$BRANCH:jenkins.jobtype.conf`
        # Get the job parameters from the branch
        JOB_PARAMETERS=`git show origin/$BRANCH:jenkins.parameters.json`
        
        # Create a paramter for this branch to be used by the job generator
        JOB_BRANCH_PARAMETERS="{\"parameter\": [{\"name\":\"branch\", \"value\":\"$BRANCH\"}]}"

        # To save agro, create two files with the above
        echo $JOB_PARAMETERS > left.json
        echo $JOB_BRANCH_PARAMETERS > right.json

        # Use JQ (apt-get install jq if you don't have it) to merge the user supplied parameters (from git) with the branch name needed by the generator job
        JOB_MERGED_PARAMETERS=`jq -s '.[0].parameter + .[1].parameter | {parameter: .}' left.json right.json`

        # Post to jenkins to trigger the generation job
        curl -X POST ${JENKINS_URL}job/$JOB_GENERATOR_NAME/build \
        -u $USER:$TOKEN \
        --data-urlencode json="$JOB_MERGED_PARAMETERS"

    fi
    
  
done < branches

