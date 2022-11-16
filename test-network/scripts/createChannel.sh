#!/bin/bash

# imports  
. scripts/envVar.sh
. scripts/utils.sh

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
fi

createChannelTx() {
	set -x
	configtxgen -profile mychannel -outputCreateChannelTx ./channel-artifacts/mychannel.tx -channelID mychannel
	res=$?
	{ set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
  echo "채널 tx생성 완료..."
}

createAncorPeerTx() {
	#asOrg 주석 의미
	configtxgen -profile mychannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1
	configtxgen -profile mychannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2
	
	echo
}

createChannel() {
	setGlobals org1 0

	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		# peer channel create -o orderer0.org1.example.com:7050 -c mychannel -f ../channel-artifacts/mychannel.tx --outputBlock $BLOCKFILE --tls true --cafile $ORDERER_CA >&log.txt
		#peer channel create -f /home/firstfabric/test-network/channel-artifacts/mychannel.tx -c mychannel -o orderer0.example.com:7050 --tls true --cafile $ORDERER_CA >&log.txt

		peer channel create -o localhost:7050 -c mychannel --ordererTLSHostnameOverride orderer0.example.com -f ./channel-artifacts/mychannel.tx --outputBlock ./channel-artifacts/mychannel.block --tls --cafile $ORDERER_CA
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	verifyResult $res "Channel creation failed"
	echo
	echo "'$CHANNEL_NAME' create success!"
	echo
}

# joinChannel ORG
joinChannel() {
  #FABRIC_CFG_PATH=$PWD/../config/
  	ORG=$1
  	for var in 0 1; do
		setGlobals $ORG $var
		local rc=1
		local COUNTER=1
		## Sometimes Join takes time, hence retry
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel join -b ./channel-artifacts/mychannel.block >&log.txt
		res=$?
		{ set +x; } 2>/dev/null
			let rc=$res
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		verifyResult $res "After $MAX_RETRY attempts, peer.org${ORG} has failed to join channel '$CHANNEL_NAME' "
	done
}

updateAnchorPeersFirstORg() {
	setGlobals 'org1' 0
	local rc=1
	local COUNTER=1

	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
		peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com -c mychannel -f ./channel-artifacts/Org1MSPanchors.tx --tls --cafile $ORDERER_CA
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$MY_CHANNEL_NAME' ===================== "
	sleep $DELAY
	echo
}

updateAnchorPeersSecondORg() {
	
	setGlobals 'org2' 0
	local rc=1
	local COUNTER=1

	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
		peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com -c mychannel -f ./channel-artifacts/Org2MSPanchors.tx --tls --cafile $ORDERER_CA
    res=$?
    set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$MY_CHANNEL_NAME' ===================== "
	sleep $DELAY
	echo
}


FABRIC_CFG_PATH=${PWD}/configtx

## Create channeltx
infoln "Generating channel create transaction '${CHANNEL_NAME}.tx'"
createChannelTx

## Create anchorpeertx
echo "### Generating anchor peer update transactions txfile###"
createAncorPeerTx

#BLOCKFILE="./system-genesis-block/${CHANNEL_NAME}.block"

FABRIC_CFG_PATH=$PWD/../config/

## Create channel
infoln "Creating channel ${CHANNEL_NAME}"
createChannel
successln "Channel '$CHANNEL_NAME' created"

## Join all the peers to the channel
infoln "Joining org1 peers to mychannel..."
joinChannel org1
infoln "Joining org2 peers to mychannel..."
joinChannel org2

##앵커 피어 설정은 마지막에 한다

## Set the anchor peers for each org in the channel
infoln "Setting anchor peer for org1... peer0"
updateAnchorPeersFirstORg
infoln "Setting anchor peer for org2... peer0"
updateAnchorPeersSecondORg

successln "Channel '$CHANNEL_NAME' joined"
