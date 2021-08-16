/**
 Structured logs of adapton effects.
*/
import G "types/Graph";
import E "types/Eval";
import Log "types/Log";
import Buffer "mo:base/Buffer";
import L "mo:base/List";

module {

  public type LogEvent<Name, Val, Error, Closure> =
    Log.LogEvent<Name, Val, Error, Closure>;

  public type LogEventBuf<Name, Val, Error, Closure> =
    Buffer.Buffer<LogEvent<Name, Val, Error, Closure>>;

  public type LogBufStack<Name, Val, Error, Closure> =
    L.List<LogEventBuf<Name, Val, Error, Closure>>;

  public class Logger<Name, Val, Error, Closure>(
    evalOps : E.EvalOps<Name, Val, Error, Closure>,
    _logFlag : Bool
  ) {

    var logFlag = _logFlag;

    var logBuf : LogEventBuf<Name, Val, Error, Closure> =
      Buffer.Buffer<LogEvent<Name, Val, Error, Closure>>(0);

    var logStack : LogBufStack<Name, Val, Error, Closure> = null;

    public func setFlag(_logFlag : Bool) {
      assert(L.isNil(logStack)); // implies that the editor, not archivist, is active.
      logFlag := _logFlag;
    };

    public func begin() {
      if (logFlag) {
        logStack := ?(logBuf, logStack);
        logBuf := Buffer.Buffer<LogEvent<Name, Val, Error, Closure>>(03);
      }
    };

    public func end(tag : G.LogEventTag<Name, Val, Error, Closure>)
    {
      if (logFlag) {
        switch (logStack) {
          case null { assert false };
          case (?(prevLogBuf, tail)) {
            let events = logBuf.toArray();
            let ev = logEvent(tag, events);
            logStack := tail;
            logBuf := prevLogBuf;
            logBuf.add(ev);
          }
        }
      }
    };

    /** -- public log utils, parameterized by the types Name, Val, Error, Closure -- */

    public func logEvent
      (tag : G.LogEventTag<Name, Val, Error, Closure>,
       events : [LogEvent<Name, Val, Error, Closure>])
      : LogEvent<Name, Val, Error, Closure>
    {
      switch tag {
      case (#put(v, n))      { #put(v, n,      events) };
      case (#putThunk(c, n)) { #putThunk(c, n, events) };
      case (#get(r, n))      { #get(r, n,      events) };
      case (#dirtyIncomingTo(n)){ #dirtyIncomingTo(n,events) };
      case (#dirtyEdgeFrom(n)){ #dirtyEdgeFrom(n,events) };
      case (#cleanEdgeTo(n,f)) { #cleanEdgeTo(n,f,events) };
      case (#cleanThunk(n,f)) { #cleanThunk(n,f,events) };
      case (#evalThunk(n,r)) { #evalThunk(n,r,events) };
      }
    };


    public func logEventBody
      (event : LogEvent<Name, Val, Error, Closure>)
      : [LogEvent<Name, Val, Error, Closure>]
    {
      switch event {
      case (#put(v, n, evts))      { evts };
      case (#putThunk(c, n, evts)) { evts };
      case (#get(r, n, evts))      { evts };
      case (#dirtyIncomingTo(n, evts)){ evts };
      case (#dirtyEdgeFrom(n, evts)){ evts };
      case (#cleanEdgeTo(n,f, evts)) { evts };
      case (#cleanThunk(n,f, evts)) { evts };
      case (#evalThunk(n,r, evts)) { evts };
      }
    };

    public func logEventTag
      (event : LogEvent<Name, Val, Error, Closure>)
      : G.LogEventTag<Name, Val, Error, Closure>
    {
      switch event {
      case (#put(v, n, evts))      { #put(v, n) };
      case (#putThunk(c, n, evts)) { #putThunk(c, n) };
      case (#get(r, n, evts))      { #get(r, n) };
      case (#dirtyIncomingTo(n, evts)){ #dirtyIncomingTo(n) };
      case (#dirtyEdgeFrom(n, evts)){ #dirtyEdgeFrom(n) };
      case (#cleanEdgeTo(n,f, evts)) { #cleanEdgeTo(n, f) };
      case (#cleanThunk(n,f, evts)) { #cleanThunk(n, f) };
      case (#evalThunk(n,r, evts)) { #evalThunk(n, r) };
      }
    };


    public func getLogEvents() : [LogEvent<Name, Val, Error, Closure>] {
      logBuf.toArray()
    };

    public func getLogEventLast() : ?LogEvent<Name, Val, Error, Closure> {
      if (logBuf.size() > 0) {
        ?logBuf.get(logBuf.size() - 1)
      } else {
        null
      }
    };

    // assert last log event
    public func assertLogEventLast(expected : LogEvent<Name, Val, Error, Closure>) {
      let logLen = logBuf.size();
      if (logLen > 0) {
        let actual = logBuf.get(logLen - 1);
        assert logEventEq(actual, expected)
      } else { // no log event
        assert false
      }
    };

    public func logEventsEq (e1 : [LogEvent<Name, Val, Error, Closure>],
                             e2 : [LogEvent<Name, Val, Error, Closure>]) : Bool {
      if (e1.size() == e2.size()) {
        for (i in e1.keys()) {
          if (logEventEq(e1[i], e2[i])) {
            /* continue */
          } else {
            return false
          }
        };
        true
      } else { false }
    };

    public func resultEq (r1:{#ok:Val; #err:Error}, r2:{#ok:Val; #err:Error}) : Bool {
      switch (r1, r2) {
        case (#ok(v1), #ok(v2)) { evalOps.valEq(v1, v2) };
        case (#err(e1), #err(e2)) { evalOps.errorEq(e1, e2) };
        case _ false;
      };
    };

    public func logEventEq (e1 : LogEvent<Name, Val, Error, Closure>,
                            e2 : LogEvent<Name, Val, Error, Closure>) : Bool {
      switch (e1, e2) {
      case (#put(n1, v1, es1), #put(n2, v2, es2)) {
             evalOps.nameEq(n1, n2) and evalOps.valEq(v1, v2) and logEventsEq(es1, es2)
           };
      case (#putThunk(n1, c1, es1), #putThunk(n2, c2, es2)) {
             evalOps.nameEq(n1, n2) and evalOps.closureEq(c1, c2) and logEventsEq(es1, es2)
           };
      case (#get(n1, r1, es1), #get(n2, r2, es2)) {
             evalOps.nameEq(n1, n2) and resultEq(r1, r2) and logEventsEq(es1, es2)
           };
      case (#dirtyIncomingTo(n1, es1), #dirtyIncomingTo(n2, es2)) {
             evalOps.nameEq(n1, n2) and logEventsEq(es1, es2)
           };
      case (#dirtyEdgeFrom(n1, es1), #dirtyEdgeFrom(n2, es2)) {
             evalOps.nameEq(n1, n2) and logEventsEq(es1, es2)
           };
      case (#cleanEdgeTo(n1, f1, es1), #cleanEdgeTo(n2, f2, es2)) {
             evalOps.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
           };
      case (#cleanThunk(n1, f1, es1), #cleanThunk(n2, f2, es2)) {
            evalOps.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
           };
      case (#evalThunk(n1, r1, es1), #evalThunk(n2, r2, es2)) {
             evalOps.nameEq(n1, n2) and resultEq(r1, r2) and logEventsEq(es1, es2)
           };
      case (_, _) {
             false
           }
      }

    };
  };
}
