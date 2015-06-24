!#/usr/bin/bash
#USER=YOUR_ADMIN_USER
#TOKEN=YOUR_TOKEN
GIT_REPOSITORY_PATH=`git rev-parse --show-toplevel`
GIT_REPOSITORY_NAME=`basename $GIT_REPOSITORY_PATH`

# Get all branches from current repository
git branch -r \
| grep -v "origin/HEAD" \
| sed 's/^[ \t]*//;s/[ \t]*$//' \
| sed 's/^origin\///' \
| grep -v '^$' > branches

# For each branch
while read -r line
do
    BRANCH=$line
    JOB_NAME=$GIT_REPOSITORY_NAME-$BRANCH
    echo "Checking if $BRANCH job exists"

    SHOULD_BE_404_IF_NEW_JOB=`curl -u $USER:$TOKEN -o /dev/null --head --silent --write-out '%{http_code}' ${JENKINS_URL}view/$JOB_NAME/job/api/JSON`

    if [ $SHOULD_BE_404_IF_NEW_JOB = "404" ]; then
        echo "Creating job"

        JOB_GENERATOR_NAME=`git show origin/$BRANCH:jenkins.jobtype.conf`
        JOB_PARAMETERS=`git show origin/$BRANCH:jenkins.parameters.json`
        JOB_BRANCH_PARAMETERS="{\"parameter\": [{\"name\":\"branch\", \"value\":\"$BRANCH\"}]}"

        echo $JOB_PARAMETERS > left.json
        echo $JOB_BRANCH_PARAMETERS > right.json

        JOB_MERGED_PARAMETERS=`jq -s '.[0].parameter + .[1].parameter | {parameter: .}' left.json right.json`

        curl -X POST ${JENKINS_URL}job/$JOB_GENERATOR_NAME/build \
        -u $USER:$TOKEN \
        --data-urlencode json="$JOB_MERGED_PARAMETERS"

    fi
    
  
done < branches

