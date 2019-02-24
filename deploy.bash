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
    --post-copy=   <optional post copy shell script path with commands in it, 
                  should be in .sh or .bash format>\n
    --rollback=   <optional rollback param, accepts only git head hash of a branch>\n

    --start=      <optional custom command to to start application>\n
'''

# Log Function
function log() {
  echo -e $1
  echo -e $1 >> $INFO_LOG 2>&1
}

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
    --post-copy=*)
      postcopy=${opt#*=}
      if [ -z $postcopy ];then
        true
      fi
      ;;
    --rollback=*)
      rollback_head=${opt#*=}
      if [ -z $rollback_head ];then
        true
      fi
      ;;
    --start=*)
      customCommand=${opt#*=}
      if [ -z "$customCommand" ];then
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
log "\n##### `date` #####\n"

# displaying options provided and thei values
log "Key : $key \n
     Destination : $dest \n
     Host : $host \n
     Username : $user \n
     Repo : $gitc \n
     Branch : $branch \n
     Sub Module : $sub \n
     Pre-Copy : $precopy \n
     Post-Copy : $postcopy \n
     Rollback : $rollback_head \n
     Custom Command: $customCommand \n"

# remote script that executes and deploy code
function remoteExec()
{
    function Remote_Script()
    {
        cd $1
        echo -e "Deploying Application to Docker ... "
        docker-compose up --build -d
    }

    log "Remote execution starting, Deploying into Docker ... "
    
    if [ "$1" == 'n' ];then
      Remote_Script "$4" >> $INFO_LOG 2>&1
    else
      ssh -q -i "$1" "$2"@"$3" "$(declare -f Remote_Script);Remote_Script $4" >> $INFO_LOG 2>&1
    fi
}

# remote script that executes custom command and deploy code
function remoteExecWithCustomCommand()
{
    function Remote_Script()
    {
        cd $1
        echo -e "Deploying Application to Docker ... "
        shift
        $@
    }

    log "Remote execution starting, Deploying into Docker ... "

    if [ "$1" == 'n' ];then
      Remote_Script "$4" "$5" >> $INFO_LOG 2>&1
    else
      ssh -q -i "$1" "$2"@"$3" "$(declare -f Remote_Script);Remote_Script $4 $5" >> $INFO_LOG 2>&1
    fi
}

mkdir -p $TMP_DIR

log "Cloning git repo ... "

if [ "$sub" == "y" ];then
  git clone -b "$branch" --recurse-submodules --single-branch "$gitc" "$TMP_DIR" >> $INFO_LOG 2>&1
else
  git clone -b "$branch" --single-branch "$gitc" "$TMP_DIR" >> $INFO_LOG 2>&1
fi

if [ $? -ne 0 ];then
  log "Something went wrong while cloning repo, please see $INFO_LOG file for more details\n";
  rm -rf $TMP_DIR
  exit 1
fi

log "Cloning git repo successfully completed ... "

# Rolling Back
if [ -z $rollback_head ];then
  true
else
  cd "$TMP_DIR"
  git checkout "$rollback_head" > /dev/null 2>&1
  log "Rolling Back, checking out git head $rollback_head\n"
fi

log "Copying files to remote host"

if [ $key == 'n' ];then
  $precopy
  mkdir -p "$dest";
  cp -R "$TMP_DIR"* "$dest" >> $INFO_LOG 2>&1
else
  $precopy
  ssh -q -i "$key" "$user"@"$host" "mkdir -p $dest";
  scp -i "$key" -r "$TMP_DIR"* "$user"@"$host":"$dest" >> $INFO_LOG 2>&1
fi

if [ $? -ne 0 ];then
  log "Something went wrong while copying files to remote host, please see $INFO_LOG file for more details\n"
  rm -rf $TMP_DIR
  exit 1
fi

log "Copying files to remote host successfully completed"

if [ $key == 'n' ];then
  log "Running Post Copy Script"
  $postcopy
elif [ -z $postcopy ];then
  true
else
  log "Running Post Copy Script"
  ssh -q -i "$key" "$user"@"$host" 'bash -s' < $postcopy
fi

log "Deploying code ... "

# Custom Command
if [ -z "$customCommand" ];then
  remoteExec "$key" "$user" "$host" "$dest"
else
  remoteExecWithCustomCommand "$key" "$user" "$host" "$dest" "$customCommand"
fi

if [ $? -ne 0 ];then
  log "Something went wrong while deploying code to remote host\n"
  rm -rf $TMP_DIR
  exit 1
else
  log "Bringing up Docker successfully completed ... "
fi

# Remove temporary clone dir
rm -rf $TMP_DIR