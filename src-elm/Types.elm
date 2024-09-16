module Types exposing (..)

import Html.Styled
import Path exposing (Path)
import Ports exposing (StatusOutput)


type Msg
    = UpdateStatus (List StatusOutput)
    | Svn
    | SetPath
    | SetUsername String
    | SetPassword String
    | SetRepo String
    | Checkout
    | UpdatePath (Maybe String)
    | UpdateRepo (Maybe String)
    | HandleCheck Path Bool
    | CommitMsg String
    | Commit
    | Revert
    | Expand Path Bool


type alias SHtml x =
    Html.Styled.Html x
