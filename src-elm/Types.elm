module Types exposing (..)

import Html.Styled
import Path exposing (Path)
import Ports exposing (LogEntry, Login, StatusOutput)


type Msg
    = ChangeTab Tab
    | UpdateStatus (List StatusOutput)
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
    | GetLog Login
    | UpdateLog (List LogEntry)


type Tab
    = Status
    | Log


type alias SHtml x =
    Html.Styled.Html x
