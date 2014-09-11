#!/bin/bash
set -e

#
# Build the distribution using the same process used on Drupal.org
#
# Usage: scripts/build.sh [-y] <project> from the profile main directory.
#

# Definning variables & constants
ASK=true
CAT=$(which cat)
CHMOD=$(which chmod)
CP=$(which cp)
BASEDIR=$(dirname $0)
DATE=$(which date)
DATETIME=$($DATE '+%Y%m%d%H%M')
DESTINATION="../releases/$DATETIME"
DRUSH=$(which drush)
ECHO=$(which echo)
CLEAN=false
LN=$(which ln)
LS=$(which ls)
MKDIR=$(which mkdir)
MKTEMP=$(which mktemp)
MV=$(which mv)
RM=$(which rm)
RMDIR=$(which rmdir)
SUDO=$(which sudo)
TEMP_BUILD=$($MKTEMP -d)

# Colors
GREEN='\033[01;32m'
NC='\033[00m'
RED='\033[01;31m'

usage() {
  $ECHO "Usage: build.sh [-y] [-c] -e {pro|dev} [-p <PROJECT_NAME>]" >&2
  $ECHO "Use -p <PROJECT_NAME>, if not username by default." >&2
  $ECHO "Use -y to skip deletion confirmation." >&2
  $ECHO "Use -c to perform a clean installation and the first time installation." >&2
  $ECHO "Use -e to set the environment 'pro' or 'dev'." >&2
  cd - > /dev/null
  exit 1
}

# Positioning the script
cd $BASEDIR

# Check the options
while getopts ye:cp: opt; do
  case $opt in
	y) ASK=false ;;
	c) CLEAN=true ;;
	p) PROJECT=$OPTARG ;;
	e) ENVMNT=$OPTARG ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    ;;
  esac
done

if [ -z $PROJECT ]; then
  PROJECT=$(/usr/bin/whoami) 
fi

if [ -z $ENVMNT ]; then
  usage
fi

if [ ! -f ../profile/drupal-org.make ]; then
  $ECHO "[error] Run this script expecting ../profile/ directory."
  exit 1
fi

# Drush make expects destination to be empty
$RMDIR $TEMP_BUILD

# Build the profile.
$ECHO -e "${GREEN}Building the profile...${NC}"
$DRUSH make --no-cache --no-core --contrib-destination="." ../profile/$PROJECT-${ENVMNT}.make tmp

# Build the distribution and copy the profile in place.
$ECHO -e "${GREEN}Building the distribution...${NC}"
$DRUSH make ../profile/drupal-org-core.make $TEMP_BUILD
$ECHO -e "${GREEN}Moving to destination...${NC}"
#$CP -r . $TEMP_BUILD/profiles/$PROJECT
$MKDIR -p $TEMP_BUILD/profiles/$PROJECT
$CP -r tmp/profiles/$PROJECT/* $TEMP_BUILD/profiles/$PROJECT
$RM -rf tmp
$MV $TEMP_BUILD $DESTINATION

# Create symblic links
$ECHO -e "${GREEN}Creating symbolic links...${NC}"
if [ -h ../www ]; then
	$RM ../www
fi
$LN -s releases/$DATETIME ../www
$LN -s ../../../../shared/files ../releases/$DATETIME/sites/default/files

# Update database & clean
if $CLEAN; then
	$ECHO -e "${GREEN}Update database & cleaning...${NC}"
	read -r -p "Give me the complete DOMAIN (ex: www.example.org): " DOMAIN
	read -r -p "Give me the SITE NAME: " SITENAME
	read -r -p "Give me the SITE MAIL: " SITEMAIL
	read -r -p "Give me ROOT database password: " PASSWD
	
	cd ../www

	$ECHO -e "${RED}You are about to DROP all the '$PROJECT' database.${NC}"
	$DRUSH si --db-url=mysql://$PROJECT:$PROJECT@localhost/$PROJECT --db-su=root --db-su-pw=$PASSWD --site-mail="$SITEMAIL" --account-mail="$SITEMAIL" $PROJECT
	
	$CHMOD u+w sites/default/settings.php
	$ECHO "\$base_url='http://$DOMAIN';" >> sites/default/settings.php
	
	$DRUSH cc all
	$DRUSH updatedb -y
	$DRUSH cache-clear drush
	$DRUSH features-revert-all -y
	$DRUSH cc all

	cd -
	
	$CP ../www/sites/default/settings.php ../config/
else
  $CP ../config/settings.php ../www/sites/default/
fi

# Cleaning releases
$LS -t ../releases/* | sed '1,4d' | xargs rm -rf

$ECHO -e "${GREEN}...DONE...${NC}"

