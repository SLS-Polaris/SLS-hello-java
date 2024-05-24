#!/bin/bash
echo "*************************************************************************"
echo "Processing Inputs . . ."
ApplicationFile=$1
BuildCommand=$2
BuildParms=$3
coverityUser=$4
coverityPassword=$5
coverityCheckers=$6
coverityURL=$7
projectName=$8
branch=$9

DEBUG=true

echo "Configuring Application . . ."
desc=""
runnerOS="local"
gitSHA="${GITHUB_SHA}"

if [ "$coverityURL" == "" ]; then
  # coverityURL="https://coverity-test.aepsc.com"
  coverityURL="https://poc312.coverity.synopsys.com"
fi

if [ "$coverityCheckers" == "" ]; then
  coverityCheckers="all"
fi

if [ "${GITHUB_SERVER_URL}" != "" ]; then
  desc="${GITHUB_SERVER_URL}/$projectName/actions/runs/${GITHUB_RUN_ID}"
fi

if [ "${RUNNER_OS}" != "" ]; then
  runnerOS="${RUNNER_OS}"
fi

if [ "${GITHUB_WORKSPACE}" == "" ]; then
  projectLocation=$PWD
else
  projectLocation=${GITHUB_WORKSPACE}
fi
pdir="$projectLocation"
dir="$pdir/idir"

if [ "$projectName" == "" ]; then
  projectName=${$GITHUB_REPOSITORY}
fi

if [ "$branch" == "" ]; then
  branch=${GITHUB_REF_NAME}
fi

# ------ SET UP BUILD Commands -------
if [[ $BuildCommand =~ "mvn" ]]; then
  if [ "$BuildParms" == "" ]; then
    BuildParms="install"
  fi 
  if [ "$ApplicationFile" == "" ]; then
    cleanCMD="$BuildCommand clean"
    buildCMD="$BuildCommand $BuildParms"
  else
    cleanCMD="$BuildCommand -f $pdir/$ApplicationFile clean"
    buildCMD="$BuildCommand -f $pdir/$ApplicationFile $BuildParms"
  fi
fi

if [[ $BuildCommand =~ "msbuild" ]]; then
  cleanCMD="$BuildCommand /clean"
  buildCMD="$BuildCommand $pdir\\$ApplicationFile $BuildParms"
fi

if [[ $BuildCommand =~ "dotnet" ]]; then
  cleanCMD="$BuildCommand clean $pdir\\$ApplicationFile"
  if [[ ! $BuildCommand =~ "build" ]]; then
    $BuildCommand="$BuildCommand build"
  fi
  buildCMD="$BuildCommand $pdir\\$ApplicationFile $BuildParms"
fi

# streamName="$projectName($branch)"
streamName=${{ github.event.repository.name }}-${{ github.base_ref }}

# DEBUGGING Commands
if [ "$DEBUG" == "true" ]; then
  echo " ***** DEBUGGING Commands ***** "
  echo "ApplicationFile=$ApplicationFile"
  echo "BuildCommand=$BuildCommand"
  echo "BuildParms=$BuildParms"
  echo "coverityUser=$coverityUser"
  echo "coverityCheckers=$coverityCheckers"
  echo "coverityURL=$coverityURL"
  echo "projectLocation=$projectLocation"
  echo "projectName=$projectName"
  echo "branch=$branch"
  echo "desc=$desc"
  echo "streamName=$streamName"
  echo "cleanCMD=$cleanCMD"
  echo "buildCMD=$buildCMD"
  echo "pdir=$pdir"
  echo "dir=$dir"
  echo " ******************************* "  
fi

# -------- Performs a Coverity Capture (Identify project types in Project) ----------
echo '--------------------------------'
echo '| *** AEP Coverity Capture *** |'
echo '--------------------------------'
#cov-capture --dir idir --source-dir $Project_SRC
if [ "$DEBUG" == "true" ]; then
  echo coverity capture --project-dir "$pdir" --dir "$dir" -o capture.build.clean-command="$cleanCMD" -o capture.build.build-command="$buildCMD"
fi
coverity capture --project-dir "$pdir" --dir "$dir" -o capture.build.clean-command="$cleanCMD" -o capture.build.build-command="$buildCMD"

# -------- Perform a Coverity Analysis for the Whole Project ----------
echo '-------------------------------'
echo '| *** AEP Coverity Analyze *** |'
echo '-------------------------------'
#cov-analyze --dir idir --ticker-mode none --strip-path $github_workspace $Coverity_Checkers
if [ "$DEBUG" == "true" ]; then
  echo coverity analyze --project-dir "$pdir" --dir "$dir" -o analyze.location=local -o analyze.checkers.all=true
fi
coverity analyze --project-dir "$pdir" --dir "$dir" -o analyze.location=local -o analyze.checkers.all=true


# -------- Perform a Coverity Commit to push Results to Coverity Connect Server ----------
echo '-------------------------------'
echo '| *** AEP Coverity Commit *** |'
echo '-------------------------------'
if [ "$DEBUG" == "true" ]; then
  echo cov-commit-defects --user "***" --password "***" --dir idir --ticker-mode none --url $coverityURL --stream "$streamName" --scm git --description "$desc" --target "$runnerOS" --version "$gitSHA"
fi
cov-commit-defects --user $coverityUser --password $coverityPassword --dir "$dir" --ticker-mode none --url $coverityURL --stream "$streamName" --scm git --description "$desc" --target "$runnerOS" --version "$gitSHA"