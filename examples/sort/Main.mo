import Meta "../../src/data/Meta";
import Sort "Sort";

actor {
  var sort = Sort.Sort();
  let meta = Meta.Counter();
  public query func test() : async () {
    let r =
      sort.eval(
        #put(#text "output",
        #seq(#treeOfStream(#streamOfArray(#text "input",
                    #array([
                   (#val(#num 04), meta.next()),
                   (#val(#num 16), meta.next()),
                   (#val(#num 02), meta.next()),
                   (#val(#num 07), meta.next()),
                   (#val(#num 11), meta.next()),
                   (#val(#num 09), meta.next()),
/*
                   (#val(#num 06), meta.next()),
                   (#val(#num 23), meta.next()),
                   (#val(#num 08), meta.next()),
                   (#val(#num 13), meta.next()),
                   (#val(#num 06), meta.next()),
                   (#val(#num 14), meta.next()),
                   (#val(#num 17), meta.next()),
                   (#val(#num 16), meta.next()),
*/
                   ])
               )))));
    let r1 =
      sort.eval(#seq(#treeGet(#at "output")));
  
    sort.printLog()

  };
}
