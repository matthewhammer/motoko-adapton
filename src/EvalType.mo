import P "mo:base/prelude";
import Buf "mo:base/buf";
import Hash "mo:base/hash";
import List "mo:base/list";
import H "mo:base/hashMap";
import L "mo:base/list";

import Render "mo:redraw/Render";

// Types defined by the interpreter client using Adapton:
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
    using the cache just defined in item (a).  See tests dir for examples.

 c. Updates the Engine from step (a) to use the evaluation function from step (b).
    Again, see tests dir for examples.

 Now, the evaluation function in step (b) is fully-defined,
 and it is ready to use the cache provided by the adapton package.

*/

public type EvalOps<Name, Val, Error, Closure> = {

/* Once we have type components in records, move here:
  type Name = _Name;
  type Val = _Val;
  type Error = _Error;
  type Env = _Env;
  type Exp = _Exp;
*/

  // an equality operation for each type:
  nameEq : (n1:Name, n2:Name) -> Bool;
  valEq : (v1:Val, v2:Val) -> Bool;
  errorEq : (err1:Error, err2:Error) -> Bool;
  closureEq : (cl1:Closure, cl2:Closure) -> Bool;

  // hash operations (only Name for now):
  nameHash : (n:Name) -> Hash.Hash;

  // abstract expression evaluation
  cyclicDependency : (L.List<Name>, Name) -> Error;
};

public type EvalClosure<Val, Error, Closure> = {
  eval: Closure -> {#ok:Val; #err:Error};
};

// Optional 2D graphics: Specify how to render each type:
public type RenderOps<Name, Val, Error, Closure> = {
  name:    (Render.Render, Name) -> ();
  val:     (Render.Render, Val) -> ();
  error:   (Render.Render, Error) -> ();
  closure: (Render.Render, Closure) -> ();  
};

}
