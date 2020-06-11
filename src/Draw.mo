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
        case (?ops) ops.name(render, n);
        case null { };
      }
    };

    public func val(v:Val) {
      switch (getEngine().renderOps) {
        case (?ops) ops.val(render, v);
        case null { };
      }
    };

    public func closure(c:Closure) {
      switch (getEngine().renderOps) {
        case (?ops) ops.closure(render, c);
        case null { };
      }
    };

    public func error(e:Error) {
      switch (getEngine().renderOps) {
        case (?ops) ops.error(render, e);
        case null { };
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
      { // indent body
        render.begin(#flow(horz()));
        text(" ", taFill(#closed(0, 0, 0)));
        logEventBody(render, getEngine().logEventBody(l));
        render.end();
      };
      render.end();
    };

    func logEventTag(render:Render.Render, tag:G.LogEventTag<Name, Val, Error, Closure>) {
      render.begin(#flow(horz()));
      let ta = taFill(#closed(255, 255, 255));
      switch tag {
      case (#put(_name, _val)) {
             text("put", ta);
             name(_name);
             val(_val);
           };
      case (#putThunk(_name, _clos)) {
             text("putThunk", ta);
             name(_name);
             closure(_clos);
           };
      case (#get(_name, _res)) {
             text("get", ta);
             name(_name);
             result(_res);
           };
      case (#dirtyIncomingTo(_name)) {
             text("dirtyIncomingTo", ta);
             name(_name);
           };
      case (#dirtyEdgeFrom(_name)) {
             text("dirtyEdgeFrom", ta);
             name(_name);
           };
      case (#cleanEdgeTo(_name, _flag)) {
             text("cleanEdgeTo", ta);
             name(_name);
             flag(_flag);
          };
      case (#cleanThunk(_name, _flag)) {
             text("cleanThunk", ta);
             name(_name);
             flag(_flag);
           };
      case (#evalThunk(_name, _res)) {
             text("evalThunk", ta);
             name(_name);
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
