module Types exposing (..)

import Html.Styled
import Path exposing (..)


type Msg
    = UpdateStatus (List StatusOutput)
    | Svn
    | SetPath
    | UpdatePath (Maybe String)
    | HandleCheck Path Bool
    | CommitMsg String
    | Commit
    | Expand Path Bool


type alias StatusOutput =
    { info : String
    , path : String
    , isDir : Bool
    }


type alias SHtml x =
    Html.Styled.Html x
