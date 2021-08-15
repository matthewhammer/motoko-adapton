let upstream =
      https://github.com/kritzcreek/vessel-package-set/releases/download/mo-0.6.6-20210809/package-set.dhall

let
    -- This is where you can add your own packages to the package-set
    additions =
      [ { name = "stand"
        , repo = "https://github.com/matthewhammer/motoko-stand/"
        , version = "master"
        , dependencies = [ "base" ]
        }
      , { name = "redraw"
        , repo = "https://github.com/matthewhammer/motoko-redraw/"
        , version = "master"
        , dependencies = [ "base", "stand" ]
        }
      ]

in  upstream # additions
