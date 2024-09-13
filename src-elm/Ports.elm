port module Ports exposing (..)


port svn : String -> Cmd msg


port setPath : () -> Cmd msg


port checkout :
    { root : String
    , repo : String
    }
    -> Cmd msg


port commit :
    { root : String
    , msg : String
    , changes : List ( String, Bool )
    }
    -> Cmd msg


port revert :
    { root : String
    , changes : List String
    }
    -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg


type alias StatusOutput =
    { info : String
    , path : String
    , isDir : Bool
    }


port updateStatus : (List StatusOutput -> msg) -> Sub msg
