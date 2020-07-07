import Render "mo:redraw/Render";
import Mono5x5 "mo:redraw/glyph/Mono5x5";

import P "mo:base/Prelude";
import E "EvalType";
import G "GraphType";

// Drawing utilities for the Adapton engine's log and graph structures
module {

  /* We break a potential object cycle by withholding
     the drawing object(s) that we define by the class below:

     Also, we do not include the entire API of the engine, but rather,
     only the surface are that we need to access for drawing things.
  */
  public type Engine<Name, Val, Error, Closure>
    = {
      // eventually, we can make this "safer" by having an accessor issue cheap persistent copies of the Context type
      var context : G.Context<Name, Val, Error, Closure> ;

      // to do (minor): make "safer" via an accessor
      var renderOps : ?E.RenderOps<Name, Val, Error, Closure> ;

      getLogEventLast() : ?G.LogEvent<Name, Val, Error, Closure> ;
      logEventBody : G.LogEvent<Name, Val, Error, Closure> -> [G.LogEvent<Name, Val, Error, Closure>];
      logEventTag : G.LogEvent<Name, Val, Error, Closure> -> G.LogEventTag<Name, Val, Error, Closure>;
    };


  // Flow atts --------------------------------------------------------

  func horz () : Render.FlowAtts = {
    dir=#right;
    interPad=1;
    intraPad=1;
  };

  func vert () : Render.FlowAtts = {
    dir=#down;
    interPad=1;
    intraPad=1;
  };

  func textHorz () : Render.FlowAtts = {
    dir=#right;
    interPad=1;
    intraPad=1;
  };

  // Text atts --------------------------------------------------------

  type TextAtts = Render.BitMapTextAtts;
  func taFill(fg:Render.Fill) : TextAtts = {
    zoom=2;
    fgFill=fg;
    bgFill=#closed((0, 0, 0));
    flow=textHorz();
  };

  func taLogEventTag() : TextAtts =
    taFill(#closed((180, 140, 190)));


  // a single engine has a single draw object, associated in one direction via this constructor:
  public class Draw<Name,Val,Error,Closure>() {

    public var engine : ?Engine<Name,Val,Error,Closure> = null;

    func getEngine() : Engine<Name,Val,Error,Closure> =
      switch engine { case null P.unreachable(); case (?e) e; };

    var render = {
      let r = Render.Render();
      r.begin(#flow(vert()));
      r
    };

    var charRender =
      Render.CharRender(render, Mono5x5.bitmapOfChar,
                        {
                          zoom = 3;
                          fgFill = #closed((255, 255, 255));
                          bgFill = #closed((0, 0, 0));
                          flow = horz()
                        });

    var textRender = Render.TextRender(charRender);

    /* -- shorthands -- redirect back to the client's code, for their types -- */

    public func name(n:Name) {
      switch (getEngine().renderOps) {
        case (?ops) ops.name(textRender, n);
        case null { assert false };
      }
    };

    public func val(v:Val) {
      switch (getEngine().renderOps) {
        case (?ops) ops.val(textRender, v);
        case null { assert false };
      }
    };

    public func closure(c:Closure) {
      switch (getEngine().renderOps) {
        case (?ops) ops.closure(textRender, c);
        case null { assert false };
      }
    };

    public func error(e:Error) {
      switch (getEngine().renderOps) {
        case (?ops) ops.error(textRender, e);
        case null { assert false };
      }
    };

    /* --- Log event structure -- */

    public func result(r:{#ok:Val; #err:Error}) {
      switch r {
        case (#ok(v)) val(v);
        case (#err(e)) error(e);
      }
    };

    public func text(t : Text, ta : TextAtts) {
      textRender.textAtts(t, ta)
    };

    public func flag(f:Bool) {
      if f {
        text("true", taFill(#closed(255, 255, 255)))
      } else {
        text("false", taFill(#closed(255, 255, 255)))
      }
    };

    func logEventBody(render:Render.Render, ls:[G.LogEvent<Name, Val, Error, Closure>]) {
      for (l in ls.vals()) { logEventRec(render, l) }
    };

    func logEventRec(render:Render.Render, l:G.LogEvent<Name, Val, Error, Closure>) {
      render.begin(#flow(vert()));
      logEventTag(render, getEngine().logEventTag(l));
      { let body = getEngine().logEventBody(l);
        if (body.size() == 0) { } else {
          render.begin(#flow(horz()));
          text(" ", taFill(#closed(0, 0, 0)));
          render.begin(#flow(vert()));
          render.fill(#open((255, 255, 255), 1));
          logEventBody(render, body);
          render.end();
          render.end();
        }
      };
      render.end();
    };

    func logEventTag(render:Render.Render, tag:G.LogEventTag<Name, Val, Error, Closure>) {
      render.begin(#flow(horz()));
      let taHi = taFill(#closed(255, 255, 255));
      let taLo = taFill(#closed(100, 100, 100));
      let taEval = taFill(#closed(100, 255, 100));
      switch tag {
      case (#put(_name, _val)) {
             text("put ", taLo);
             name(_name);
             text(" := ", taHi);
             val(_val);
           };
      case (#putThunk(_name, _clos)) {
             text("put ", taLo);
             name(_name);
             text(" := ", taHi);
             closure(_clos);
           };
      case (#get(_name, _res)) {
             text("get ", taLo);
             name(_name);
             text(" => ", taHi);
             result(_res);
           };
      case (#dirtyIncomingTo(_name)) {
             text("dirtyIncomingTo", taHi);
             name(_name);
           };
      case (#dirtyEdgeFrom(_name)) {
             text("dirtyEdgeFrom", taHi);
             name(_name);
           };
      case (#cleanEdgeTo(_name, _flag)) {
             text("cleanEdgeTo", taHi);
             name(_name);
             flag(_flag);
          };
      case (#cleanThunk(_name, _flag)) {
             text("cleanThunk", taHi);
             name(_name);
             flag(_flag);
           };
      case (#evalThunk(_name, _res)) {
             text("eval ", taEval);
             name(_name);
             text(" => ", taHi);
             result(_res);
           };
      };
      render.end();
    };

    /* --- Graph structure --- */

    public func graph() {
      // to do -- draw the current roots and edges of the engine, including their current status
    };

    public func logEventLast() {
      switch (getEngine().getLogEventLast()) {
      case null { };
      case (?l) { logEventRec(render, l) }
      }
    };

    public func getResult() : Render.Result {
      render.end();
      let res = render.getResult();
      { // start the next rendering...
        render := Render.Render();
        render.begin(#flow(vert()));
      };
      res
    };

  };

}
