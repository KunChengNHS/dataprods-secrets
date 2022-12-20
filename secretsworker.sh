#!/bin/bash

PROFILE=dp-svc-user
KMSKEYID=399e2a2d-44f9-4e3c-a13f-39422ce06798
CLSTIME=5
SAFE=./safe
UNSAFE=./unsafe
FILE=''
COMMENT=''


usage() {
    printf "\nSee confluence page https://nhsd-confluence.digital.nhs.uk/display/TPS/Secrets+Management for command details\n"
}

dodecrypt() {
    is_safefile
    git_msg
    kms_decrypt $SAFEFILE
    clrscreen
}

doupdate() {
    is_safefile
    git_msg
    kms_decrypt $SAFEFILE > $UNSAFEFILE
    KEY=$(echo ${SECRET} | cut -d "=" -f1)
    VALUE=$(echo ${SECRET} | cut -d "=" -f2)
    MATCHCOUNT=$(cd $UNSAFE; grep -wc ^$KEY $FILE)

    case $MATCHCOUNT in
    0)
        printf "This secret does not exist. Use command 'make add-secret...' to add this secret"
        ;;
    1)
        sed -i '/^'"${KEY}"'\=/s/=.*$/='"${VALUE} ${COMMENT}"'/' $UNSAFEFILE
        kms_encrypt $UNSAFEFILE > $SAFEFILE
        printf "Secret(s) added/updated\n"
        printf "Make sure to merge into main branch and push to remote to preserve changes\n"
        cat $UNSAFEFILE
        rm -f $UNSAFEFILE
        clrscreen
        ;;
    *)
        error_multiplematch
        ;;
    esac

    exit
}

doencrypt() {
    is_safefile
    git_msg
    kms_decrypt $SAFEFILE > $UNSAFEFILE
    KEY=$(echo ${SECRET} | cut -d "=" -f1)
    MATCHCOUNT=$(cd $UNSAFE; grep -wc ^$KEY $FILE)

    case $MATCHCOUNT in
    0)
        echo >> $UNSAFEFILE
        echo $SECRET $COMMENT >> $UNSAFEFILE

        kms_encrypt $UNSAFEFILE > $SAFEFILE
        cat $UNSAFEFILE
        rm -f $UNSAFEFILE
        clrscreen
        get_aliasname
        printf "Make sure to merge into main branch and push to remote to preserve changes\n"
        ;;
    1)
        printf "Secret with key $KEY already exists\n"
        printf "Use command 'make update-secret...' to update this secret\n"
        printf "Or add it manually by decrypting the file first\n"
        ;;
    *)
        error_multiplematch
        ;;
    esac
    exit
}

dolisttopicsdecrypt() {
    PS3="Select line number for topic to decrypt: "
    select TOPIC in $(cd $SAFE; ls -1 ${ENV}*.enc | sed -e 's/\..*$//') quit; do
    printf "Selected $TOPIC\n\n"
    if [ "$TOPIC" == "quit" ]; then
        exit
    else
        SAFEFILE=./safe/${TOPIC}.enc
        kms_decrypt $SAFEFILE
        clrscreen
        break
    fi
    done
}

doencryptfile() {
    if [ ! -f $UNSAFEFILE ]; then
        printf "Cannot encrypt file: $UNSAFEFILE as it does not exist\n"
        exit
    fi
    if [ ! -f $SAFEFILE ] || [ $UNSAFEFILE -nt $SAFEFILE ]; then
        cat $UNSAFEFILE
        clrscreen
        kms_encrypt $UNSAFEFILE > $SAFEFILE
        rm $UNSAFEFILE
        get_aliasname
    else
        printf "Newer encrypted file '${FILE}.enc' already exists\n"
    fi
}

dodecryptfile() {
    is_safefile
    git_msg
    rm -f $UNSAFEFILE
    kms_decrypt $SAFEFILE > $UNSAFEFILE
    ALIAS=$(aws --profile=$PROFILE kms list-aliases --key-id $KMSKEYID | jq '.Aliases[].AliasName')
    printf "File: '${UNSAFEFILE}' decrypted using KMS Key aliasname: ${ALIAS}\n"
}

main() {
    awscli_check
    COMMAND=$1
    TOPIC=$2
    ENV=$3
    CLS=$4
    FILE=${ENV}-${TOPIC}
    SAFEFILE=$SAFE/$FILE.enc
    UNSAFEFILE=$UNSAFE/$FILE

    case ${COMMAND} in
    "decrypt")
        dodecrypt;;
    "encrypt")
        SECRET=$5
        COMMENT="### ${@:6}"
        doencrypt;;
    "update")
        SECRET=$4
        COMMENT="### ${@:6}"
        doupdate;;
    "list-topics")
        dolisttopicsdecrypt;;
    "encrypt-file")
        doencryptfile;;
    "decrypt-file")
        dodecryptfile;;
    *)
        printf $COMMAND
        usage;;
    esac
}

awscli_check() {
    if ! command -v aws &> /dev/null
    then
        printf "Error: awscli binary is not installed or in the path. Fix and retry."
        exit
    fi
}

git_msg() {
    printf "*** MAKE SURE YOU HAVE CHECKED OUT THE LATEST 'main' BRANCH ***\n\n"
}

kms_encrypt() {
    aws kms --profile $PROFILE encrypt --key-id $KMSKEYID --plaintext fileb://$1 --output text --query CiphertextBlob | base64 --decode
}

kms_decrypt() {
    aws kms --profile $PROFILE decrypt --ciphertext-blob fileb://$1 --query Plaintext --output text | base64 --decode
}

get_aliasname() {
    ALIAS=$(aws --profile=$PROFILE kms list-aliases --key-id $KMSKEYID | jq '.Aliases[].AliasName')
    printf "File encrypted using KMS Key aliasname: ${ALIAS}\n"
}

is_safefile() {
    if [ ! -f $SAFEFILE ]; then
        printf "Encrypted file '${FILE}.enc' does not exist\n"
        exit
    fi
}

error_multiplematch() {
    printf "Cannot handle entries with multiple matching entries - edit manually\n"
    printf "Run 'make decrypt-file topic=$TOPIC env=$ENV to decrypt the file and insert secret manually\n"
    printf "When done encrypt the file by running the command:\n"
    printf "'make encrypt-file topic=$TOPIC env=$ENV'\n"
    exit
}

clrscreen() {
    if [[ ! "no" =~ "$CLS" ]]; then
        sleep $CLSTIME
        tput reset
    fi

}

main $@
