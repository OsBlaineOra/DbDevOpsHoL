#!/bin/bash
export OCI_CLI_PROFILE=PERSONAL

# Set Variables
AVAILABILITY_DOMAIN_NAME="US-ASHBURN-AD-1"
AVAILABILITY_DOMAIN=$(oci iam availability-domain list   --all   --query 'data[?contains(name, `'"${AVAILABILITY_DOMAIN_NAME}"'`)] | [0].name'   --raw-output)
COMPARTMENT_NAME="Projects"
DB_NAME="demo"
DB_DISPLAY_NAME="DemoDb"
DB_PW="T3stertester"
WALLET_PW="Pw4ZipFile"
WALLET_ZIP="/home/bcarter/tempWallet/Wallet_${DB_NAME}.zip"
COMPUTE_NAME="CiCdDemo"
COMPUTE_SHAPE="VM.Standard2.1"
# COMPUTE_SHAPE="VM.Standard.E2.1.Micro" # Always Free
COMPUTE_OS="Oracle Linux"
COMPUTE_OS_VERSION="7.7"
PUBLIC_KEY="/home/bcarter/.ssh/oracle.pub"

create_compartment() {
    COMPARTMENT_ID= $(oci iam compartment create \
        --compartment-id $(oci iam compartment list --query "data[?contains(\"compartment-id\",'.tenancy.')].\"compartment-id\" | [0]" --raw-output) \
        --name ${COMPARTMENT_NAME} \
        --description "For ${COMPARTMENT_NAME}" \
        --query "data.id" --raw-output)
}

create_db() {
    DB_ID=$(oci db autonomous-database create \
        --compartment-id ${COMPARTMENT_ID} \
        --cpu-core-count 1 \
        --data-storage-size-in-tbs 1 \
        --db-name "${DB_NAME}" \
        --display-name "${DB_DISPLAY_NAME}" \
        --db-workload "OLTP" \
        --admin-password "T3stertester" \
        --is-free-tier  False \
        --wait-for-state AVAILABLE \
        --query "data.id" --raw-output)
}

create_vnc() {
    VNC_ID=$(oci network vcn create \
    --compartment-id ${COMPARTMENT_ID} \
    --display-name "${COMPARTMENT_NAME}_VNC" \
    --dns-label "${COMPARTMENT_NAME}_DNS" \
    --cidr-block "<0.0.0.0/0>"
    --query 'data.id' \
    --raw-output)

    SECURITY_LIST_ID=$(oci network security-list create \
    --compartment-id ${COMPARTMENT_ID} \
    --egress-security-rules "[{"destination": "<0.0.0.0/0>", \
                               "protocol": "<6>", \
                               "isStateless": <true>, \
                               "tcpOptions": {"destinationPortRange": <null>, "sourcePortRange": <null>}}]" \
    --ingress-security-rules "[{"source": "<0.0.0.0/0>", \
                                "protocol": "<6>", \
                                "isStateless": <false>, \
                                "tcpOptions": {"destinationPortRange": {"max": <8080>, "min": <8080>}, "sourcePortRange": <null>}}]" \
    --vcn-id ${VNC_ID} \
    --display-name "Port8080"
    --query 'data.id' \
    --raw-output)

    SUBNET_ID=$(oci network subnet create \
    --compartment-id ${COMPARTMENT_ID} \
    --vcn-id ${VNC_ID} \
    --availability-domain "${AVAILABILITY_DOMAIN}" \
    --display-name "${COMPARTMENT_NAME}_SUBNET" \
    --dns-label "${COMPARTMENT_NAME}_DNS" \
    --cidr-block "<10.0.0.0/16>" \
    --security-list-ids "["${SECURITY_LIST_ID}"]"
    --query 'data.id' \
    --raw-output)

    oci network internet-gateway create \
    --compartment-id ${COMPARTMENT_ID} \
    --is-enabled <true> \
    --vcn-id ${VNC_ID} \
    --display-name "${COMPARTMENT_NAME}_GATEWAY"

    oci network route-table list \
    --compartment-id ${COMPARTMENT_ID} \
    --vcn-id ${VNC_ID}
}

create_compute() {
    ocid_image=$(oci compute image list \
        --compartment-id ${COMPARTMENT_ID} \
        --operating-system "${COMPUTE_OS}" \
        --operating-system-version "${COMPUTE_OS_VERSION}" \
        --shape "${COMPUTE_SHAPE}" \
        --sort-by TIMECREATED \
        --query 'data[0].id' \
        --raw-output)

    VNC_ID=$(oci network vcn list \
        -c $COMPARTMENT_ID \
        --query "data [] | [0].id" \
        --raw-output)
        # ?\"display-name\"=='${COMPARTMENT_NAME}_VNC'
        

    # if [[ -z "${VNC_ID}" ]]; then
    #     echo "No VNC found."
    #     create_vnc
    # fi

    SUBNET_ID=$(oci network subnet list \
        -c $COMPARTMENT_ID \
        --vcn-id ${VNC_ID} \
        --query "data [?contains(\"display-name\", '"${AVAILABILITY_DOMAIN}"')] | [0].id" \
        --raw-output)
        # ?\"display-name\"=='${COMPARTMENT_NAME}_SUBNET'

    export COMPUTE_ID=$(oci compute instance launch \
        --compartment-id ${COMPARTMENT_ID} \
        --display-name ${COMPUTE_NAME} \
        --availability-domain "${AVAILABILITY_DOMAIN}" \
        --subnet-id "${SUBNET_ID}" \
        --image-id "${ocid_image}" \
        --shape "${COMPUTE_SHAPE}" \
        --ssh-authorized-keys-file "${PUBLIC_KEY}" \
        --assign-public-ip true \
        --wait-for-state RUNNING \
        --query 'data.id' \
        --raw-output)
}

export COMPARTMENT_ID=$(oci iam compartment list --query "data[?name=='${COMPARTMENT_NAME}'].id | [0]" --raw-output)

if [[ -z "${COMPARTMENT_ID}" ]]; then
    echo "No Demo Compartment found."
    while true; do
        read -p "Do you wish to create the Demo Compartment? " yn
        case $yn in
            [Yy]* ) echo "do it"; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

export DB_ID=$(oci db autonomous-database list -c ${COMPARTMENT_ID} --query "data[?\"db-name\"=='${DB_NAME}'].id | [0]" --raw-output)
echo $DB_ID

if [[ -z "$DB_ID" ]]; then
    echo "No $DB_DISPLAY_NAME Database found."
    while true; do
        read -p "Do you wish to create the $DB_DISPLAY_NAME Database?" yn
        case $yn in
            [Yy]* ) create_db; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

download_wallet() {
    pw=$1
    file=$2

    oci db autonomous-database generate-wallet --autonomous-database-id $DB_ID --password $pw --file $file
}

download_wallet T3stertester Wallet_CiCd.zip

export COMPUTE_ID=$(oci compute instance list -c ${COMPARTMENT_ID} --query "data[?\"display-name\"=='${COMPUTE_NAME}'].id | [0]" --raw-output)
echo $COMPUTE_ID

if [[ -z "$COMPUTE_ID" ]]; then
    echo "No $COMPUTE_NAME Compute Instance found."
    while true; do
        read -p "Do you wish to create the $COMPUTE_NAME Compute Instance?" yn
        case $yn in
            [Yy]* ) create_compute; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

clean_up() {
    oci db autonomous-database delete $DB_ID
    
    # if [ -d "$PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/wallet" ]; then
    #     echo "Removing Wallet Directory"
    #     rm -rf $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/wallet
    # fi

    # if [ -f "$PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/testConnect.sql" ]; then
    #     echo "Deleting testConnect.sql"
    #     rm "$PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/testConnect.sql"
    # fi
}

# clean_up

# echo "set cloudconfig $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/wallet/Wallet_demos.zip
# connect admin/T3stertester@demos_TP
# select 'Yes! I connected to my Always Free ATP database!' did_it_work from dual;
# exit;" >> $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/testConnect.sql

# mkdir $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/wallet
# cd $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/wallet

# oci db autonomous-database generate-wallet --autonomous-database-id $DB_ID --password T3stertester --file Wallet_demos.zip

# unzip Wallet_demos.zip

# sed -i -e 's|oracle.net.wallet_location=|'"# oracle.net.wallet_location="'|' \
# -e 's|#javax.net.ssl.|'"javax.net.ssl."'|' \
# -e 's|<password_from_console>|'"T3stertester"'|' \
# ojdbc.properties

# if [ "$1" != "init" ]; then
#     sql /nolog @$PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/testConnect.sql

#     cd $PRESENTATION_DIRECTORY/Active/LiquibaseAlwaysFree/code/new
#     liquibase updateSQL
#     clean_up
# fi