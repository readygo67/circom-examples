pragma circom 2.0.5;

include "sha256.circom";

/*
 * Implements SimpleSerialize (SSZ) according to the Ethereum 2.0. spec for 
 * various containers, including BeaconBlockHeader, SyncCommittee, etc.
 */

template SSZLayer(numBytes) {
    assert(numBytes >= 64);
    signal input in[numBytes];
    signal output out[numBytes\ 2];

    var numPairs = numBytes \ 64;
    component hashers[numPairs];

    for (var i = 0; i < numPairs; i++) {
        hashers[i] = Sha256Bytes(64);
        for (var j = 0; j < 64; j++) {
            hashers[i].in[j] <== in[i * 64 + j];
        }
    }

    for (var i = 0; i < numPairs; i++) {
        for (var j = 0; j < 32; j++) {
            out[i * 32 + j] <== hashers[i].out[j];
        }
    }
}


template SSZArray(numBytes, log2b) {
    assert(32 * (2 ** log2b) == numBytes);

    signal input in[numBytes];
    signal output out[32];

    component sszLayers[log2b];
    for (var layerIdx = 0; layerIdx < log2b; layerIdx++) {
        var numInputBytes = numBytes \ (2 ** layerIdx);
        sszLayers[layerIdx] = SSZLayer(numInputBytes);

        for (var i = 0; i < numInputBytes; i++) {
            if (layerIdx == 0) {
                sszLayers[layerIdx].in[i] <== in[i];
            } else {
                sszLayers[layerIdx].in[i] <== sszLayers[layerIdx - 1].out[i];
            }
        }
    }

    for (var i = 0; i < 32; i++) {
        out[i] <== sszLayers[log2b - 1].out[i];
    }
}


template SSZPhase0SyncCommittee(
    SYNC_COMMITTEE_SIZE,
    LOG_2_SYNC_COMMITTEE_SIZE,
    G1_POINT_SIZE
) {
    signal input pubkeys[SYNC_COMMITTEE_SIZE][G1_POINT_SIZE];
    signal input aggregatePubkey[G1_POINT_SIZE];
    signal output out[32];

    component sszPubkeys = SSZArray(
        SYNC_COMMITTEE_SIZE * 64,
        LOG_2_SYNC_COMMITTEE_SIZE + 1
    );
    for (var i = 0; i < SYNC_COMMITTEE_SIZE; i++) {
        for (var j = 0; j < 64; j++) {
            if (j < G1_POINT_SIZE) {
                sszPubkeys.in[i * 64 + j] <== pubkeys[i][j];
            } else {
                sszPubkeys.in[i * 64 + j] <== 0;
            }
        }
    }

    component sszAggregatePubkey = SSZArray(64, 1);
    for (var i = 0; i < 64; i++) {
        if (i < G1_POINT_SIZE) {
            sszAggregatePubkey.in[i] <== aggregatePubkey[i];
        } else {
            sszAggregatePubkey.in[i] <== 0;
        }
    }

    component hasher = Sha256Bytes(64);
    for (var i = 0; i < 64; i++) {
        if (i < 32) {
            hasher.in[i] <== sszPubkeys.out[i];
        } else {
            hasher.in[i] <== sszAggregatePubkey.out[i - 32];
        }
    }

    for (var i = 0; i < 32; i++) {
        out[i] <== hasher.out[i];
    }
}

//ETH2.0 BeanBockHeadner
template SSZBeaconBlockHeader() {
    signal input slot[32];
    signal input proposerIndex[32];
    signal input parentRoot[32];
    signal input stateRoot[32];
    signal input bodyRoot[32];
    signal output out[32];

    component sszBeaconBlockHeader = SSZArray(256, 3);
    for (var i = 0; i < 256; i++) {
        if (i < 32) {
            sszBeaconBlockHeader.in[i] <== slot[i];
        } else if (i < 64) {
            sszBeaconBlockHeader.in[i] <== proposerIndex[i - 32];
        } else if (i < 96) {
            sszBeaconBlockHeader.in[i] <== parentRoot[i - 64];
        } else if (i < 128) {
            sszBeaconBlockHeader.in[i] <== stateRoot[i - 96];
        } else if (i < 160) {
            sszBeaconBlockHeader.in[i] <== bodyRoot[i - 128];
        } else {
            sszBeaconBlockHeader.in[i] <== 0;
        }
    }

    for (var i = 0; i < 32; i++) {
        out[i] <== sszBeaconBlockHeader.out[i];
    }
}

// https://beaconcha.in/slot/6718304
// 对应的slot= 6718304,  hash= 93b565f4963da72294d15161b14526aff8b272b209653c8c962f959153904905

component main = SSZBeaconBlockHeader();