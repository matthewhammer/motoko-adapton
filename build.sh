moc `./vessel sources` --package adapton src -r test/test.mo &&\
moc `./vessel sources` --package adapton src --idl test/Calc.mo &&\
moc `./vessel sources` --package adapton src -c test/Calc.mo &&\
cp Calc.wasm dfxproj/canisters/dfxproj/main.wasm

