import Render "mo:redraw/Render";
import G "GraphType";

module {

  // We break a potential cycle by withholding the drawing object that we define below:
  public type Engine<Name, Val, Error, Closure>
    = {
      var context : G.Context<Name, Val, Error, Closure> ;
      getLogEventLast() : ?G.LogEvent<Name, Val, Error, Closure> ;
    };

  func textAtts() : Render.TextAtts {
    {
      // to do
    }
  };

  func logEvents(render:Render.Render, ls:[G.LogEvent]) {
    for (l in ls) { logEventRec(render, l) }
  };

  func logEventRec(render:Render.Render, l:G.LogEvent) {
    render.begin();
    switch l {
      case (#put(name, val, body)) {
             render.text("put", textAtts());
             logEvents(body)
           };
      case (#putThunk(name, clos, body)) {
             render.text("putThunk", textAtts());
             logEvents(body)
           };
      case (#get(name, res, body)) {

           };
      case (#dirtyIncomingTo(name, body)) {

           };
      case (#dirtyEdgeFrom(name, body)) {

           };
      case (#cleanEdgeTo(name, flag, body)) {

           };
      case (#cleanThunk(name, flag, body)) {

           };
      case (#evalThunk(name, res, body)) {

           };
    };
    render.end();
  };

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
      logEventRec(render, engine.getLogEventLast())
    };

    public func getResult() : Render.Result {
      // to do -- end downward vertical flow; create new render object...
      render.getResult()
    };

  };

}
