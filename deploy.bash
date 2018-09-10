#!/bin/bash

#######################################################################
#
# This script helps to pull source code from a repo and deploy
# docker application into a host having password less authentication
#
#######################################################################


TMP_DIR="/tmp/git-tmp/"
INFO_LOG="log.info"

# Remove temporary repo DIR
rm -rf $TMP_DIR

# A help message to display if options are not provided properly
help='''
  USAGE:\n
    -k   </path/to/aws key file on local machine>\n
    -d   </path/to/remote destination dir>\n
    -h   <remote hostname or IP>\n
    -u   <username of remote host>\n
    -g   </path/to/git repo to clone>\n
    -b   <git branch name>\n
    -s   <git sub-module (y/n)>\n
'''

# check if the optiosn provided count is zero
if [ $# -eq 0 ]; then
    echo -e "No options provided\n"
    echo -e "$help";
    exit 2
fi

# case based options and setting them to variables to do something later
while getopts ":k:d:h:u:g:b:s:" opt; do
  let optnum++
  case $opt in
    k)
      key=$OPTARG
      ;;
    d)
      dest=$OPTARG
      ;;
    h)
      host=$OPTARG
      ;;
    u)
      user=$OPTARG
      ;;
    g)
      gitc=$OPTARG
      ;;
    s)
      sub=$OPTARG
      ;;
    b)
      branch=$OPTARG
      ;;
    \?)
      echo -e "Invalid option: -$OPTARG\n"
      echo -e "$help"
      exit 1
      ;;
    :)
      echo -e "Option -$OPTARG requires an argument.\n"
      echo -e "$help"
      exit 1
      ;;
  esac
done

# check if all the required options are given or not
if [[ $optnum -lt 7 ]];then
  echo -e "All the options must be specified correctly";
  echo -e "$help";
  exit 1
fi

# Print timestamp to .info file
echo -e "\n##### `date` #####\n"
echo -e "\n##### `date` #####\n" >> $INFO_LOG 2>&1

# displaying options provided and thei values
echo "
      Key : $key
      Destination : $dest
      Host : $host
      Username : $user
      Repo : $gitc
      Branch : $branch
      Sub Module : $sub
     "

echo "
      Key : $key
      Destination : $dest
      Host : $host
      Username : $user
      Repo : $gitc
      Branch : $branch
      Sub Module : $sub
     " >> $INFO_LOG 2>&1

# remote script that executes and deploy code
function remoteExec()
{
    function Remote_Script()
    {
        cd $1
        echo -e "Bringing down Docker ... "
        docker-compose down -v
        echo -e "Bringing up Docker ... "
        docker-compose up --build -d
    }

    echo "Remote execution starting, Deploying into Docker ... "
    echo "Remote execution starting, Deploying into Docker ... " >> $INFO_LOG 2>&1
    ssh -q -i "$1" "$2"@"$3" "$(declare -f Remote_Script);Remote_Script $4 $5" >> $INFO_LOG 2>&1
    
    if [ $? -eq 0 ];then 
      echo -e "Bringing up Docker successfully completed ... "
      echo -e "Bringing up Docker successfully completed ... " >> $INFO_LOG 2>&1
    fi
}

mkdir -p $TMP_DIR

echo -e "Cloning git repo ... "
echo -e "Cloning git repo ... " >> $INFO_LOG 2>&1

if [ "$sub" == "y" ];then
  git clone -b "$branch" --recurse-submodules --single-branch "$gitc" "$TMP_DIR" >> $INFO_LOG 2>&1
else
  git clone -b "$branch" --single-branch "$gitc" "$TMP_DIR" >> $INFO_LOG 2>&1
fi

if [ $? -ne 0 ];then
  echo -e "Something went wrong while cloning repo, please see $INFO_LOG file for more details\n";
  echo -e "Something went wrong while cloning repo, please see $INFO_LOG file for more details\n"; >> $INFO_LOG 2>&1
  rm -rf $TMP_DIR
  exit 1
fi
echo -e "Cloning git repo successfully completed ... "
echo -e "Cloning git repo successfully completed ... " >> $INFO_LOG 2>&1

echo -e "Copying files to remote host"
echo -e "Copying files to remote host" >> $INFO_LOG

ssh -q -i "$key" "$user"@"$host" "mkdir -p $dest";
scp -i "$key" -r "$TMP_DIR"* "$user"@"$host":"$dest" >> $INFO_LOG 2>&1

if [ $? -ne 0 ];then
  echo -e "Something went wrong while copying files to remote host, please see $INFO_LOG file for more details\n";
  echo -e "Something went wrong while copying files to remote host, please see $INFO_LOG file for more details\n"; >> $INFO_LOG 2>&1
  rm -rf $TMP_DIR
  exit 1
fi
echo -e "Copying files to remote host successfully completed"
echo -e "Copying files to remote host successfully completed" >> $INFO_LOG 2>&1

echo -e "Deploying code ... "
echo -e "Deploying code ... " >> $INFO_LOG 2>&1
remoteExec "$key" "$user" "$host" "$dest" "$branch"

if [ $? -ne 0 ];then
  echo -e "Something went wrong while deploying code to remote host\n";
  echo -e "Something went wrong while deploying code to remote host\n"; >> $INFO_LOG 2>&1
  rm -rf $TMP_DIR
  exit 1
fi

# Remove temporary clone dir
rm -rf $TMP_DIR