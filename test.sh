echo PATH = $PATH
echo vessel @ `which vessel`

mkdir -p .vessel/base/b296b63b33e5f52a540311a342e16934867c3f5a && ln -s $(dfx cache show)/base .vessel/base/b296b63b33e5f52a540311a342e16934867c3f5a/src

echo
echo == Build
echo

dfx start --background
dfx build
dfx canister install --all
dfx canister call Calc test '()'
