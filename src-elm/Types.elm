module Types exposing (..)

import Html.Styled
import Path exposing (Path)
import Ports exposing (StatusOutput)


type Msg
    = UpdateStatus (List StatusOutput)
    | Svn
    | SetPath
    | UpdatePath (Maybe String)
    | HandleCheck Path Bool
    | CommitMsg String
    | Commit
    | Revert
    | Expand Path Bool


type alias SHtml x =
    Html.Styled.Html x
