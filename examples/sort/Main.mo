import Meta "../../src/data/Meta";
import Sort "Sort";

actor {
  var sort = Sort.Sort();

  var metaCounter : Nat = 0;
  func metaAlloc () : Meta.Meta {
    let level = Meta.Level.ofNat(metaCounter);
    let name = #nat metaCounter;
    let meta = {level; name};
    metaCounter += 1;
    meta
  };

  public query func test() : async () {
    let r =
      sort.eval(
        #seq(#toTree(
               #array(
                 [(#val(#num 4), metaAlloc()),
                  (#val(#num 8), metaAlloc()),
                  (#val(#num 2), metaAlloc()),
                  (#val(#num 7), metaAlloc()),
                  (#val(#num 1), metaAlloc()),
                  (#val(#num 9), metaAlloc()),
                  (#val(#num 6), metaAlloc())]))));
  };
}
