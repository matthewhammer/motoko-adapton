import Render "mo:redraw/Render";
import E "EvalType";
import A "Adapton";

module {

  class Draw<Name,Val,Error,Env,Exp>() {

  public func begin() : Render.Render {
    Render.Render()
  };

  public func graph(r:Render.Render, a:A.Context<Name,Val,Error,Env,Exp>) {
    // to do
  };

  public func logEvent(r:Render.Render, ev:A.LogEvent<Name,Val,Error,Env,Exp>) {
    // to do
  };

  };

}
