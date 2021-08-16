/**
 Evaluation definitions for engine.
*/
import P "mo:base/Prelude";
import Buffer "mo:base/Buffer";
import Hash "mo:base/Hash";
import List "mo:base/List";
import H "mo:base/HashMap";
import L "mo:base/List";

import Render "mo:redraw/Render";

module {

/*

 A generic Adapton engine is parameterized by these choices,
 determined by a DSL implementation and its interpreter:

 1. How to represent Name, Val, Error and Closure types?
    For each, how to compare two instances for equality?
    How to hash Names?

 2. How to evaluate a Closure to an Error or Val?


 We separate the interpreter's definition into parts 1 and 2 above
 in order to break the cycle of dependencies that connects the Adapton
 engine's need for evaluation with the interpreter's
 need to access the cache.

 To resolve this cycle, the Adapton client does three steps, not one:

 a. Defines the items mentioned in question 1 above, and applies the
    Adapton.Engine functor to get an initial cache representation.  This
    representation is only half-defined, however: It still has no way to
    perform Closure evaluation.  Steps (b) and (c) are still needed below.

 b. Defines the evaluation function required by item 2 above,
    using the cache just defined in item (a).

 c. Updates the Engine from step (a) to
    use the evaluation function from step (b).

 Now, the evaluation function in step (b) is fully-defined,
 and it is ready to use the cache provided by the adapton package.

 See tests dir for an example.

*/

public type EvalOps<Name, Val, Error, Closure> = {

  // an equality operation for each type:
  nameEq : (n1:Name, n2:Name) -> Bool;
  valEq : (v1:Val, v2:Val) -> Bool;
  errorEq : (err1:Error, err2:Error) -> Bool;
  closureEq : (cl1:Closure, cl2:Closure) -> Bool;

  // hash operations (only Name for now):
  nameHash : (n:Name) -> Hash.Hash;

  // cyclicDependency: constructor for a dynamic error:
  cyclicDependency : (L.List<Name>, Name) -> Error;
};

public type EvalClosure<Val, Error, Closure> = {
  eval: Closure -> {#ok:Val; #err:Error};
};

}
