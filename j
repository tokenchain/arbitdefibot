#!/usr/bin/env bash
NVM_DIR=~/.nvm
. ~/.nvm/nvm.sh
boolean_result_false=false
boolean_result_true=true


help() {
  local usage="Explorer builder autoscript -h\n
	 Please try select any of these cmd - testnet,dx1\n

	 Example\n

	 testnet: sh build.sh testnet\n
	 production: sh build.sh dx1\n

	 skip upload: sh build.sh testnet -test\n
	 skip upload: sh build.sh dx1  -test\n
	 try to help it out
	 "
  echo $usage
}
# Accepts a version string and prints it incremented by one.
# Usage: increment_version <version> [<position>] [<leftmost>]
increment_version() {
  declare -a part=(${1//\./ })
  declare new
  declare -i carry=1

  for ((CNTR = ${#part[@]} - 1; CNTR >= 0; CNTR -= 1)); do
    len=${#part[CNTR]}
    new=$((part[CNTR] + carry))
    [ ${#new} -gt $len ] && carry=1 || carry=0
    [ $CNTR -gt 0 ] && part[CNTR]=${new: -len} || part[CNTR]=${new}
  done
  new="${part[*]}"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${new// /.}"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "${new// /.}"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "not correct system - cygwin detected"
    exit
  fi
}
abort_program() {
  cd $BUILD_DIR
  rm -f $FILE
  exit
}

pbuild(){
  cnpm run lintTs
  #tsc -p .
  cnpm run build
}

dev(){
  cnpm run lintTs
  #tsc -p .
  cnpm run dev
}

deploy_balincer(){
  rm -rf dist
  rm -rf $DIST_DIR
  if [[ ! -f dist ]]; then
    mkdir -p dist
  fi
  pbuild
}

#1: the full path
#2: the target location in the remote server
upload_file() {
  local file_size_kb=$(du -k "$1" | cut -f1)

  if [[ $file_size_kb -eq 0 ]]; then
    echo "⛔️ file is zero bytes..."
    abort_program
  fi

  scp $1 root@$LOCAL:$2

  if [ $? -eq 0 ]; then
    echo "✅ ==== upload successfully"
  # else
  #echo "⛔️ Error from uploading... $1"
  # abort_program
  fi

}
remotecmd() {
  local remote_cmd=$2
  ssh -t root@$LOCAL "cd $TARGET_LOC; bash; $remote_cmd"
}

directcmd() {
  ssh -t root@$LOCAL "cd $TARGET_LOC; ./build.sh"
}

mod_setting() {
  param_hk="$1 = \"$2\""
  #echo "$param_hk"
  cat $EXPLORER_SETTINGS | jq "$param_hk" -c $EXPLORER_SETTINGS | sponge $EXPLORER_SETTINGS
}
mod_package_json() {
    local NODEPFILE=$3
    param_chan=$(echo "$1 = \"$2\"")
    echo "$param_chan"
    cat $NODEPFILE | jq "$param_chan" $NODEPFILE | sponge $NODEPFILE
}
env_segment() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "mainnet"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    echo "testlocal"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "testlocal"
    # POSIX compatibility layer and Linux environment emulation for Windows
  elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows
    echo "testlocal"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # ...
    echo "testlocal"
  fi
}

linuxtools() {
  #https://snapcraft.io/install/solc/centos
  if ! command -v rsync &>/dev/null; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    echo "rsync could not be found"
    sudo yum install rsync
  fi
}
checkssh(){
  # Script for checking if SSH port is open
  # Only checks that port is open. Not that actually SSH connection can occur
  local counter=0
  local result="ssh disabled"
  local remote=$LOCAL

  while [ $counter -lt 20 ]; do
    echo "check ssh port connection for $remote"
    telnet_output=`echo quit | telnet $remote 22 2>/dev/null | grep Connected`
    case "$telnet_output" in
      *Connected*)
        let counter=100
        result="ssh enabled"
        ;;
    esac
    let counter=counter+1
    echo "sleep for 5 seconds"
    sleep 5
  done

  echo "$result on $remote"

  if [[ "$result" =~ "enabled" ]]
  then
    exit 0
  fi
}
mactools() {
  if ! command -v rsync &>/dev/null; then
    echo "rsync could not be found"
    brew install rsync
  fi
  if ! command -v cnpm &>/dev/null; then
    echo "cnpm could not be found"
    npm i -g cnpm
  fi
  if ! command -v vercel &>/dev/null; then
    echo "vercel could not be found"
    cnpm i -g vercel
  fi
  #NVM_VERSION=$(echo "$(node -v)" | grep -o -E '[0-9]{2}.')
  local NVM_VERSION=$(echo "$(node -v)" | cut -d. -f1)
  echo "==> 🈯️ all modules needed are completed."
  if [[ ${NVM_VERSION} == "v12" ]]; then
    echo "node version is on the right version : v12"
  else
    echo "please use the below command to switch to the right version of node"
    echo "nvm use 12"
    exit
  fi


  #local test_port=$(nc $LOCAL 22 &> /dev/null; echo $?)
}

deploy_web_to_vercel(){
  rm -rf dist
  rm -rf $DIST_DIR
  if [[ ! -f dist ]]; then
    mkdir -p dist
  fi
  cnpm run build
  #monoploy game
  #cd dist
  #shopt -s extglob
  #rm -v -rf dist/!(_nuxt|.nojekyll|tmoney.ico|monoploy|mmonoploy|monomaker|monoprogram|monoploy|index.html|index_monoploy)
  if [[ ! -f $DIST_DIR ]]; then
    mkdir -p $DIST_DIR
  fi
  mv dist/* $DIST_DIR
  #rm {$DIRSET}_nuxt/stats.json

  cd $DIST_DIR

  echo ".vercel" >> .gitgnore

  if [[ ! -f .vercel ]]; then
      mkdir -p .vercel
  fi
  declare organizationID="$1"
  declare projectID="$2"
  cd .vercel
cat <<EOF >project.json
  {"orgId":"${organizationID}","projectId":"${projectID}"}
EOF
  cd $DIST_DIR

  vercel --prod
}

translation_py(){
  # declare pytranslate="$HOME/Documents/b95/fastroundscam/controller/translate.py"
  declare localization="$PWD/src/i18n/lang"
  local _c=$(
    cat <<EOF

# !/usr/bin/env python
# coding: utf-8
import os

from googlesheettranslate.main import GoogleTranslationSheet


#builder = GoogleTranslationSheet().EnabledProxy().builderOutputTarget("${localization}").builderMeta("${GOOGLETRANS}")
builder = GoogleTranslationSheet().builderOutputTarget("${localization}").builderFromCSV("${TRANSLATION_F}")
builder.GetReader().overrideFileFormat("_{}.json", True)
builder.run( "CN")
builder.run( "EN")
builder.run( "ZH")
builder.run( "JP")
builder.run( "TH")
builder.run( "IN")
builder.run( "KR")
builder.run( "RU")
builder.run( "AR")
builder.run( "DE")
builder.run( "ES")
builder.run( "FR")
builder.run( "IT")

EOF
  )
  python3 -c "$_c"
}



# how to use cp
# https://riptutorial.com/bash/topic/4030/copying--cp-

ensureTargetFolder(){
  TARGET_STATIC="$BUILD_DIR/src/static"
  if [[ ! -f $TARGET_STATIC ]]; then
    mkdir -p $TARGET_STATIC
    chmod u+w $TARGET_STATIC
  fi
}

ensureTargetSubFolder(){
  TARGET_STATIC="$BUILD_DIR/src/static"
  local sub_folder=$1
  if [[ ! -f "$TARGET_STATIC/$sub_folder" ]]; then
    mkdir -p "$TARGET_STATIC/$sub_folder"
    chmod u+w "$TARGET_STATIC/$sub_folder"
  fi
}
configStaticIconFile(){
  local icon_file_name=$1
  ensureTargetFolder
  cp -f "$BUILD_DIR/extern/icon/$icon_file_name" $TARGET_STATIC
}
configVer(){
  local i="package.json"
  mod_package_json ".version" $VERSION $i
}
address_cover_okmain(){
    declare package_key=$1
    echo "$(cat "$BUILD_DIR_KEY/deploy_OKExChainMainnet.json" | jq -r ".$package_key")"
}
address_cover_oktest(){
    declare package_key=$1
    echo "$(cat "$BUILD_DIR_KEY/deploy_OKExChainTestnet.json" | jq -r ".$package_key")"
}
address_cover_rsc(){
    declare package_key=$1
    echo "$(cat "$BUILD_DIR_KEY/deploy_RSCMainnet.json" | jq -r ".$package_key")"
}
_configParent(){
  local f=$1
  mod_package_json ".extensions.compile" "src/pages/airdrop.vue" $f
  mod_package_json ".extensions.title" $APP_TITLE $f
  mod_package_json ".extensions.desc" $APP_DESC $f
  mod_package_json ".extensions.coin_profile_usdt" "https://i.postimg.cc/zfxxmCY7/38e225ad7f0df4a562837b9fed3c525c-pewter-art-coin-art.jpg" $f
  mod_package_json ".extensions.coin_profile_lsl" "https://github.com/balincer-network/dappv0/blob/main/extern/pack/200w/small_logo_black_200px.png?raw=true" $f
  mod_package_json ".extensions.coin_address" "" $f
  mod_package_json ".extensions.documentation" "https://docs.balincer.network/" $f
  mod_package_json ".extensions.telegram_chat" "https://t.me/Balincer_Global" $f
  mod_package_json ".extensions.telegram_channel" "https://t.me/balincerChannel" $f
  mod_package_json ".extensions.twit" "No message in here" $f
  mod_package_json ".extensions.google_analytics_id" "UA-61080213-2" $f
  mod_package_json ".version" $VERSION $f
}
configOKTest(){
  local f="package.json"
  local icon="balx16.ico"
  rm -rf $TARGET_STATIC
  local CHAINID=65
  configStaticIconFile $icon
  _configParent $f
  mod_package_json ".extensions.app_icon" "/$icon" $f
  mod_package_json ".extensions.production_domain" "https://tgvestevent.balincer.network" $f
  mod_package_json ".extensions.chainID" $CHAINID $f
  mod_package_json ".extensions.coin_symbol" "OKT" $f
  mod_package_json ".extensions.node_using" "OKlinkTestnet" $f
  mod_package_json ".extensions.airdrop.OKlinkTestnet" $(address_cover_oktest "StraightVestPool") $f
  mod_package_json ".extensions.genesis_person" $(address_cover_oktest "MarginPoolAddressesProvider") $f
  mod_package_json ".extensions.coin_address" "" $f
  mod_package_json ".extensions.explorertx" "https://www.oklink.com/oec-test/tx/" $f
  mod_package_json ".extensions.referraluri" "https://tgvestevent.balincer.network?code=" $f
}
configRSC(){
  local f="package.json"
  local icon="balx16.ico"
  local CHAINID=1023
  rm -rf $TARGET_STATIC
  configStaticIconFile $icon
  _configParent $f
  # configStaticSoundFile "error"
  mod_package_json ".extensions.production_domain" "https://tgvesteventrsc.balincer.network" $f
  mod_package_json ".extensions.app_icon" "/$icon" $f
  mod_package_json ".extensions.node_using" "RSC" $f
  mod_package_json ".extensions.chainID" $CHAINID $f
  mod_package_json ".extensions.coin_symbol" "RSC" $f
  mod_package_json ".extensions.airdrop.RSC" $(address_cover_rsc "StraightVestPool") $f
  mod_package_json ".extensions.genesis_person" $(address_cover_rsc "GenesisKey") $f
  mod_package_json ".extensions.coin_address" "" $f
  # previously uploaded coin images: https://postimg.cc/gallery/7S570R6/6ff8e341
  mod_package_json ".extensions.explorertx" "https://www.raisc.io/tx/" $f
  mod_package_json ".extensions.referraluri" "https://tgvesteventoktest.balincer.network?code=" $f
}

gitpush() {
  local gitcheck=$(git diff --shortstat)
  git add .
  #git remote add origin ${GIT_LOC}.git
  git commit -m "Check Point 🍥 ${gitcheck}"
  git push origin
  git push bitbucket
  echo "♻️ You can open from the list of url as shown below"
  git remote -v
}
deploy(){
  local sshline="ssh -i /Users/hesdx/.ssh/id_rsa_aws"
  cd $BUILD_DIR && rsync -avz -e $sshline "$BUILD_DIR/dist" root@$LOCAL:$TARGET_LOC
}
TARGET_LOC=/home/wwwroot/arbitdefi/
APP_TITLE="defiabibot"
APP_DESC="botdefitradingalgo"
GOOGLETRANS="https://docs.google.com/spreadsheets/d/e/2PACX-1vR9-Nx_JTxmBP9rRTfGapdWWB2CQ4EBDBHwS8ZbIMg_6_yZcaWE7gVMs4vLd8npOnEUjJhpMnE3cPCS/pubhtml?gid=863127413&single=true"
BUILD_DIR=$HOME/Documents/b95/arbitdefibot
DIST_DIR=$HOME/Documents/b95/arbitdefibot/build_web
TARGET_STATIC="$BUILD_DIR/src/static"
BUILD_DIR_KEY=$HOME/Documents/b95/balincer/deploy_results
TRANSLATION_F="$HOME/Documents/b95/arbitdefibot/extern/translation.csv"
