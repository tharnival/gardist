module Main exposing (..)

import Browser
import FileTree exposing (FileTree)
import Html exposing (Html)
import Html.Styled exposing (br, button, div, main_, text, textarea, toUnstyled)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick, onInput)
import Ports exposing (..)
import Styles exposing (..)
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)
import Types exposing (..)
import Util exposing (..)



-- MAIN


main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }



-- MODEL


type alias Model =
    { status : FileTree
    , path : Maybe String
    , commitMsg : String
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { status = FileTree.empty
      , path = Nothing
      , commitMsg = ""
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateStatus status ->
            ( { model | status = FileTree.fromStatus status }, Cmd.none )

        Svn ->
            ( model, svn <| Maybe.withDefault "." model.path )

        HandleCheck path checked ->
            let
                newStatus =
                    model.status
                        |> FileTree.updateCheck path checked
            in
            ( { model | status = newStatus }, Cmd.none )

        SetPath ->
            ( model, setPath () )

        UpdatePath path ->
            if isJust path then
                ( { model | path = path }, svn <| Maybe.withDefault "." path )

            else
                -- don't overwrite existing path with nothing
                ( model, Cmd.none )

        CommitMsg commitMsg ->
            ( { model | commitMsg = commitMsg }, Cmd.none )

        Commit ->
            ( { model | commitMsg = "" }
            , commit
                { root = Maybe.withDefault "." model.path
                , msg = model.commitMsg
                , changes = FileTree.getCommitPaths model.status
                }
            )

        Expand path expanded ->
            let
                newStatus =
                    model.status
                        |> FileTree.expand path expanded
            in
            ( { model | status = newStatus }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ updateStatus UpdateStatus
        , updatePath UpdatePath
        ]



-- VIEW


view : Model -> Html Msg
view model =
    toUnstyled <|
        main_ []
            [ div []
                ([ button [ css <| buttonStyle ++ [ w_64 ], onClick SetPath ] [ text "choose folder" ]
                 , div [] [ text <| Maybe.withDefault "No path specified" model.path ]
                 ]
                    ++ statusSection model
                )
            ]


statusSection : Model -> List (SHtml Msg)
statusSection model =
    if isJust model.path then
        [ br [] []
        , button [ css <| buttonStyle ++ [ w_64 ], onClick Svn ] [ text "update status" ]
        , br [] []
        ]
            ++ FileTree.view model.status
            ++ [ br [] []
               , textarea
                    [ css textFieldStyle
                    , placeholder "Commit message"
                    , value model.commitMsg
                    , onInput CommitMsg
                    ]
                    []
               , br [] []
               , button
                    [ css <| buttonStyle ++ [ w_32 ]
                    , disabled <|
                        -- don't allow commiting if there is no message
                        -- or no changes added
                        (model.commitMsg == "")
                            || (FileTree.getCommitPaths model.status |> List.isEmpty)
                    , onClick Commit
                    ]
                    [ text "commit" ]
               ]

    else
        []
