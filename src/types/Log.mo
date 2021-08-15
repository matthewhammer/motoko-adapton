import R "mo:base/Result";

module {

  // Logs are tree-structured.
  public type LogEvent<Name, Val, Error, Closure> = {
    #put:      (Name, Val, [LogEvent<Name, Val, Error, Closure>]);
    #putThunk: (Name, Closure, [LogEvent<Name, Val, Error, Closure>]);
    #get:      (Name, R.Result<Val, Error>, [LogEvent<Name, Val, Error, Closure>]);
    #dirtyIncomingTo:(Name, [LogEvent<Name, Val, Error, Closure>]);
    #dirtyEdgeFrom:(Name, [LogEvent<Name, Val, Error, Closure>]);
    #cleanEdgeTo:(Name, Bool, [LogEvent<Name, Val, Error, Closure>]);
    #cleanThunk:(Name, Bool, [LogEvent<Name, Val, Error, Closure>]);
    #evalThunk:(Name, R.Result<Val, Error>, [LogEvent<Name, Val, Error, Closure>])
  };

  // A tag is the "head" of a log, without its internal structure.
  public type LogEventTag<Name, Val, Error, Closure> = {
    #put:      (Name, Val);
    #putThunk: (Name, Closure);
    #get:      (Name, R.Result<Val, Error>);
    #dirtyIncomingTo:Name;
    #dirtyEdgeFrom: Name;
    #cleanEdgeTo:(Name, Bool);
    #cleanThunk:(Name, Bool);
    #evalThunk:(Name, R.Result<Val, Error>);
  };

}
