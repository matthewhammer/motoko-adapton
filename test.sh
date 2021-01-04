#!/bin/bash
VERSION=`cat .DFX_VERSION`
export PATH=~/.cache/dfinity/versions/$VERSION:`pwd`:$PATH
dfx stop &&\
dfx start --background --clean &&\
dfx canister create Calc &&\
dfx build Calc &&\
dfx canister install Calc &&\
dfx canister call Calc test2 '()'

echo "BEGIN PROBLEMATIC TEST (will hang now.)"
dfx canister call Calc test '()'
echo DONE
