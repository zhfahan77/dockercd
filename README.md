# GIT + Docker CD

Script to pull application repo from Git and copy it to remote host and run it as a docker.

N.B. Need the repo to be dockerized.

USAGE:

    -k   </path/to/aws key file on local machine or pass n to provide no key>

    -d   </path/to/remote destination dir>

    -h   <remote hostname or IP>

    -u   <username of remote host>

    -g   </path/to/git repo to clone>

    -b   <git branch name>

    -s   <git sub-module (y/n)>
