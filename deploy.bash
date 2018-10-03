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
    -k   </path/to/aws key file on local machine or pass 'n' to provide no key>\n
    -d   </path/to/remote destination dir>\n
    -h   <remote hostname or IP>\n
    -u   <username of remote host>\n
    -g   </path/to/git repo to clone>\n
    -b   <git branch name>\n
    -s   <git sub-module (y/n)>\n
    --pre-copy=   <optional pre copy shell script path with commands in it, 
                  should be in .sh or .bash format>\n
'''

# check if the options provided count is zero
if [ $# -eq 0 ]; then
    echo -e "No options provided\n"
    echo -e "$help";
    exit 2
fi

# case based options and setting them to variables to do something later
while [[ $# -gt 0 ]]; do
    opt="$1"
  let optnum++
  case "$opt" in
    -k)
      shift
      key="$1"
      ;;
    -d)
      shift
      dest="$1"
      ;;
    -h)
      shift
      host="$1"
      ;;
    -u)
      shift
      user="$1"
      ;;
    -g)
      shift
      gitc="$1"
      ;;
    -s)
      shift
      sub="$1"
      ;;
    -b)
      shift
      branch="$1"
      ;;
    --pre-copy=*)
      precopy=${opt#*=}
      if [ -z $precopy ];then
        true
      fi
      ;;
    *)
      echo -e "Invalid option: -$opt\n"
      echo -e "$help"
      exit 1
      ;;
  esac
  shift
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
      Pre-Copy : $precopy
     "

echo "
      Key : $key
      Destination : $dest
      Host : $host
      Username : $user
      Repo : $gitc
      Branch : $branch
      Sub Module : $sub
      Pre-Copy : $precopy
     " >> $INFO_LOG 2>&1

# remote script that executes and deploy code
function remoteExec()
{
    function Remote_Script()
    {
        cd $1
        echo -e "Deploying Application to Docker ... "
        docker-compose up --build -d
    }

    echo "Remote execution starting, Deploying into Docker ... "
    echo "Remote execution starting, Deploying into Docker ... " >> $INFO_LOG 2>&1
    
    if [ "$1" == 'n' ];then
      ssh -q "$2"@"$3" "$(declare -f Remote_Script);Remote_Script $4" >> $INFO_LOG 2>&1
    else 
      ssh -q -i "$1" "$2"@"$3" "$(declare -f Remote_Script);Remote_Script $4" >> $INFO_LOG 2>&1
    fi

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

if [ $key == 'n' ];then
  $precopy
  ssh -q "$user"@"$host" "mkdir -p $dest";
  scp -r "$TMP_DIR"* "$user"@"$host":"$dest" >> $INFO_LOG 2>&1
else
  $precopy
  ssh -q -i "$key" "$user"@"$host" "mkdir -p $dest";
  scp -i "$key" -r "$TMP_DIR"* "$user"@"$host":"$dest" >> $INFO_LOG 2>&1
fi


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