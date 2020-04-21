import Render "mo:redraw/Render";
import T "types";

module {
  
  public type Result = Render.Result;

  public func begin() : Render.Render {
    Render.Render()
  };

  public func env(r:Render.Render, env:T.Eval.Env) {
    // to do
  };

  public func graph(r:Render.Render, a:T.Adapton.Context) {
    // to do
  };

  public func logEvent(r:Render.Render, ev:T.Adapton.LogEvent) {
    // to do
  };

}
