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
echo "Usage: $0 (-u gituser | -o gitorg) -r repo (-up user:pass | -t token | -a) [options...]

Mandaroty Options:
 -up, --userpass	Git login and password in the format of username:password
 -t,  --token		OAuth Token login, can be used instead of username and password
 -a,  --anonymous	Anonymous Authentication, no token and no user password
 -u,  --username	Git User name ()
 -o,  --org		Organization name
 -r,  --repo 		Repository name
 
 Optional Options:
 -l,  --latest 		download only the latest releases
      --tag			specific tag/release
 -n,  --no-download	don't download
 -d,  --debug 		Debug mode
 -h,  --help		this help message and exit

"

}

testPairValues() {
	if [ $2 ] ; then
		if [[ $2 == -* ]] ; then 
			echo "Value starts with dash \"$2\" are you sure you'r not missing a value?"
			printHelp
			exit 3
		fi
		return 0
	else
		echo "$1 didn't have a value
Usage: $1 <Value>"
		printHelp
		exit 2
	fi
}

parse_switch() {
	DOWNLOAD=true
	ANONYMOUS=false
	while (( $# )); do
		case $1 in
			-up|--userpass) testPairValues $1 $2 && USERPASS=$2
			shift 2 ;;
			-t|--token) testPairValues $1 $2 &&  TOKEN=$2
			shift 2 ;;
			-o|--org) testPairValues $1 $2 &&  ORG=$2
			shift 2 ;;
			-u|--username) testPairValues $1 $2 && GITUSER=$2 
			shift 2 ;;
			-r|--repo) testPairValues $1 $2 && REPO=$2 
			shift 2 ;;
			-a|--anonymous) ANONYMOUS=true
			shift 1 ;;
			-l|--latest) LATEST=true 
			shift 1 ;;
			--tag) testPairValues $1 $2 && TAG=$2 
			shift 2 ;;
			-d|--debug) DEBUG=true 
			shift 1 ;;
			-n|--no-download) DOWNLOAD=false
			shift 1 ;;
			-h|--help) printHelp ; exit 0 ;;
			*) echo ERROR: $1 is unsupported.
			printHelp
			exit 1
			;;
		esac
	done
	[ $DEBUG ] && echo "userpass: $USERPASS \n Org: $ORG \n Repo: $REPO \n Download: $DOWNLOAD"
	[ $DEBUG ] && echo "ANONYMOUS: $ANONYMOUS \n Org: $ORG \n Repo: $REPO \n Download: $DOWNLOAD"
	[ $USERPASS ] && USERAUTH=-u $USERPASS
	[ $TOKEN ] && TOKENAUTH=?access_token=$TOKEN
}

test_input() {
	if [[ -z "$USERPASS"  && -z "$TOKEN" && "$ANONYMOUS" == false  ||  -z "$REPO" || -z "$ORG" && -z "$GITUSER" || -n "$TAG" && "$LATEST" == "true" ]] ; then
		printHelp
		[[ -z "$USERPASS"  && -z "$TOKEN" && "$ANONYMOUS" == false ]] && echo ERROR: Missing Username and Password, Access Token or Anonymous directive.
		[[ -z "$ORG" && -z "$GITUSER" ]] && echo ERROR: Missing Org or Username, please supply one of them. supply it as -o OrgName or -u Username
		[ -z "$REPO" ] && echo ERROR: Missing Repository name. supply it as -r RepositoryName
		[[ -n "$TAG" && "$LATEST" == "true" ]] && echo "ERROR: Both tag and latest were passed, please specify only one of them (or none)."
		
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
	RESPONSE=$(curl -s $USERAUTH https://api.github.com/orgs/$ORG$TOKENAUTH --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		echo ERROR: Org $ORG was not found
		exit 4
	fi
}

testUser(){
	RESPONSE=$(curl -s $USERAUTH https://api.github.com/users/$GITUSER$TOKENAUTH --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		echo ERROR: User $GITUSER was not found
		exit 4
	fi
}


testRepo(){
	RESPONSE=$(curl -s $USERAUTH https://api.github.com/repos/$ORG/$REPO$TOKENAUTH --write-out %{http_code} --output /dev/null)
	if [ "$RESPONSE" != "200" ] ; then
		[ -n "$ORG" ] && echo ERROR: Repository $REPO was not found in $ORG
		[ -n "$GITUSER" ] && echo ERROR: Repository $REPO was not found in $GITUSER.
		[ $ANONYMOUS ] && echo ERROR: Repository $REPO might be private
		
		exit 4
	fi
}

getList () {
	[ ! $LATEST ] && LIST=`curl -s $USERAUTH https://api.github.com/repos/$ORG/$REPO/releases$TOKENAUTH | bash ./JSON.sh -b | grep -v uploader | grep assets | grep "\"name\"\|\"url\"\|\"browser_download_url\""`
	TAGID=0
	[ -n "$TAG" ] && TAGID=$(echo "$LIST" | grep "\"browser_download_url\"" | grep "$TAG" | sed "s/\[//" | sed "s/,.*//" | head -1)
	[ $DEBUG ] && echo "TagID: \"$TAGID\""
	[[ $LATEST == "true" || -n "$TAG" ]] && LIST=`curl -s $USERAUTH https://api.github.com/repos/$ORG/$REPO/releases$TOKENAUTH | bash ./JSON.sh -b | grep "^\[$TAGID," |grep -v uploader | grep assets | grep "\"name\"\|\"url\"\|\"browser_download_url\""`
	[ $DEBUG ] && echo "TagID: $TAGID"
	[ $DEBUG ] && echo -e "LIST:\n$LIST" 
}

downloadList() {
IFS=$'\n' 
for line in $LIST ;
do
	[ $DEBUG ] && echo line is $line
	VALUE=$(echo $line | cut -f2)
	[[ $line == *url* && ! $line == *browser_download_url* ]] && URL=$VALUE 
	[[ $line == *name* ]] && NAME=${VALUE//\"}
	if [[ $line == *browser_download_url* ]] ; then 
		[ -f $NAME ] && echo "$NAME exists before downloading."
		$DOWNLOAD && echo Downloading $NAME as referenced in $URL
		! $DOWNLOAD && echo Not Downloading $NAME as referenced in $URL
		$DOWNLOAD && curl -s $USERAUTH -L -H "Accept:application/octet-stream" ${URL//\"}$TOKENAUTH -o $NAME
		[ -s $NAME ] && $DOWNLOAD && echo ${NAME//\"} downloaded successfully. ||  echo $NAME was not downloaded.
	fi
done
}

main $*
