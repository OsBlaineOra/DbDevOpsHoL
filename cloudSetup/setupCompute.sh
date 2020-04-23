#!/bin/bash
DB_DISPLAY_NAME=$1

export OCI_CLI_PROFILE=PERSONAL
# export OCI_CLI_PROFILE=DEMO
export COMPARTMENT_ID=$(oci iam compartment list --query "data [?description=='Demo'].{OCID:id}" | jq -r '.[].OCID')

if [[ -z "$COMPARTMENT_ID" ]]; then
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

wait_until_state() {
    WAIT_STATE=$1

    while true; do
        STATE=$(oci db autonomous-database get --autonomous-database-id $DB_ID | jq -r '.data."lifecycle-state"')
        if [[ $WAIT_STATE = $STATE ]]; then
          break;
        else
          echo "Current State: $STATE"
          sleep 5
        fi
    done
}

create_compute() {
    read -p "Enter Compute Name: " COMPUTE_NAME

    ocid_instance=$(oci compute instance launch \
    --display-name CiCd \
    --compartment-id $COMPARTMENT_ID \
    --availability-domain qVbG:US-ASHBURN-AD-3 \
    --subnet-id "${OCID_SUBNET}" \
    --image-id "ocid1.image.oc1.iad.aaaaaaaa6tp7lhyrcokdtf7vrbmxyp2pctgg4uxvt4jz4vc47qoc2ec4anha" \
    --shape "VM.Standard.E2.1.Micro" \
    --ssh-authorized-keys-file "/home/bcarter/.ssh/oracle.pub" \
    --assign-public-ip true \
    --wait-for-state RUNNING \
    --no-retry)

    echo $ocid_instance

    # if [[ -z "$COMPARTMENT_ID" ]]; then
    #     echo "No Demo Compartment found."
    #     while true; do
    #         read -p "Do you wish to create the Demo Compartment? " yn
    #         case $yn in
    #             [Yy]* ) echo "do it"; break;;
    #             [Nn]* ) exit;;
    #             * ) echo "Please answer yes or no.";;
    #         esac
    #     done
    # fi
}

create_compute