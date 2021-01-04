echo PATH = $PATH
echo vessel @ `which vessel`

dfx start --background
dfx build
dfx canister install --all
dfx canister call Calc test '()'
