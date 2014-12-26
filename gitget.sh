#!/usr/bin/bash
# Guy Elkayam 25-Dec-2014. Merry XMas.
# Download Binaries from GitHub Releases

SUPPORTED="-up -r -o -l -d"
DOWNLOAD=true

while [ $# -gt 0 ]; do
	[ $DEBUG ] && echo $1 $2
	case $1 in
		-up) USERPASS=$2
		shift 2
		;;
		-o) ORG=$2
		shift 2 ;;
		-r) REPO=$2 
		shift 2 ;;
		-l) LATEST=true 
		shift 1 ;;
		-d) DEBUG=true 
		shift 1 ;;
		-dd) DOWNLOAD=false
		shift 1 ;;
		*) echo ERROR: $1 is unsupported. Only $SUPPORTED are supported.
		exit 1
		;;
	esac
done

if [  ! -n "$USERPASS"  -o  ! -n "$ORG" -o ! -n "$REPO" ] ; then
	echo "ERROR: Usage \"$0 -up UserName:PassWord -o Org -r repo\""
	echo "ERROR: For debug run \"DEBUG=true $0 -up UserName:PassWord -o Org -r repo\""
	[ $DEBUG ] && echo "ERROR: Usage \"$0 -up $USERPASS -o $ORG -r $REPO\""
	[ -z "$USERPASS" ] && echo ERROR: Missing Username and Password. supply them as -up user:pass
	[ -z "$ORG" ] && echo ERROR: Missing Org or Account. supply it as -o OrgName
	[ -z "$USERPASS" ] && echo ERROR: Missing Repository name. supply it as -r RepositoryName

	exit 1
fi

[ ! -e JSON.sh ] && echo Fetching JSON.sh from GitHub && curl -s https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh -o JSON.sh

[ $DEBUG ] && echo "userpass: $USERPASS \n Org: $ORG \n Repo: $REPO \n Download: $DOWNLOAD"

[ $DEBUG ] && echo "curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep "^[0" |grep -v uploader | grep assets | grep "\"name\"\|\"url\"""
IFS=$'\n' 
[ $LATEST ] && COMMAND=`curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep "^\[0," |grep -v uploader | grep assets | grep "\"name\"\|\"url\""`
[ ! $LATEST ] && COMMAND=`curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep -v uploader | grep assets | grep "\"name\"\|\"url\""`
for line in $COMMAND ;
do
	[ $DEBUG ] && echo line is $line
	VALUE=$(echo $line | cut -f2)
	[[ $line == *url* ]] && URL=$VALUE 
	if [[ $line == *name* ]] ; then 
		NAME=$VALUE
		echo Downloading $NAME as referenced in $URL
		$DOWNLOAD && curl -s -u $USERPASS -L -H "Accept:application/octet-stream" ${URL//\"} -o ${NAME//\"}
		[ -e ${NAME//\"} ] && echo ${NAME//\"} downloaded successfully. || echo ERROR: ${NAME//\"} was not downloaded .
	fi
done
