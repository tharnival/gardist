module Main exposing (..)

import Browser
import FileTree exposing (FileTree)
import Html exposing (Html)
import Html.Styled exposing (a, br, button, div, input, main_, text, textarea, toUnstyled)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick, onInput)
import Ports exposing (..)
import Styles
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
    { tab : Tab
    , username : String
    , password : String
    , status : FileTree
    , path : Maybe String
    , repo : String
    , commitMsg : String
    , log : List LogEntry
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { tab = Status
      , username = ""
      , password = ""
      , status = FileTree.empty
      , path = Nothing
      , repo = ""
      , commitMsg = ""
      , log = []
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        ChangeTab tab ->
            ( { model | tab = tab }
            , if tab == Log then
                log { root = "/home/thor/temp/svn/gardist", username = "tharnival", password = "barneyhal" }

              else
                Cmd.none
            )

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

        SetRepo content ->
            ( { model | repo = content }, Cmd.none )

        SetUsername username ->
            ( { model | username = username }, Cmd.none )

        SetPassword password ->
            ( { model | password = password }, Cmd.none )

        Checkout ->
            ( model
            , checkout
                { root = Maybe.withDefault "." model.path
                , repo = model.repo
                , username = model.username
                , password = model.password
                }
            )

        UpdatePath path ->
            if isJust path then
                ( { model | path = path }, svn <| Maybe.withDefault "." path )

            else
                -- don't overwrite existing path with nothing
                ( model, Cmd.none )

        UpdateRepo repo ->
            case repo of
                Just x ->
                    ( { model | repo = x }, Cmd.none )

                Nothing ->
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
                , username = model.username
                , password = model.password
                }
            )

        Revert ->
            ( model
            , revert
                { root = Maybe.withDefault "." model.path
                , changes =
                    FileTree.getCommitPaths model.status
                        |> List.map fst
                }
            )

        Expand path expanded ->
            let
                newStatus =
                    model.status
                        |> FileTree.expand path expanded
            in
            ( { model | status = newStatus }, Cmd.none )

        GetLog login ->
            ( model, log login )

        UpdateLog log ->
            ( { model | log = log }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ updateStatus UpdateStatus
        , updatePath UpdatePath
        , updateRepo UpdateRepo
        , updateLog UpdateLog
        ]



-- VIEW


view : Model -> Html Msg
view model =
    toUnstyled <|
        main_ []
            [ div []
                ([ text "username:"
                 , input [ css <| Styles.text ++ [ w_48 ], value model.username, onInput SetUsername ] []
                 , br [] []
                 , text "password:"
                 , input [ css <| Styles.text ++ [ w_48 ], type_ "password", value model.password, onInput SetPassword ] []
                 , br [] []
                 , button [ css <| Styles.button ++ [ w_64 ], onClick SetPath ] [ text "choose folder" ]
                 , div [] [ text <| Maybe.withDefault "No path specified" model.path ]
                 ]
                    ++ (if isJust model.path then
                            tabsView model
                                ++ (case model.tab of
                                        Status ->
                                            statusSection model

                                        Log ->
                                            logSection model
                                   )

                        else
                            []
                       )
                )
            ]


tabsView : Model -> List (SHtml Msg)
tabsView model =
    [ button [ css <| Styles.tab, disabled <| model.tab == Status, onClick (ChangeTab Status) ] [ text "Status" ]
    , button [ css <| Styles.tab, disabled <| model.tab == Log, onClick (ChangeTab Log) ] [ text "Log" ]
    , br [] []
    ]


statusSection : Model -> List (SHtml Msg)
statusSection model =
    [ button [ css <| Styles.button ++ [ w_32, mt_3, mb_5 ], onClick Checkout ] [ text "checkout" ]
    , input [ css <| Styles.text, type_ "text", value model.repo, onInput SetRepo ] []
    , br [] []
    , button [ css <| Styles.button ++ [ w_64 ], onClick Svn ] [ text "update status" ]
    , br [] []
    ]
        ++ FileTree.view model.status
        ++ [ br [] []
           , textarea
                [ css Styles.textField
                , placeholder "Commit message"
                , value model.commitMsg
                , onInput CommitMsg
                ]
                []
           , br [] []
           , button
                [ css <| Styles.button ++ [ w_32 ]
                , disabled <|
                    -- don't allow commiting if there is no message
                    -- or no changes added
                    (model.commitMsg == "")
                        || (FileTree.getCommitPaths model.status |> List.isEmpty)
                , onClick Commit
                ]
                [ text "commit" ]
           , button
                [ css <| Styles.button ++ [ w_32, ml_3 ]
                , disabled <| List.isEmpty <| FileTree.getCommitPaths model.status
                , onClick Revert
                ]
                [ text "discard" ]
           ]


logSection : Model -> List (SHtml Msg)
logSection model =
    model.log
        |> List.concatMap
            (\x ->
                [ div [ css <| Styles.logEntry ]
                    [ text (String.concat [ "#", x.revision, " by ", x.author ])
                    , a [ css [ absolute, right_2 ] ]
                        [ text
                            (String.concat
                                [ String.left 10 x.date
                                , " "
                                , String.slice 11 16 x.date
                                ]
                            )
                        ]
                    , br [] []
                    , text x.msg
                    ]
                ]
            )
