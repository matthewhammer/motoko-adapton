import Engine "../../src/Engine";
import Seq "../../src/data/Sequence";
import Meta "../../src/data/Meta";
import R "mo:base/Result";
import L "mo:base/List";
import Text "mo:base/Text";
import Debug "mo:base/Debug";

/**
 Incremental sorting example.
 Uses adapton for representing stream thunks and caching them as data changes.
 */
module {

public type Name = Meta.Name;

public type Val = {
  #unit;
  #num : Nat;
  #seq : Seq.Val<Val>;
};

public type Error = {
  #typeMismatch;
  #seq : Seq.Error<Val>;
};

public type Exp = {
  #unit;
  #num : Nat;
  #seq : Seq.Exp<Val>;
};

public class Sort() {
  /* -- cache implementation, via adapton package -- */
  public var engine : Engine.Engine<Name, Val, Error, Exp> =
    Engine.Engine<Name, Val, Error, Exp>(
      {
        nameEq=func (x:Name, y:Name) : Bool { x == y };
        valEq=func (x:Val, y:Val) : Bool { x == y };
        closureEq=func (x:Exp, y:Exp) : Bool { x == y };
        errorEq=func (x:Error, y:Error) : Bool { x == y };
        nameHash=Meta.Name.hash;
        cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
          Debug.print(debug_show {stack; name});
          assert false; loop { }
        }
      },
      true // logging
    );
  public var engineIsInit = false;

  public var seq = Seq.Sequence<Val, Error, Exp>(
    engine,
    {
      valMax = func(v1 : Val, v2 : Val) : R.Result<Val, Error> {
        switch (v1, v2) {
        case (#num n1, #num n2)
        #ok(#num(if (n1 > n2) n1 else n2));
        case _ #err(#typeMismatch);
        }
      };
      getVal = func(v : Val) : ?Seq.Val<Val> =
        switch v { case (#seq(s)) ?s; case _ null };
      putVal = func(v : Seq.Val<Val>) : Val = #seq(v);
      putExp = func(e : Seq.Exp<Val>) : Exp = #seq(e);
      getExp = func(e : Exp) : ?Seq.Exp<Val> =
        switch e { case (#seq(e)) ?e; case _ null };
      putError = func(e : Seq.Error<Val>) : Error = #seq(e);
      getError = func(e : Error) : ?Seq.Error<Val> =
        switch e { case (#seq(e)) ?e; case _ null };
    }
  );

  func evalRec(exp : Exp) : R.Result<Val, Error> {
    switch exp {
      case (#unit) #ok(#unit);
      case (#num n) #ok(#num n);
      case (#seq e) seq.eval(e);
    }
  };

  public func eval(exp : Exp) : R.Result<Val, Error> {
    if (not engineIsInit) {
      engine.init({eval=evalRec});
      engineIsInit := true
    };
    evalRec(exp)
  };

  public func printLog() {
    let log = engine.takeLog();
    // compiler bug here, it seems:
    debug { Debug.print (debug_show log) }
  };

};

}

