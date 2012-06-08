#!/bin/bash
# requires formail from procmail package,
# sendsms script from smstools3
# and sqlite3

# Released in the Public Domain
# This work is free of known copyright restrictions.

PATH="$PATH:/usr/local/sbin:/usr/local/bin"
allowed_countrycodes=("49")
max_nick_length="10"
db="/opt/sms-verteiler/sms.db"
get_numbers() {
	sqlite3 $db "select number from numbers;"
}
get_admins() {
	sqlite3 $db "select number from admins;"
}
get_names() {
	sqlite3 $db "select name from numbers where number='$1';"
}
add_admin() {
	sqlite3 $db "insert into admins (number,name) values ('$1', '$2');"
}
validate_number() {
	number="$1"
	num_length=$(echo -n "$number" | wc -m)
	# german mobile number max length is 13 min is 12
	# https://en.wikipedia.org/wiki/Telephone_numbers_in_Germany#Non-geographic_numbering
	# change accordingly for other countries
	if ! [ $num_length = 13 -o $num_length = 12 ]
	then
		echo "invalid number length, are you sure you added the countrycode code?"
		exit 1
	fi
	for countrycode in $allowed_countrycodes
	do
		if ! echo $number |egrep -q "^$countrycode"
		then    
			echo "Invalid Countrycode, the number has to start with one of the following countrycodes"
			for countrycode in $allowed_countrycodes
			do
				echo $countrycode
			done
			exit 1
		fi
	done
}
validate_name() {
	name="$1"
	name_length=$(echo $name | wc -m)
	if ! [ $name_length -le $max_nick_length ]
	then
		echo "nickname should be <=${max_nick_length} chars"
	fi
}
add_user() {
	validate_number "$1"
	validate_name "$2"
        sqlite3 $db "insert into numbers (number,name) values ('$1', '$2');"
}
add_admin() {
	validate_number "$1"
	validate_name "$2"
	sqlite3 $db "insert into admins (number,name) values ('$1', '$2');"
}

case "$1" in
	RECEIVED)
		sms="$2"
  		FROM=$(formail -zx From: < $sms)
		if get_numbers | grep -q $FROM
		then
			for TO in $(get_numbers)
			do
				tmpmsg=$(mktemp)
				name="$(get_names $TO)"
				echo -n "${name}: " >> $tmpmsg
				cat $sms |formail -I "" |head -n -1 |tail -n -1 >> $tmpmsg
				cat $tmpmsg |sendsms $TO
				rm $tmpmsg
			done
		else
			for ADMIN in $(get_admins)
			do
				cat $sms |formail -I "" |head -n -1 |tail -n -1| sendsms $ADMIN
			done
		fi
	;;
	adduser)
		if [ $# -ne 3 ]
		then
			echo "Usage $0 $1 number nickname"
			echo "number should include the countrycode without prefixes and nickname should be <=${max_nick_length} chars"
		fi
		number="$2"
		name="$3"
		add_user $number $name
	;;
        addadmin)
                if [ $# -ne 3 ]
                then
                        echo "Usage $0 $1 number nickname"
                        echo "number should include the countrycode without prefixes and nickname should be <=${max_nick_length} chars"
                fi
                number="$2"
                name="$3"
                add_admin $number $name
        ;;
	createdb)
		sqlite3 $db "CREATE TABLE numbers (id INTEGER PRIMARY KEY AUTOINCREMENT, number INTEGER, name TEXT);"
		sqlite3 $db "CREATE TABLE admins (id INTEGER PRIMARY KEY AUTOINCREMENT, number INTEGER, name TEXT);"
	;;
	*)
		echo "Usage: $0 adduser number nickname"
	;;
esac
