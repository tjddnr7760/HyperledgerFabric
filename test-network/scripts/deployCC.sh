#!/bin/bash

CHANNEL_NAME=${1:-"mychannel"}
CC_NAME=${2:-"basic"}
CC_SRC_PATH=${3:-"NA"}
CC_SRC_LANGUAGE=go
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}
PACKAGE_ID=""

echo --- executing with the following
echo   - CHANNEL_NAME:$'\e[0;32m'$CHANNEL_NAME$'\e[0m'
echo   - CC_NAME:$'\e[0;32m'$CC_NAME$'\e[0m'
echo   - CC_SRC_PATH:$'\e[0;32m'$CC_SRC_PATH$'\e[0m'
echo   - CC_SRC_LANGUAGE:$'\e[0;32m'$CC_SRC_LANGUAGE$'\e[0m'
echo   - CC_VERSION:$'\e[0;32m'$CC_VERSION$'\e[0m'
echo   - CC_SEQUENCE:$'\e[0;32m'$CC_SEQUENCE$'\e[0m'
echo   - CC_END_POLICY:$'\e[0;32m'$CC_END_POLICY$'\e[0m'
echo   - CC_COLL_CONFIG:$'\e[0;32m'$CC_COLL_CONFIG$'\e[0m'
echo   - CC_INIT_FCN:$'\e[0;32m'$CC_INIT_FCN$'\e[0m'
echo   - DELAY:$'\e[0;32m'$DELAY$'\e[0m'
echo   - MAX_RETRY:$'\e[0;32m'$MAX_RETRY$'\e[0m'
echo   - VERBOSE:$'\e[0;32m'$VERBOSE$'\e[0m'

CC_SRC_LANGUAGE=`echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:]`

FABRIC_CFG_PATH=$PWD/../config/



# User has not provided a path, therefore the CC_NAME must
# be the short name of a known chaincode sample
if [ "$CC_SRC_PATH" = "NA" ]; then
	echo Determining the path to the chaincode
	# first see which chaincode we have. This will be based on the
	# short name of the known chaincode sample
	if [ "$CC_NAME" = "basic" ]; then
		echo $'\e[0;32m'asset-transfer-basic$'\e[0m' chaincode
		CC_SRC_PATH="../../my-fabric-samples/asset-transfer-basic"
	elif [ "$CC_NAME" = "secured" ]; then
		echo $'\e[0;32m'asset-transfer-secured-agreeement$'\e[0m' chaincode
		CC_SRC_PATH="../asset-transfer-secured-agreement"
	elif [ "$CC_NAME" = "ledger" ]; then
		echo $'\e[0;32m'asset-transfer-ledger-agreeement$'\e[0m' chaincode
		CC_SRC_PATH="../asset-transfer-ledger-queries"
	elif [ "$CC_NAME" = "private" ]; then
		echo $'\e[0;32m'asset-transfer-private-data$'\e[0m' chaincode
		CC_SRC_PATH="../asset-transfer-private-data"
	else
		echo The chaincode name ${CC_NAME} is not supported by this script
		echo Supported chaincode names are: basic, secured, and private
		exit 1
	fi

	# now see what language it is written in
	if [ "$CC_SRC_LANGUAGE" = "go" ]; then
		CC_SRC_PATH="$CC_SRC_PATH/chaincode-go/"
	elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
		CC_SRC_PATH="$CC_SRC_PATH/chaincode-java/"
	elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
		CC_SRC_PATH="$CC_SRC_PATH/chaincode-javascript/"
	elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
		CC_SRC_PATH="$CC_SRC_PATH/chaincode-typescript/"
	fi

	# check that the language is available for the sample chaincode
	if [ ! -d "$CC_SRC_PATH" ]; then
		echo The smart contract language "$CC_SRC_LANGUAGE" is not yet available for
		echo the "$CC_NAME" sample smart contract
		exit 1
	fi
## Make sure that the path the chaincode exists if provided
elif [ ! -d "$CC_SRC_PATH" ]; then
	echo Path to chaincode does not exist. Please provide different path
	exit 1
fi

# do some language specific preparation to the chaincode before packaging
if [ "$CC_SRC_LANGUAGE" = "go" ]; then
		CC_RUNTIME_LANGUAGE=golang

	echo Vendoring Go dependencies at $CC_SRC_PATH
	pushd $CC_SRC_PATH
	GO111MODULE=on go mod vendor
	popd
	echo Finished vendoring Go dependencies

elif [ "$CC_SRC_LANGUAGE" = "java" ]; then
	CC_RUNTIME_LANGUAGE=java

	echo Compiling Java code ...
	pushd $CC_SRC_PATH
	./gradlew installDist
	popd
	echo Finished compiling Java code
	CC_SRC_PATH=$CC_SRC_PATH/build/install/$CC_NAME

elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
	CC_RUNTIME_LANGUAGE=node

elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
	CC_RUNTIME_LANGUAGE=node

	echo Compiling TypeScript code into JavaScript ...
	pushd $CC_SRC_PATH
	npm install
	npm run build
	popd
	echo Finished compiling TypeScript code into JavaScript

else
	echo The chaincode language ${CC_SRC_LANGUAGE} is not supported by this script
	echo Supported chaincode languages are: go, java, javascript, and typescript
	exit 1
fi

INIT_REQUIRED="--init-required"
# check if the init fcn should be called
if [ "$CC_INIT_FCN" = "NA" ]; then
	INIT_REQUIRED=""
fi

if [ "$CC_END_POLICY" = "NA" ]; then
	CC_END_POLICY=""
else
	CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
	CC_COLL_CONFIG=""
else
	CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi


#if [ "$CC_INIT_FCN" = "NA" ]; then
#	INIT_REQUIRED=""
#fi

# import utils
. scripts/envVar.sh


packageChaincode() {
	ORG=$1
	setGlobals $ORG $2
	set -x
	peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label basic_1.0 >&log.txt
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Chaincode packaging on peer${2}.${ORG} has failed"
	echo "===================== Chaincode is packaged on peer${2}.${ORG} ===================== "
	echo
}

# installChaincode PEER ORG
installChaincode() {
	ORG=$1
	setGlobals $ORG $2
	set -x
	#peer lifecycle chaincode install ${CC_NAME}.tar.gz >&log.txt
	peer lifecycle chaincode install fabcar.tar.gz
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Chaincode installation on peer${2}.${ORG} has failed"
	echo "===================== Chaincode is installed on peer${2}.${ORG} ===================== "
	echo
}

# queryInstalled PEER ORG
queryInstalled() {
	ORG=$1
	setGlobals $ORG $2
	set -x
	peer lifecycle chaincode queryinstalled >&log.txt
	res=$?
	set +x
	cat log.txt
	PACKAGE_ID=$(sed -n "/${CC_NAME}-${NUM}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
	verifyResult $res "Query installed on peer${2}.${ORG} has failed"
	echo "===================== Query installed successful on peer${2}.${ORG} on channel ===================== "
	echo
}


# approveForMyOrg VERSION PEER ORG
approveForMyOrg() {
	ORG=$1
	setGlobals $ORG $2
	#checkChannel $@
	set -x
	peer lifecycle chaincode approveformyorg  -o localhost:7050 --tls --cafile $ORDERER_CA --channelID mychannel --name basic --version 1.0 --init-required --package-id basic_1.0:3cfcf67978d6b3f7c5e0375660c995b21db19c4330946079afc3925ad7306881 --sequence 1 --signature-policy "OR ('Org1.peer','Org2.peer')"
	
	#peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com --tls --cafile $ORDERER_CA --channelID mychannel --name basic --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG}
	#peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer1.example.com --tls --cafile $ORDERER_CA --channelID mychannel --name basic --version 1 --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --waitForEvent
	echo $PACKAGE_ID, ${PACKAGE_ID}
	#peer lifecycle chaincode approveformyorg --tls --cafile /home/firstfabric/test-network/organizations/ordererOrganizations/example.com/orderers/orderer0.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --channelID mychannel --name basic --version 1 --sequence 1 --waitForEvent --package-id $PACKAGE_ID
	set +x
	cat log.txt
	verifyResult $res "Chaincode definition approved on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME' failed"
	echo "===================== Chaincode definition approved on peer${2}.${ORG} on channel '$MY_CHANNEL_NAME' ===================== "
	echo
}

# checkCommitReadiness VERSION PEER ORG
checkCommitReadiness() {
	ORG=$1
	MYPEER=$2
	setGlobals $ORG $MYPEER
	#checkChannel $1 $2
	shift 2
	echo "===================== Checking the commit readiness of the chaincode definition on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
	# we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		sleep $DELAY
		echo "Attempting to check the commit readiness of the chaincode definition on peer${MYPEER}.${ORG}, Retry after $DELAY seconds."
		set -x
		peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name basic --version 1.0 --sequence 1 --output json
		res=$?
		set +x
		let rc=0
		for var in "$@"; do
			grep "$var" log.txt &>/dev/null || let rc=1
		done
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	if test $rc -eq 0; then
		echo "===================== Checking the commit readiness of the chaincode definition successful on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME' ===================== "
	else
		echo
		echo $'\e[1;31m'"!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Check commit readiness result on peer${MYPEER}.${ORG} is INVALID !!!!!!!!!!!!!!!!"$'\e[0m'
		echo
		exit 1
	fi
}

# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
commitChaincodeDefinition() {
	#arsePeerConnectionParameters $@
	res=$?
	#checkChannel $1 $2
	verifyResult $res "Invoke transaction failed on channel '$MY_CHANNEL_NAME' due to uneven number of peer and org parameters "

	# while 'peer chaincode' command can get the orderer endpoint from the
	# peer (if join was successful), let's supply it directly as we know
	# it using the "-o" option
	set -x
	peer lifecycle chaincode commit -o localhost:7050 --tls --cafile $ORDERER_CA --channelID mychannel --name basic --version 1.0 --sequence 1
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Chaincode definition commit failed on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME' failed"
	echo "===================== Chaincode definition committed on channel '$MY_CHANNEL_NAME' ===================== "
	echo
}

# queryCommitted ORG
queryCommitted() {
	ORG=$1
	setGlobals $ORG $2
	#checkChannel $1 $2
	EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
	echo "===================== Querying chaincode definition on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
	# we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		sleep $DELAY
		echo "Attempting to Query committed status on peer${MYPEER}.${ORG}, Retry after $DELAY seconds."
		set -x
		peer lifecycle chaincode querycommitted --channelID mychannel --name basic
		res=$?
		set +x
		test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
		test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
		COUNTER=$(expr $COUNTER + 1)
	done
	echo
	cat log.txt
	if test $rc -eq 0; then
		echo "===================== Query chaincode definition successful on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME' ===================== "
		echo
	else
		echo
		echo $'\e[1;31m'"!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query chaincode definition result on ${MYPEER}.${ORG} is INVALID !!!!!!!!!!!!!!!!"$'\e[0m'
		echo
		exit 1
	fi
}

chaincodeInvokeInit() {
	#parsePeerConnectionParameters $@
	#checkChannel $1 $2
	res=$?
	verifyResult $res "Invoke transaction failed on channel '$MY_CHANNEL_NAME' due to uneven number of peer and org parameters "

	# while 'peer chaincode' command can get the orderer endpoint from the
	# peer (if join was successful), let's supply it directly as we know
	# it using the "-o" option
	set -x
	fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
	echo invoke fcn call:${fcn_call}
	peer chaincode invoke -o localhost:7050 --tls --cafile $ORDERER_CA -C mychannel -n basic --isInit -c ${fcn_call}

	res=$?
	set +x
	cat log.txt
	verifyResult $res "Invoke execution on $PEERS failed "
	echo "===================== Invoke transaction successful on $PEERS on channel '$MY_CHANNEL_NAME' ===================== "
	echo
}

chaincodeQuery() {
	ORG=$1
	setGlobals $ORG $2
	#checkChannel $1 $2
	echo "===================== Querying on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
	# we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		sleep $DELAY
		echo "Attempting to Query peer${MYPEER}.${ORG}, Retry after $DELAY seconds."
		set -x
		peer chaincode query -C mychannel -n basic -c '{"Args":["queryAllCars"]}'
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	echo
	cat log.txt
	if test $rc -eq 0; then
		echo "===================== Query successful on peer${MYPEER}.${ORG} on channel '$MY_CHANNEL_NAME' ===================== "
		echo
	else
		echo
		echo $'\e[1;31m'"!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query result on peer${MYPEER}.${ORG} is INVALID !!!!!!!!!!!!!!!!"$'\e[0m'
		echo
		exit 1
	fi
}


################
## mychannel1 ##
################
## package the chaincode
packageChaincode org 0

## Install chaincode on peer0.org1 and peer0.customer
echo "Installing chaincode on peer0.org1..."
installChaincode org1 0
echo "Installing chaincode on peer1.org1..."
installChaincode org1 1
echo "Installing chaincode on peer0.org2..."
installChaincode org2 0
echo "Installing chaincode on peer1.org2..."
installChaincode org2 1

## query whether the chaincode is installed
queryInstalled org1 0

## approve the definition for org1
approveForMyOrg org1 0
## now approve also for customer
approveForMyOrg org2 0

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness org1 0 "\"Org2MSP\": true" "\"Org1MSP\": true" 

## now that we know for sure both orgs have approved, commit the definition
commitChaincodeDefinition org1 0 org2 0

## query on both orgs to see that the definition committed successfully
queryCommitted org1 0
queryCommitted org2 0