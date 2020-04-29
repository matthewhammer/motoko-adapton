import Render "mo:redraw/Render";

import E "EvalType";
import G "GraphType";
import LogEvent "LogEvent";

module {

  // We break a potential cycle by only including the `context`, and no drawing object(s):
  public type Engine<Name, Val, Error, Closure>
    = { var context : G.Context<Name, Val, Error, Closure> };

  // a single engine has a single draw object, associated in one direction via this constructor:
  public class Draw<Name,Val,Error,Closure>( engine : Engine<Name,Val,Error,Closure> ) {

    var render = {
      let r = Render.Render();
      // to do -- begin downward vertical flow
      r
    };

    public func graph() {
      // to do -- draw the current roots and edges of the engine, including their current status
    };

    public func logEvent() {
      // to do -- draw the last logEvent
    };

    public func getResult() : Render.Result {
      // to do -- end downward vertical flow; create new render object...
      render.getResult()
    };

  };

}
