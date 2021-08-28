import Meta "../../src/data/Meta";
import Sort "Sort";

actor {
  var sort = Sort.Sort();
  let meta = Meta.Counter();
  public query func test() : async () {
    let r =
      sort.eval(
        #seq(#toTree(
               #array(
                 [(#val(#num 4), meta.next()),
                  (#val(#num 8), meta.next()),
                  (#val(#num 2), meta.next()),
                  (#val(#num 7), meta.next()),
                  (#val(#num 1), meta.next()),
                  (#val(#num 9), meta.next()),
                  (#val(#num 6), meta.next())]))));
  };
}
