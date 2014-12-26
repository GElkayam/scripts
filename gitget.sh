#!/usr/bin/bash
# Guy Elkayam 25-Dec-2014. Merry XMas.
# Download Binaries from GitHub Releases

main() {
	parse_switch $*
	test_input
	[ -n "$ORG" ] && testOrg
	[ -n "$GITUSER" ] && testUser
	testRepo
	getJSON
	getList
	downloadList
}

printHelp(){
echo "Usage: $0 [options...]
Options:
 -up, --userpass	Git login and password in the format of username:password
 -u, --username		Git User name ()
 -o, --org		Organization name
 -r, --repo 		Repository name
 -l, --latest 		download only the latest releases
 -n, --no-download	don't download
 -d, --debug 		Debug mode
 -h, --help		this help message and exit

"
}

parse_switch() {
	DOWNLOAD=true
	SUPPORTED="-up -r -o -l -d -n"
	while [ $# -gt 0 ]; do
		[ $DEBUG ] && echo $*
		case $1 in
			-up|--userpass) USERPASS=$2
			shift 2
			;;
			-o|--org) ORG=$2
			shift 2 ;;
			-u|--username) GITUSER=$2
			shift 2 ;;
			-r|--repo) REPO=$2 
			shift 2 ;;
			-l|--latest) LATEST=true 
			shift 1 ;;
			-d|--debug) DEBUG=true 
			shift 1 ;;
			-n|--no-download) DOWNLOAD=false
			shift 1 ;;
			-h|--help) printHelp ; exit 0 ;;
			*) echo ERROR: $1 is unsupported. Only $SUPPORTED are supported.
			exit 1
			;;
		esac
	done
	[ $DEBUG ] && echo "userpass: $USERPASS \n Org: $ORG \n Repo: $REPO \n Download: $DOWNLOAD"
}

test_input() {
	if [  ! -n "$USERPASS"  -o  ! -n "$REPO" -o ! -n "$ORG" -a ! -n "$GITUSER" ] ; then
		printHelp
		[ -z "$USERPASS" ] && echo ERROR: Missing Username and Password. supply them as -up user:pass
		[ -z "$ORG" ] && echo ERROR: Missing Org or Username, please supply one of them. supply it as -o OrgName or -u Username
		[ -z "$USERPASS" ] && echo ERROR: Missing Repository name. supply it as -r RepositoryName

		exit 1
	fi
	if [ -n "$ORG" -a -n "$GITUSER"  ] ; then
		printHelp
		echo "Both Org and Username were passed, please choose only one of them"
		exit 1
	fi
	
}

getJSON() {
	[ ! -e JSON.sh ] && echo Fetching JSON.sh from GitHub && curl -s https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh -o JSON.sh
}

testOrg(){
	RESPONSE=$(curl -s -u $USERPASS https://api.github.com/orgs/$ORG --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		echo ERROR: Org $ORG was not found
		exit 4
	fi
}

testUser(){
	RESPONSE=$(curl -s -u $USERPASS https://api.github.com/users/$GITUSER --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		echo ERROR: User $GITUSER was not found
		exit 4
	fi
}


testRepo(){
	RESPONSE=$(curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		[ -n "$ORG" ] && echo ERROR: Repository $REPO was not found in $ORG
		[ -n "$GITUSER" ] && echo ERROR: Repository $REPO was not found in $GITUSER
		
		exit 4
	fi
}

getList () {
	[ $LATEST ] && LIST=`curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep "^\[0," |grep -v uploader | grep assets | grep "\"name\"\|\"url\""`
	[ ! $LATEST ] && LIST=`curl -s -u $USERPASS https://api.github.com/repos/$ORG/$REPO/releases | sh ./JSON.sh -b | grep -v uploader | grep assets | grep "\"name\"\|\"url\""`
}

downloadList() {
IFS=$'\n' 
for line in $LIST ;
do
	[ $DEBUG ] && echo line is $line
	VALUE=$(echo $line | cut -f2)
	[[ $line == *url* ]] && URL=$VALUE 
	if [[ $line == *name* ]] ; then 
		NAME=${VALUE//\"}
		[ -f $NAME ] && echo "$NAME exists before downloading."
		$DOWNLOAD && echo Downloading $NAME as referenced in $URL
		! $DOWNLOAD && echo Not Downloading $NAME as referenced in $URL
		$DOWNLOAD && curl -s -u $USERPASS -L -H "Accept:application/octet-stream" ${URL//\"} -o $NAME
		[ -s $NAME ] && $DOWNLOAD && echo ${NAME//\"} downloaded successfully. ||  echo $NAME was not downloaded.
	fi
done
}

main $*