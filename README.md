Feature branching has been a exceptionally disruptive change over the last ten years within engineering teams. It has enabled developers to work on disparate stories, all while maintaining the safety of source control systems like Git and Mercurial. 

Despite all the power of approaches like Gitflow I’ve never really seen it integrated particularly well into continuous integration tools like Jenkins. Testing on a local machine is great, but it’s still rather superficial – you lack the reassurance of a sandboxed, ideally native environment (particularly true in finance). Even more so, the parallelism & speed provided by a dedicated grid of build slaves.

What would be ideal is a continuous integration system which is aware of your feature branches and can automatically create jobs directly from a template and begin monitoring your commits. This is how I believe the process should work:

<Diagram>

There are a couple of tools out there which allow you to automate such a process, for example
•	Job Generator Plugin –https://wiki.jenkins-ci.org/display/JENKINS/Job+Generator+Plugin
•	Jenkins Template Plugin - http://blog.cloudbees.com/2012/02/using-jenkins-templates-plugin-to.html

Which combine neatly with the REST API - https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API

At the most basic we need to perform two tasks:
* Job Creation
* Job Removal (merged or deleted branches)

Avoiding as many complexities as possible, let’s look how you could setup such a system.

## Prerequisites 
* Jenkins running on Linux
* “jq” installed on your PATH (a command line JSON manipulator)
* A Git repository (you can drop in alternatives, just modify the commands as needed)
* A secured account with Job CRUD entitlements – make sure you jot down your API Token
* Job Generator Plugin for Jenkins

Implementing job generation needs two components. A Git Branch ‘sniffer’, and one or more Job Templates.

# Job Template 

Let’s start with your Job Template - don’t forget to install the job generator plugin! Create a brand new job with an appropriate name and select Job-Generator – this will be your template.

<Screenshot 1>

At a minimum you’ll need to specify a parameterized build with the Branch Name as a Generator Parameter. I’d suggest you use BRANCH_NAME as the parameter key. As you create more intricate jobs you’ll add more parameters here which can be loaded from your Git repository.

<Screenshot 2>

You’ll use this BRANCH_NAME parameter to drive the name of the generated job and which branch to checkout and watch. Go ahead and enter your git repository details and an appropriate job trigger

<Screenshot 3>

<Screenshot 4>

 It’s generally wise to use a job name in a particular form so you can identify which jobs were generated dynamically. What is also particularly helpful is keeping all the dynamically generated jobs within a Jenkins View.

<Screenshot 5>

Let’s test the new generator by running it as a normal job.

<Screenshot 6>

With a bit of luck a brand new job will have been created. Take a look and check everything worked as expected. 

<Screenshot 7>

# Git Branch Sniffer

This is where it gets a touch more complicated. To keep this post as simple as possible, we’ll only look for branches on a specific repository. As you build up your tooling you’ll find it isn’t particularly difficult to look at multiple repositories. 

<Screenshot 1>

Create a brand new, ‘Free-Style’ project with an appropriate name and configure your Git Repository as you did before. You won’t need any parameters. You’ll need to configure the job to either poll or use Git hooks to listen for branch changes – make sure you select “all branches” in the configuration.

<Screenshot 2>

The final step is to add an ‘Execute shell’. Below is the shell script you’ll need to use. For the moment (and this is less than ideal) your “sysadmin” user and token will need to be entered in plain text as shown below. I’d recommend making this job only visible to your sysadmin user. You could also use a private key, but that is out of the scope of this blog.

<Screenshot 3>

You’ll notice the script declares two variables for your credentials and then executes a bash script which performs the interactions to create a new job.

This script performs the following tasks:
1	Get repository name which you specified in the branch sniffer configuration
2	List all the branches for that repository
3	For each branch, check if it does not already exist – if it does, exit
a.	Get the job template name from  the new branch (this allows you to change the job template on the fly)
b.	Get the job parameters from the new branch  (see above)
c.	Create a new build job based on the job template, using the job parameters for this branch

I chose to write this as a bash script to avoid any dependencies, however it may be worth while using Groovy or indeed, creating a Jenkins plugin to perform this task using native calls. Also note, the script does not perform error handling (yet).

Once this is saved and executed it should pick up and generate your new jobs! 

# Closing thoughts


## House keeping
As with almost all devops tasks, it’s worth automating a few other housekeeping tasks, for example:
* 	Expiry of old feature branches – Avoid redundant branches, I’d suggest alerting the owners if a no new commits have been performed in X weeks
* Disabling of failed jobs – No point retriggering dead jobs. And a Pull request should pass unless a build is successful. Great way of reducing resource utilisation
* 	Purging of workspace files after a specific period – Don’t waste space leaving files unused
* Monitoring your Jenkins utilisation and expansion requirements -  https://wiki.jenkins-ci.org/display/JENKINS/Global+Build+Stats+Plugin


## Alternative approaches
* Jenkins CLI can manipulate the XML which ultimately powers the configuration of the build system. If you need more power, this can work quite well remotely. Unfortunately you also inherit the overhead of maintaing those XML files. Each new version of Jenkins (and the installed plugins) may require a new XML schema breaking your compatibility.
