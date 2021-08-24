import Engine "../Engine";

import H "mo:base/Hash";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Text "mo:base/Text";


module {

  /// Names as untyped symbol trees.
  /// Names serve as locally-unique dynamic identifiers.
  public type Name = {
    #none;
    #int : Int;
    #nat : Nat;
    #text : Text;
    #bin : (Name, Name);
    #tri : (Name, Name, Name);
    #cons : (Name, [ Name ]);
    #record : [(Name, Name)];
  };
  
  // Levels define [Cartesian trees](https://en.wikipedia.org/wiki/Cartesian_tree).
  public type Level = Nat;

  // Meta data within inductive components of incremental data structures.
  public type Meta = {
    name : Name;
    level : Level;
  };
}
  
