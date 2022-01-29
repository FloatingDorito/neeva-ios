#!/bin/sh

SCRIPTS_DIR=$(dirname $0)

. $SCRIPTS_DIR/git-util.sh
. $SCRIPTS_DIR/version-util.sh

echo "Make sure Xcode does not have the project open."
echo "Press ENTER to continue. Ctrl+C to cancel."
read

# 1- Make sure the tree is clean
i=0
while true
do 
  # retry 3 times before giving up
  if has_uncommitted_files; then
    if [ $i -eq 3 ]; then
      echo "Retried 3 times. You still have uncommitted files. Please commit or stash, and then re-run prepare next version script."
      exit 1
    else
      echo "****************************************"
      git status
      echo "****************************************"
      echo "You have uncommitted files. Please review changes, commit or stash, Press ENTER to retry. Ctrl+C to cancel."
      read
    fi
  else
    break
  fi
  ((i=i+1))
done

# 2- Run update-version.sh
$SCRIPTS_DIR/update-version.sh

# check if it's on a valid branch
if ! is_branch_of_release && ! is_branch_of_main; then
  echo "You are not on main or release branch. Are you sure you want to continue? Press ENTER to proceed. Ctrl+C to cancel."
  read
fi

# 3- Get version and create branch accordingly or push directly onto release branch

CURRENT_PROJECT_VERSION=$(get_current_project_version)

BRANCH_NAME="$(git_user_name)/prepare-for-build-$CURRENT_PROJECT_VERSION"
REMOTE_NAME="$(get_remote_branch)"

if is_branch_of_release; then
  read -r -p "You are on release branch, do you want to push changes directly onto branch? [Y/n] " response
  if [[ "$response" =~ ^([nN][oO]?)$ ]]
  then
    continue
  else
    git diff
    git commit -a -m "Preparing for build $CURRENT_PROJECT_VERSION"
    echo "Push changes? Press ENTER to continue. Ctrl+C to cancel."
    read
    git push origin $REMOTE_NAME
    exit 1
  fi
fi

echo "Proposing to create branch:"
echo "  name = $BRANCH_NAME"
echo "  from = $REMOTE_NAME"
echo "Create branch? Press ENTER to continue. Ctrl+C to cancel."
read

git checkout -b $BRANCH_NAME $REMOTE_NAME
git diff
git commit -a -m "Preparing for build $CURRENT_PROJECT_VERSION"

# 4- Upload branch for review

echo "Push branch? Press ENTER to continue. Ctrl+C to cancel."
read

git push origin $BRANCH_NAME
