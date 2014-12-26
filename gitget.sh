#!/usr/bin/bash
# Guy Elkayam 25-Dec-2014. Merry XMas.
# Download Binaries from GitHub Releases

if [ $# -ne 3 ] ; then
	echo "ERROR: Usage \"$0 UserName:PassWord Org repo\""
	echo "ERROR: For debug run \"DEBUG=true $0 UserName:PassWord Org repo\""
	exit 1
fi
USERPASS=$1
ORG=$2
REPO=$3
[ ! -e JSON.sh ] && echo Fetching JSON.sh from GitHub && curl -s https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh -o JSON.sh

[ $DEBUG ] && echo "got $USERPASS and $ORG and $REPO"

[ $DEBUG ] && echo "curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep "^[" |grep -v uploader | grep assets | grep "\"name\"\|\"url\"""
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
		curl -s -u $USERPASS -L -H "Accept:application/octet-stream" ${URL//\"} -o ${NAME//\"}
		[ -e ${NAME//\"} ] && echo ${NAME//\"} downloaded successfully. || echo ERROR downloading ${NAME//\"}.
	fi
done
