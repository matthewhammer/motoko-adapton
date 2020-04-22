import P "mo:base/prelude";
import Buf "mo:base/buf";
import Hash "mo:base/hash";
import List "mo:base/list";
import H "mo:base/hashMap";
import L "mo:base/list";

module {

// A generic Adapton engine is parameterized by these choices,
// determined by a DSL implementation in its evaluator:
public type Eval<Name, Val, Error, Env, Exp> = {
/* Once we have type components in records:
  type Name = _Name;
  type Val = _Val;
  type Error = _Error;
  type Env = _Env;
  type Exp = _Exp;
*/
  nameEq : (n1:Name, n2:Name) -> Bool;
  nameHash : (n:Name) -> Hash.Hash;
  valEq : (v1:Val, v2:Val) -> Bool;
  errorEq : (err1:Error, err2:Error) -> Bool;
  envEq : (env1:Env, env2:Env) -> Bool;
  expEq : (e1:Exp, e2:Exp) -> Bool;
  eval : (env:Env, exp:Exp) -> {#ok:Val; #err:Error};
};

}
