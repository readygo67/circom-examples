pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/comparators.circom";


template Swap(nBits){
    signal input in[2];
    signal output out[2];

    signal gt <== GreaterThan(nBits)([in[0], in[1]]);
    out[0] <== (in[1] - in[0])*gt + in[0];
    out[1] <== (in[0] - in[1])*gt + in[1];
}


template BubbleSort(n, nBits){
    signal input in[n];
    signal output out[n];
    signal tmp[n][n][n]; //[round][step][element]

    component swap[n-1][n-1];

    tmp[0][0][0] <== in[0];
    tmp[0][0][1] <== in[1];

    for (var j=2;j<n;j++){
        tmp[0][j-1][j] <== in[j]; 
    }

    // (i-1)round, the ith round has (n-i-1) step.
    for (var i=0; i<n-1;i++){
        for (var j=0;j < n -i -1;j++){   
            swap[i][j] = Swap(nBits);
            swap[i][j].in[0] <== tmp[i][j][j];
            swap[i][j].in[1] <== tmp[i][j][j+1];

            tmp[i][j+1][j] <== swap[i][j].out[0];
            tmp[i][j+1][j+1] <== swap[i][j].out[1];
        }
        
        //prepare data for the next round 
        tmp[i+1][0][0] <== tmp[i][1][0];
        for (var k=1;k< n-i-1;k++){
            tmp[i+1][k-1][k] <== tmp[i][k+1][k]; 
        }
    }
    
    //pickup output
    out[0] <== tmp[n-2][1][0];
    out[1] <== tmp[n-2][1][1];

    for (var i=2;i<=n-1;i++){
        out[i] <== tmp[n-1-i][i][i];
    }
}

component main = BubbleSort(16, 252);

