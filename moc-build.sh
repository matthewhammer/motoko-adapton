moc `./vessel sources` --idl test/Calc.mo &&\
moc `./vessel sources` -c test/Calc.mo &&\
mkdir -p canisters/calc &&\
cp Calc.wasm canisters/calc/Calc.wasm &&\
echo Done!
