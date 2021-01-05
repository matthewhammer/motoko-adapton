import A "../Adapton";
import E "../EvalType";

import H "mo:base/Hash";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Render "mo:redraw/Render";


/* # Example of using Adapton functor (modules A and E imported above). */

/* Adapton functor step 1a:
      Define four types (see *'s below), and operations: */
module {
public type Name = Text; // *
public type Val = Int; // *

public type Error = { // *
  #divByZero;
  #unimplemented;
  #putError : Name;
};

public type Exp = { // *
  #num: Int;
  #add: (Exp, Exp);
  #sub: (Exp, Exp);
  #mul: (Exp, Exp);
  #div: (Exp, Exp);
  #named: (Name, Exp); // record a cached result at Name
};

// simple integer-based calculator, with incremental caching
public class Calc() {

  /* -- utils -- extra stuff we need -- */

  public func binOpOfExp(e:Exp)
    : ?{#add;#sub;#mul;#div} {
    switch e {
    case (#add _) ?#add;
    case (#sub _) ?#sub;
    case (#mul _) ?#mul;
    case (#div _) ?#div;
    case _ null;
    }
  };

  func expEq(x:Exp, y:Exp) : Bool {
    switch (x, y) {
    case (#num(n1), #num(n2)) { n1 == n2 };
    case (#named(n1, e1), #named(n2, e2)) { n1 == n2 and expEq(e1, e2) };
    case (#add(e1, e2), #add(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#mul(e1, e2), #mul(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#div(e1, e2), #div(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#sub(e1, e2), #sub(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case _ { false };
    }
  };

  func errorEq(x:Error, y:Error) : Bool {
    switch (x, y) {
    case (#divByZero, #divByZero) { true };
    case (#unimplemented, #unimplemented) { true };
    case (#putError(n1), #putError(n2)) { n1 == n2 };
    case _ { false };
    }
  };


  /* -- custom DSL evaluator definition: -- */

  var init : Bool = false;

  public func eval(e:Exp) : R.Result<Val, Error> {
    if (not init) {
      // Adapton functor step 3:
      //   initialize engine with evaluation function.
      engine.setEvalClosure({eval=evalRec});
      // Now the the calculator is ready for (incremental) evaluation!
      init := true;
    };
   evalRec(e)
  };

  // Adapton functor step 2:
  //    Using engine as a cache, define a custom evaluation function for DSL:
  func evalRec(e:Exp) : R.Result<Val, Error> {
    switch e {
    case (#num(n)) { #ok(n) };
    case ( #add(_, _) // feedback to compiler design: This would be easier if I could bind vars here.
        or #sub(_, _)
        or #mul(_, _)
        or #div(_, _) ) {
           switch (evalEagerPair(e)) {
             case (#err(e)) #err(e);
             case (#ok((n1, n2))) {
                    switch (binOpOfExp(e)) {
                    case null { P.unreachable() };
                    case (?#add) #ok(n1 + n2) ;
                    case (?#mul) #ok(n1 * n2);
                    case (?#sub) #ok(n1 - n2);
                    case (?#div) if (n2 == 0) { #err(#divByZero) } else #ok(n1 / n2);
                  }
                  }
           }
         };
    case (#named(n, e)) {
           // Engine helps via cache steps (a) and (b):
           //   (a) put Thunk within the cache at given name
           switch (engine.putThunk(n, e)) {
           case (#err(_)) { #err(#putError(n)) }; // e.g., non-unique name in AST
           case (#ok(n)) {
                  // (b) get demands the evaluation result of put Thunk
                  switch (engine.get(n)) {
                  case (#ok(res)) { res }; // temp
                  case (#err(_)) { P.unreachable() };
                  }
                };
           }
         };
/*
    case _ {
           #err(#unimplemented)
         }
*/
    }
  };

  func evalEagerPair(e:Exp) : R.Result<(Val, Val), Error> {
    func doit(e1:Exp, e2:Exp) : R.Result<(Val, Val), Error> {
      switch (evalRec(e1)) {
      case (#err(e)) #err(e);
      case (#ok(v1)) {
             switch (evalRec(e2)) {
             case (#err(e)) #err(e);
             case (#ok(v2)) {
                    #ok((v1, v2))
                  }
             }
           }
      }
    };
    switch e {
      // redoing the pattern-match because I cannot bind vars in `or` patterns
      case (#add(e1, e2)) { doit(e1, e2) };
      case (#sub(e1, e2)) { doit(e1, e2) };
      case (#div(e1, e2)) { doit(e1, e2) };
      case (#mul(e1, e2)) { doit(e1, e2) };
      case _ { P.unreachable() };
    }
  };

  /* -- cache implementation, via adapton package -- */

  public var engine : A.Engine<Name, Val, Error, Exp> = do {
    let _errorEq = errorEq;
    // Adapton functor step 1b:
    //   Apply the functor to the definitions of types and operations,
    //   excluding the definition of evaluation itself (step 2).
    let engine = A.Engine<Name, Val, Error, Exp>
    ({
       nameEq=func (x:Text, y:Text) : Bool { x == y };
       valEq=func (x:Int, y:Int) : Bool { x == y };
       errorEq=_errorEq;
       closureEq=expEq;
       nameHash=Text.hash;
       cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
         assert false; loop { }
       }
     },
     true);
    // to do: draw things
    engine.renderOps := ?{
      name = func (r:Render.TextRender, t:Text) {
        r.textFg(t, #closed((255, 100, 255)))
      };
      val = func (r:Render.TextRender, i:Int) {
        r.textFg(Int.toText(i), #closed((255, 255, 100)))
      };
      error = func (r:Render.TextRender, e:Error) {
        // to do
      };
      closure = func (tr:Render.TextRender, e:Exp) {
        let r = tr.charRender.render;
        let tFill = #closed((120, 120, 0));
        let flow0 = { intraPad=0; interPad=0; dir=#right };
        let flow1 = { intraPad=1; interPad=1; dir=#right };
        let flow2 = { intraPad=2; interPad=2; dir=#right };
        func rec(e:Exp) {
          r.begin(#flow(flow2));
          r.fill(#open((100, 100, 0), 1));
          r.begin(#flow(flow1));
          r.fill(#open((0, 0, 0), 1));
          r.begin(#flow(flow0));
          r.fill(#closed((0, 0, 0)));
          exp(e);
          r.end();
          r.end();
          r.end()
        };
        func exp(e:Exp) {
          switch e {
          case (#named (n, e)) {
                 r.begin(#flow(flow2));
                 r.fill(#closed((100, 100, 0)));
                 tr.textBg(
                   n,
                   #closed((0,0,0)),
                   #closed((100, 100, 0)));
                 rec(e);
                 r.end();
               };
          case (#num n) { tr.textFg(Int.toText(n), tFill) };
          case (#add(e1,e2)) { rec(e1); tr.textFg("+", tFill); rec(e2) };
          case (#sub(e1,e2)) { rec(e1); tr.textFg("-", tFill); rec(e2) };
          case (#mul(e1,e2)) { rec(e1); tr.textFg("*", tFill); rec(e2) };
          case (#div(e1,e2)) { rec(e1); tr.textFg("/", tFill); rec(e2) };
          };
        };
        rec(e)
      }
    };
    // not yet fully initialized (still need to do setClosureEval)
    engine
  };

};

}
