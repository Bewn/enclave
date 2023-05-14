#!/usr/bin/env sh
## should work with generic unix shell (i.e. bash, fish, zsh, xonsh, elvish, nu, oil)
# requires lvm2 and cryptsetup

##############################------------source code-----------##############################
##~****~**~~*~*~*~*~**~**~*~*~****~*~*~*~*~***~*~*~***~*~*~***~**~*~*~****~*~*~*~*~***~*~*~*~*


#####################################################|
######## run header #################################|
############ eatablishes variables ##################|
#####################################################|

if [ ! -d  $HOME/.enclave ] ;
	then mkdir $HOME/.enclave ;
fi

# get fresh loop dev name
ENCLAVE_loop=$(sudo losetup -f)

# working directory is current run directory if possible
if [ ! -w $PWD ] ;
    then mkdir $HOME/.enclave/workdir 
    twd=$HOME/.enclave/work-dir ; # temp work dir
	else twd=$PWD
fi

#name for enclave 
ENCLAVE_name=encl.rnd #~*~*~*# enclave random. disordered // aranged
ENCLAVE_dir=$twd

fancy_line () {
	echo "~****~**~~*~*~*~*~**~**~*~*~****~*~*~*~*~***~*~*~***~*~*~***~**~*~*~****~*~*~*~*~***~*~*~*~**~*~*~**"
}

help () {
	echo "		This is the enclave cli help panel
			usage:
				 enclave-cli [ command ]
				 enclave [ -o | --OPTION ][ < path to *.rnd > ]
				 
				 commands: (for cli usage)
				   g, generate : to generate an enclave
				   c, config   : to edit, init, config, etc.

				 options: (for non-interactive usage)
				  '' : runs enclave-cli
				  -f, --file  FILE : run with already generated enclave file to use
				  -h, --help  : runs this help command"
}

generate_rnd_file () {
	read -p "            desired enclave size in MiB? 
		enter e.g. '1' for (8)*(2^8)^2 random bits (=1MiB)
		or enter '4K' (=4000*8*(2^8)^2) for 4GiB
		the pattern N*8*2^(n^2) guarantees a size where no bytes are incomplete. 
		could be useful for compression.
		(this is a meaningless but interesting way to remember the numbers and that
		we're always working with sequences of bits in the end.)
		it eill be saved as a .rnd file.

			enter now: " input

			
		  	rnd_file=$twd/$ENCLAVE_name
			echo "writing random (indeciferable) data to $ENCLAVE_name"
	dd if=/dev/urandom of=$rnd_file bs=1024 count="$input"x1024 status=progress
	echo "
			You have now created a raw random to-be-arranged enclave file"
}

add_to_lvm () {
	read -p "		
					would you like to add $USER to the logical volume management (lvm) group?
					if yes then you will only need to authenticate now and to decrypt the first time.
					[Y/n]" input
		case $input in 
			'Y'|'y'|'') sudo usermod -a -G lvm $USER 
						echo "added to lvm group" ;;
			'N'|'n') echo "not adding to lvm group" ;;
		esac
}

make_fs_on_rnd () {
	if [ ! -z $($1 | grep .rnd) ] ;
		then mkfs.btrfs $1 ;
	fi
}

randomly_generate_unique_key () {
	echo "
		we will now generate a precisely reproducable simple unicode key file
		this file will be the encryption key for the enclave. Keep it safe and secure.
		It is 10,000 lines of length 64=8^2 characters each. (could do bytewise product)
		It is generated from $twd/random-seed 
		and stored at $twd/unicode-unique-key
		...
		..
		.
		..
		..."
	dd if=/dev/urandom of=$twd/random-seed bs=64 count=100K status=progress
	cat $twd/random-seed | tr -dc 'a-zA-Z0-9~!@#$%^&*_' | fold -w 64 | head -n 10000 > $twd/unicode-uqique-key
}

create_loop_device () {
	#with random encl.rnd as disk file
	sudo losetup --direct-io=on $ENCLAVE_LOOP $ENCLAVE_FILE
}

format_rnd_fs () {
	## overwrites the random file with filesystem encrypted with out univode key
	sudo cryptsetup luksFormat --type luks2 $ENCLAVE_LOOP $twd/unicode-unique-key
}

activate_enclave_fs () {
	echo "	activating encrypted enclave with unicode-unique-key"
	sudo bash -c "
	     losetup --direct-io=on $ENCLAVE_LOOP $ENCLAVE_FILE
	     cryptsetup open $ENCLAVE_LOOP --type=luks2 enc --key-file $twd/unicode-unique-key
	     lvscan
	     "
}

setup_logical_volume () {
	if [ -z "$(sudo pvs)" ];
		 then sudo pvcreate /dev/mapper/enc ;
	fi
	if [ -z "$(sudo vgs)" ];
		then sudo vgcreate enc /dev/mapper/enc ;
	fi
	if [ -z "$(sudo lvs)" ];
    		then sudo lvcreate -n benclave -l 100%FREE enc ;
	fi
}

deactivate_enclave () {
   sudo bash -c "lvchange -an enc
   		 cryptsetup close enc
   		 losetup -D"
} 

config_procedure () {
	read -p "			 	configure? 

									[Y/n] " input
	case $input in
		y|Y|'') add_to_lvm ;;
		n|N) echo "not adding to lvm group, you will need sudo privileges to mount" ;;
	esac
}

encode_enclave () {
	true
}

full_generate_enclave () {
	generate_rnd_file
	randomly_generate_unique_key
	create_loop_device
	format_rnd_fs
	activate_enclave_fs

	## the fact that the main program code is just an ordered list of functions
	## is evidence of the usefulness of functional style programming
	## it would be better in a language with guaranteed data types and compiled functions
	## still this is very satisfying code!
}

######### distro specfic functions
user_os=$(uname -v)

check_dependencies () {
	if [ -x "$(which lvm)" ] && [ -x "$(which cryptsetup)" ] ;
		then echo "proper dependies found!"
		return 0 ;
	fi

	echo "you need lvm2 and cryptsetup. Attempting to install with common package managers
			if failed, please install those dependencies with your preferred packaging system"
	
	packagesNeeded='lvm2 cryptsetup'
	if [ -x "$(command -v apk)" ];       then sudo apk add --no-cache $packagesNeeded ;
	elif [ -x "$(command -v apt-get)" ]; then sudo apt-get install $packagesNeeded ;
	elif [ -x "$(command -v dnf)" ];     then sudo dnf install $packagesNeeded ;
	elif [ -x "$(command -v zypper)" ];  then sudo zypper install $packagesNeeded ;
	elif [ -x "$(command -v xbps)"];     then sudo xbps-install $packagesNeeded ;
	elif [ -x "$(command -v pacman)" ];	 then sudo pacman -Sy $packagesNeeded ;
	elif [ -x "$(command -v emerge)" ];  then sudo emerge -av $packagesNeeded ;
	else echo "loacal dependency install not possible, please install lvm2 and cryptsetup manually"
	fi
}

#########


#########################################################################|
#######~*~*~*~*~*~**~~*~**** "main" below *****~~~~*~*~*~*~*~*~*~*~*~*~*~|
####### top level code ##################################################|
####### for running functions and io ####################################|
#########################################################################|

## non interactive run opts
## TODO

echo "welcome to the enclave command-line interface!"
echo "~*~*~*~*~*~~*~*~*~ enjoy ~*~*~*~~*~*~*~*~*~*~*~"
PROMPT="encl-cli % <- "
read -p "$PROMPT" input

while true
do
	case $input in
		q|Q|quit|exit) exit 0 ;;
		c|C|config) config_procedure ;;
		h|H|help) help ;;
		g|G|gen|generate) full_generate_enclave ;;
		i|I|init) init_routine ;;
		check) check_dependencies ;;
	esac
	read -p "$PROMPT" input
done