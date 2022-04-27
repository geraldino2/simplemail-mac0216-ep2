#Gabriel Caiaffa Mendonça       NUSP 11838669
#Gabriel Geraldino de Souza     NUSP 12543885

# base directory structure
mkdir -p simplemail
CREDENTIALS_FILE="simplemail/credentials.dat"
if [ ! -e $CREDENTIALS_FILE ] ; then
	: > $CREDENTIALS_FILE
fi

# control variables
signed_in=false
USER=notdefined

# check if the current user has already signed in
# alert and exit code 1 if not
sign_in_verification() {
	if test "$signed_in" = false ; then
		echo "you are not signed in!"
		return 1
	fi
	return 0
}

# encode password using sha256
generate_password() {
	local sha256password=$(echo $1 | sha256sum | cut --delimiter=' ' -f1)
	echo "$sha256password"
}

# infinite loop receiving commands
while [ 1 ]; do
	# read command and args
	read -p "simplemail> " command arg1 arg2 arg3
	case $command in
		quit)
			exit 0
		;;
		help)
			echo "createuser [user] [password]\
			\nlistusers\
			\npasswd [username] [oldpassword] [newpassword]\
			\nlogin [username] [password]\
			\nlist\
			\nmsg [user]\
			\nread [number]\
			\nunread [number]\
			\ndelete [number]\
			\nquit"
		;;
		listusers)
			if [[ $(wc -l < $CREDENTIALS_FILE) = 0 ]] ; then
				echo "there are no registered users yet"
			else
				cut --delimiter=' ' -f1 < $CREDENTIALS_FILE
			fi
		;;
		createuser)
			# check if a user is already register
			# if not, append "{user} {encoded_pass}" to the credentials file
			if cut --delimiter=' ' -f1 < $CREDENTIALS_FILE | grep -Fxq $arg1 ; then
				echo "user is already registered"
			else
				password=$(generate_password $arg2)
				echo "$arg1 $password" >> $CREDENTIALS_FILE
				mkdir -p "simplemail/$arg1"
			fi
		;;
		passwd)
			# if the credentials are valid, replace old_password->new_password in the credentials file
			sign_in_verification || continue
			password=$(generate_password $arg2)
			newpassword=$(generate_password $arg3)
			if grep -Fxq "$arg1 $password" $CREDENTIALS_FILE ; then
				sed -i "s/$arg1 $password/$arg1 $newpassword/g" $CREDENTIALS_FILE
			else
				echo "incorrect credentials"
			fi
		;;
		login)
			# if the credentials are valid, update control variables
			password=$(generate_password $arg2)
			if grep -Fxq "$arg1 $password" $CREDENTIALS_FILE ; then
				signed_in=true
				USER=$arg1
			else
				echo "incorrect credentials"
			fi
		;;
		list)
			sign_in_verification || continue
			if [[ $(ls -l ./simplemail/$USER | wc -l) = 1 ]] ; then
				echo "you don't have any emails yet"
			else
				i=0
				for file in $(find "simplemail/$USER" -type f); do
					i=$(($i+1))
					echo "$i | $(head -1 "$file")"
				done
			fi
		;;
		msg)
			# receive a message/subject and create a random named file to some user folder
			sign_in_verification || continue
			if cut --delimiter=' ' -f1 < $CREDENTIALS_FILE | grep -Fxq $arg1 ; then
				read -p "subject:" subject
				echo "type a message; type control-d to exit"
				MSG_ID=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -sw 255 | head -n 1)
				echo "N | $(date) | $USER | $subject" > "simplemail/$arg1/$MSG_ID"
				cat >> "simplemail/$arg1/$MSG_ID"
			else
				echo "user does not exist"
			fi
		;;
		read)
			# read and parse a specific file (message) from a user inbox
			sign_in_verification || continue
			file=$(find "simplemail/$USER" -type f | sed "$arg1 q;d")
			sed -i "s/N |/  |/" $file
			echo "From:$(head -1 $file | cut --delimiter='|' -f3)"
			echo "Subject:$(head -1 $file | cut --delimiter='|' -f4-)"
			tail -n +2 $file
					
		;;
		unread)
			sign_in_verification || continue
			sed -i "s/  |/N |/" $(find "simplemail/$USER" -type f | sed "$arg1 q;d")
		;;
		delete)
			sign_in_verification || continue
			rm $(find "simplemail/$USER" -type f | sed "$arg1 q;d")
		;;
		*)
			echo "unrecognized command"
		;;
	esac
done
