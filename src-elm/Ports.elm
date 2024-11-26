port module Ports exposing (..)


port svn : String -> Cmd msg


port setPath : () -> Cmd msg


port checkout :
    { root : String
    , repo : String
    , username : String
    , password : String
    }
    -> Cmd msg


port commit :
    { root : String
    , msg : String
    , changes : List ( String, Bool )
    , username : String
    , password : String
    }
    -> Cmd msg


port revert :
    { root : String
    , changes : List String
    }
    -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg


port updateRepo : (Maybe String -> msg) -> Sub msg


type alias StatusOutput =
    { info : String
    , path : String
    , isDir : Bool
    }


port updateStatus : (List StatusOutput -> msg) -> Sub msg


type alias Login =
    { root : String
    , username : String
    , password : String
    }


port log : Login -> Cmd msg


type alias LogEntry =
    { revision : String
    , author : String
    , date : String
    , msg : String
    }


port updateLog : (List LogEntry -> msg) -> Sub msg
